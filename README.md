# ruyisdk/setup-ruyi-action

[Official website](https://ruyisdk.org/en/) | [Developer community](https://ruyisdk.cn) | [Open-source](https://github.com/ruyisdk)

![GitHub License](https://img.shields.io/github/license/ruyisdk/setup-ruyi-action)

A GitHub Action to download and set up the [RuyiSDK Package Manager](https://github.com/ruyisdk/ruyi)
(`ruyi`) in your workflow. It downloads the appropriate binary for the runner
architecture, verifies its SHA256 checksum, and adds it to `PATH`.

## Usage

```yaml
steps:
  - name: Setup ruyi
    uses: ruyisdk/setup-ruyi-action@v1
```

### Pin to a specific version

```yaml
steps:
  - name: Setup ruyi
    uses: ruyisdk/setup-ruyi-action@v1
    with:
      ruyi-version: '0.46.0'
```

### Use a release channel

```yaml
steps:
  - name: Setup latest beta
    uses: ruyisdk/setup-ruyi-action@v1
    with:
      ruyi-version: 'beta'
```

Supported channel values: `latest` / `stable` (latest stable release),
`beta` (latest beta), `alpha` (latest alpha).

### Override architecture

```yaml
steps:
  - name: Setup ruyi for arm64
    uses: ruyisdk/setup-ruyi-action@v1
    with:
      arch: 'arm64'
```

### Use outputs

```yaml
steps:
  - name: Setup ruyi
    id: ruyi
    uses: ruyisdk/setup-ruyi-action@v1

  - name: Print version
    run: |
      echo "Installed version: ${{ steps.ruyi.outputs.ruyi-version }}"
      echo "Binary path: ${{ steps.ruyi.outputs.ruyi-path }}"
      ruyi version
```

### Create a virtual environment

```yaml
steps:
  - name: Setup ruyi with venv
    id: ruyi
    uses: ruyisdk/setup-ruyi-action@v1
    with:
      venv-profile: 'generic'
      venv-toolchain: 'gnu-upstream'
      venv-emulator: 'qemu-user-riscv-upstream'

  - name: Use cross-compiler
    run: |
      echo "Venv at: ${{ steps.ruyi.outputs.venv-root }}"
      # The venv's bin/ is already on PATH
      riscv64-unknown-linux-gnu-gcc --version
```

### Use a custom package repository

```yaml
steps:
  - name: Setup ruyi with custom repo
    uses: ruyisdk/setup-ruyi-action@v1
    with:
      repo-remote: 'https://mirror.example.com/ruyi-repo'
      repo-branch: 'testing'
```

## Inputs

| Input | Description | Default |
|---|---|---|
| `ruyi-version` | Version of `ruyi` to install. A version number (e.g. `0.46.0`) or a channel: `latest`/`stable`, `beta`, `alpha`. | `latest` |
| `arch` | Target architecture. `auto` detects from the runner. Any value is accepted and used as the arch suffix in the download URL. | `auto` |
| `github-token` | GitHub token for API requests (avoids rate limiting). | `${{ github.token }}` |
| `venv-profile` | RuyiSDK virtual environment profile (e.g. `generic`, `sipeed-lpi4a`). If set, a venv is created and activated for subsequent steps. | _(none)_ |
| `venv-toolchain` | Toolchain package specifier(s) for the venv. Separate multiple values with spaces. | _(none)_ |
| `venv-emulator` | Emulator package specifier for the venv. | _(none)_ |
| `venv-name` | Override the virtual environment name. | _(none)_ |
| `venv-sysroot` | Sysroot behaviour: `with` (default), `without`, or a package specifier. | `with` |
| `venv-extra-commands-from` | Extra package(s) to add commands to the venv. Separate multiple values with spaces. | _(none)_ |
| `venv-dest` | Destination path for the virtual environment. | `$RUNNER_TEMP/ruyi-venv` |
| `repo-remote` | Override the RuyiSDK package repository remote URL. | _(none)_ |
| `repo-branch` | Override the RuyiSDK package repository branch. | _(none)_ |

## Outputs

| Output | Description |
|---|---|
| `ruyi-version` | The version of `ruyi` that was installed |
| `ruyi-path` | The absolute path to the installed `ruyi` binary |
| `venv-root` | The absolute path to the created virtual environment (empty if no venv was requested) |

## Supported platforms

See the [official platform support policy](https://ruyisdk.org/en/docs/Other/platform-support/)
for the list of supported architectures and their support tiers.

## 🙋 Contributing

We welcome contributions to RuyiSDK! Please see our [contribution guidelines](./CONTRIBUTING.md)
([中文](./CONTRIBUTING.zh.md)) for details on how to get started.

## ⚖️ License

Copyright &copy; Institute of Software, Chinese Academy of Sciences (ISCAS).
All rights reserved.

`setup-ruyi-action` is licensed under the [Apache 2.0 license](./LICENSE-Apache.txt).

All trademarks referenced herein are property of their respective holders.
