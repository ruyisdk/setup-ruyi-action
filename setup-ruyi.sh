#!/usr/bin/env bash
# Setup script for the RuyiSDK Package Manager (ruyi).
# This script is intended to be called from the composite GitHub Action.
set -euo pipefail

# --- Architecture resolution ---
resolve_arch() {
    local input_arch="$1"

    if [[ "$input_arch" != "auto" ]]; then
        echo "$input_arch"
        return
    fi

    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *)
            echo "::error::Cannot auto-detect architecture: unsupported uname -m value '$machine'. Please set the arch input explicitly." >&2
            exit 1
            ;;
    esac
}

# --- Build curl args with auth and API headers ---
github_api_curl_args() {
    local token="$1"
    local -n _args=$2
    _args=(--fail --silent --show-error --location)
    if [[ -n "$token" ]]; then
        _args+=(--header "Authorization: Bearer ${token}")
    fi
    _args+=(--header "Accept: application/vnd.github+json")
    _args+=(--header "X-GitHub-Api-Version: 2022-11-28")
}

# --- Resolve the version to install ---
resolve_version() {
    local version="$1"
    local token="$2"

    case "$version" in
        latest|stable)
            resolve_channel_version "stable" "$token"
            ;;
        beta)
            resolve_channel_version "beta" "$token"
            ;;
        alpha)
            resolve_channel_version "alpha" "$token"
            ;;
        *)
            # Assume it's a concrete version number
            echo "$version"
            ;;
    esac
}

# --- Resolve the latest version for a given channel ---
resolve_channel_version() {
    local channel="$1"
    local token="$2"

    echo "::debug::Resolving latest $channel ruyi version via GitHub API" >&2

    if [[ "$channel" == "stable" ]]; then
        local api_url="https://api.github.com/repos/ruyisdk/ruyi/releases/latest"
        local curl_args
        github_api_curl_args "$token" curl_args

        local response
        response="$(curl "${curl_args[@]}" "$api_url")"

        local tag_name
        tag_name="$(echo "$response" | jq -r '.tag_name')"

        if [[ -z "$tag_name" || "$tag_name" == "null" ]]; then
            echo "::error::Failed to resolve latest stable ruyi version from GitHub API" >&2
            exit 1
        fi

        echo "$tag_name"
        return
    fi

    # For beta/alpha, list recent releases and find the first matching one
    local api_url="https://api.github.com/repos/ruyisdk/ruyi/releases?per_page=30"
    local curl_args
    github_api_curl_args "$token" curl_args

    local response
    response="$(curl "${curl_args[@]}" "$api_url")"

    local tag_name
    tag_name="$(echo "$response" | jq -r --arg ch "-${channel}." \
        '[.[] | select(.tag_name | contains($ch))][0].tag_name')"

    if [[ -z "$tag_name" || "$tag_name" == "null" ]]; then
        echo "::error::No $channel release found for ruyi" >&2
        exit 1
    fi

    echo "$tag_name"
}

# --- Get SHA256 digest for an asset from the release API ---
get_asset_digest() {
    local version="$1"
    local asset_name="$2"
    local token="$3"

    local api_url="https://api.github.com/repos/ruyisdk/ruyi/releases/tags/${version}"
    local curl_args
    github_api_curl_args "$token" curl_args

    local response
    response="$(curl "${curl_args[@]}" "$api_url")"

    local digest
    digest="$(echo "$response" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .digest')"

    if [[ -z "$digest" || "$digest" == "null" ]]; then
        echo ""
        return
    fi

    # Strip the "sha256:" prefix
    echo "${digest#sha256:}"
}

# --- Main ---
main() {
    local version="${INPUT_RUYI_VERSION:-latest}"
    local input_arch="${INPUT_ARCH:-auto}"
    local token="${INPUT_GITHUB_TOKEN:-}"

    # Resolve architecture
    local arch
    arch="$(resolve_arch "$input_arch")"
    echo "::debug::Resolved architecture: $arch"

    # Resolve version
    local resolved_version
    resolved_version="$(resolve_version "$version" "$token")"
    echo "Resolved ruyi version: $resolved_version"

    # Build download URL and asset name
    local asset_name="ruyi-${resolved_version}.${arch}"
    local download_url="https://github.com/ruyisdk/ruyi/releases/download/${resolved_version}/${asset_name}"

    # Create install directory
    local install_dir="${RUNNER_TEMP}/ruyi-bin"
    mkdir -p "$install_dir"

    local binary_path="${install_dir}/ruyi"

    # Download the binary
    echo "Downloading ruyi ${resolved_version} for ${arch}..."
    echo "::debug::Download URL: $download_url"
    local curl_args=(--fail --silent --show-error --location --output "$binary_path")
    if [[ -n "$token" ]]; then
        curl_args+=(--header "Authorization: Bearer ${token}")
    fi
    curl "${curl_args[@]}" "$download_url"
    echo "Download complete."

    # Verify SHA256 checksum
    local expected_hash
    expected_hash="$(get_asset_digest "$resolved_version" "$asset_name" "$token")"
    if [[ -n "$expected_hash" ]]; then
        echo "Verifying SHA256 checksum..."
        local actual_hash
        actual_hash="$(sha256sum "$binary_path" | cut -d' ' -f1)"
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            echo "::error::SHA256 checksum mismatch! Expected: $expected_hash, Got: $actual_hash"
            rm -f "$binary_path"
            exit 1
        fi
        echo "Checksum verified."
    else
        echo "::warning::Could not retrieve SHA256 digest from GitHub API; skipping checksum verification."
    fi

    # Make executable
    chmod +x "$binary_path"

    # Add to PATH
    echo "$install_dir" >> "$GITHUB_PATH"

    # Set outputs
    echo "ruyi-version=${resolved_version}" >> "$GITHUB_OUTPUT"
    echo "ruyi-path=${binary_path}" >> "$GITHUB_OUTPUT"

    # Smoke test
    echo "Running smoke test..."
    "$binary_path" --version

    # Configure telemetry mode
    local telemetry="${INPUT_TELEMETRY:-off}"
    case "$telemetry" in
        on|true)
            echo "Enabling telemetry..."
            "$binary_path" config set telemetry.mode on
            ;;
        off|false)
            echo "Disabling telemetry..."
            "$binary_path" config set telemetry.mode off
            ;;
        *)
            echo "::error::Invalid telemetry value '$telemetry'. Use 'on'/'true' or 'off'/'false'."
            exit 1
            ;;
    esac

    # Configure custom repo remote if provided
    local repo_remote="${INPUT_REPO_REMOTE:-}"
    if [[ -n "$repo_remote" ]]; then
        echo "Configuring custom repo remote: $repo_remote"
        "$binary_path" config set repo.remote "$repo_remote"
    fi

    # Configure custom repo branch if provided
    local repo_branch="${INPUT_REPO_BRANCH:-}"
    if [[ -n "$repo_branch" ]]; then
        echo "Configuring custom repo branch: $repo_branch"
        "$binary_path" config set repo.branch "$repo_branch"
    fi

    # Update the repository index
    echo "Updating ruyi repository index..."
    "$binary_path" update

    echo "ruyi ${resolved_version} installed successfully at ${binary_path}"
}

main
