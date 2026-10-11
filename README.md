# Skopea terminal

`skopea` is the terminal client of [Skopea](https://skopea.io): a CLI for scripts and CI, and a
full-screen TUI (`skopea tui`) for people. It is one self-contained binary for macOS and Linux
(Windows through WSL 2), with nothing else to install.

This repository publishes the releases. Its source code is not public.

## Install

### macOS and Linux: Homebrew

```bash
brew install kamorionlabs/tap/skopea
```

### Debian, Ubuntu, WSL 2: apt

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.skopea.io/gpg.key | sudo tee /etc/apt/keyrings/skopea.asc > /dev/null
sudo tee /etc/apt/sources.list.d/skopea.sources > /dev/null <<'EOF'
Types: deb
URIs: https://packages.skopea.io/apt
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/skopea.asc
EOF
sudo apt-get update && sudo apt-get install skopea
```

### Fedora, RHEL, Amazon Linux: dnf

```bash
sudo curl -fsSL https://packages.skopea.io/rpm/skopea.repo -o /etc/yum.repos.d/skopea.repo
sudo dnf install skopea
```

dnf asks you to accept the signing key on first install: accept it only if its fingerprint is the
one under [Signing key](#signing-key).

### Any macOS or Linux: install script

```bash
curl -fsSL https://packages.skopea.io/install.sh | sh
```

It downloads the binary for your machine from these releases, checks it against `SHA256SUMS` and
puts it in `~/.local/bin`. Options: `--channel preview`, `--version <x.y.z>`, `--dir <path>`.

### By hand

Download your platform's file and `SHA256SUMS` from the
[latest release](https://github.com/KamorionLabs/skopea-cli/releases/latest), then:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing     # sha256sum on Linux
chmod +x skopea-darwin-arm64 && mv skopea-darwin-arm64 ~/.local/bin/skopea
```

| Platform | File | Package |
|---|---|---|
| macOS, Apple silicon | `skopea-darwin-arm64` | |
| macOS, Intel | `skopea-darwin-x64` | |
| Linux x86-64 (glibc) | `skopea-linux-x64` | `skopea_<version>_amd64.deb`, `skopea-<version>.x86_64.rpm` |
| Linux arm64 (glibc) | `skopea-linux-arm64` | `skopea_<version>_arm64.deb`, `skopea-<version>.aarch64.rpm` |

## Check it

```bash
skopea version          # the version, the commit it was built from, the API contract it speaks
skopea auth login --context <name>
skopea tui
```

## Channels

| Channel | Receives | Homebrew | apt suite | dnf repository |
|---|---|---|---|---|
| `stable` | final versions (`1.2.0`) | `skopea` | `stable` | `skopea.repo` |
| `preview` | pre-releases (`1.3.0-preview.1`) **and** final versions | `skopea-preview` | `preview` | `skopea-preview.repo` |

To follow the preview channel: `brew install kamorionlabs/tap/skopea-preview`, `Suites: preview`
in the apt source, `rpm/skopea-preview.repo` for dnf, or `--channel preview` with the script.

## Signing key

The apt repository, the dnf metadata and every rpm are signed with the key published at
<https://packages.skopea.io/gpg.key>, fingerprint:

```
312F547A3FBB3A461DBE9F16456FD77DCC3F768B
```

Every release lists the SHA-256 of each file in `SHA256SUMS`.

## Linux keyring

Human logins keep their credential in the desktop keyring through `secret-tool` (the packages
recommend `libsecret-tools` / `libsecret`). Servers, containers and CI use the machine credential
(`SKOPEA_TOKEN`, `SKOPEA_API_URL`, `SKOPEA_ORG`), which needs no keyring.

## License

The binary is licensed under the terms in [LICENSE.md](LICENSE.md). Third-party components and
their licenses are listed in `THIRD_PARTY_NOTICES.txt`, attached to every release.
