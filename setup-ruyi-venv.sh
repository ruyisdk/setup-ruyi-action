#!/usr/bin/env bash
# Create and activate a RuyiSDK virtual environment for GitHub Actions.
# This script is intended to be called from the composite GitHub Action.
set -euo pipefail

main() {
    local profile="${INPUT_VENV_PROFILE:?venv-profile is required}"
    local toolchain="${INPUT_VENV_TOOLCHAIN:-}"
    local emulator="${INPUT_VENV_EMULATOR:-}"
    local name="${INPUT_VENV_NAME:-}"
    local sysroot="${INPUT_VENV_SYSROOT:-with}"
    local extra_commands_from="${INPUT_VENV_EXTRA_COMMANDS_FROM:-}"
    local dest="${INPUT_VENV_DEST:-}"

    # Default destination
    if [[ -z "$dest" ]]; then
        dest="${RUNNER_TEMP}/ruyi-venv"
    fi

    # Build the ruyi venv command
    local cmd=(ruyi venv)

    if [[ -n "$name" ]]; then
        cmd+=(--name "$name")
    fi

    # Toolchain(s): split on whitespace to allow multiple specifiers
    if [[ -n "$toolchain" ]]; then
        for tc in $toolchain; do
            cmd+=(--toolchain "$tc")
        done
    fi

    if [[ -n "$emulator" ]]; then
        cmd+=(--emulator "$emulator")
    fi

    # Sysroot handling
    case "$sysroot" in
        with)    cmd+=(--with-sysroot) ;;
        without) cmd+=(--without-sysroot) ;;
        *)       cmd+=(--sysroot-from "$sysroot") ;;
    esac

    # Extra commands: split on whitespace
    if [[ -n "$extra_commands_from" ]]; then
        for pkg in $extra_commands_from; do
            cmd+=(--extra-commands-from "$pkg")
        done
    fi

    cmd+=("$profile" "$dest")

    echo "Creating RuyiSDK virtual environment..."
    echo "::debug::Running: ${cmd[*]}"
    "${cmd[@]}"

    # Activate for subsequent steps: export RUYI_VENV and prepend bin to PATH
    local venv_root
    venv_root="$(cd "$dest" && pwd)"

    echo "${venv_root}/bin" >> "$GITHUB_PATH"
    echo "RUYI_VENV=${venv_root}" >> "$GITHUB_ENV"

    # Set outputs
    echo "venv-root=${venv_root}" >> "$GITHUB_OUTPUT"

    echo "RuyiSDK virtual environment created at ${venv_root}"
}

main
