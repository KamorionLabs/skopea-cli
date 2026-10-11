#!/bin/sh
# Installs the `skopea` terminal (CLI and TUI) on macOS or Linux (WSL 2 included).
#
#   curl -fsSL https://packages.skopea.io/install.sh | sh
#   curl -fsSL https://packages.skopea.io/install.sh | sh -s -- --channel preview
#   curl -fsSL https://packages.skopea.io/install.sh | sh -s -- --version 0.1.0 --dir /usr/local/bin
#
# Downloads the release binary for this machine and SHA256SUMS, refuses a binary whose checksum
# does not match, and puts it in ~/.local/bin (or --dir). Nothing else on the machine is changed.
# On Linux, the apt and dnf repositories also keep skopea up to date:
# https://github.com/KamorionLabs/skopea-cli#readme
set -eu

PACKAGES_URL="${SKOPEA_PACKAGES_URL:-https://packages.skopea.io}"
RELEASES_URL="${SKOPEA_RELEASES_URL:-https://github.com/KamorionLabs/skopea-cli/releases/download}"
channel=stable
version=
dir="${SKOPEA_INSTALL_DIR:-$HOME/.local/bin}"

fail() { echo "skopea install: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --channel) [ $# -ge 2 ] || fail "--channel needs a value"; channel="$2"; shift 2 ;;
    --version) [ $# -ge 2 ] || fail "--version needs a value"; version="${2#v}"; shift 2 ;;
    --dir) [ $# -ge 2 ] || fail "--dir needs a value"; dir="$2"; shift 2 ;;
    -h|--help) echo "usage: install.sh [--channel stable|preview] [--version X.Y.Z] [--dir DIR]"; exit 0 ;;
    *) fail "unknown option $1 (expected --channel, --version or --dir)" ;;
  esac
done
case "$channel" in stable|preview) ;; *) fail "--channel must be stable or preview" ;; esac

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform=darwin-arm64 ;;
  Darwin-x86_64) platform=darwin-x64 ;;
  Linux-x86_64) platform=linux-x64 ;;
  Linux-aarch64|Linux-arm64) platform=linux-arm64 ;;
  *) fail "unsupported platform $(uname -s) $(uname -m) (macOS and Linux, x86-64 or arm64; Windows through WSL 2)" ;;
esac

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  fail "curl or wget is required"
fi

if command -v sha256sum >/dev/null 2>&1; then
  digest() { sha256sum "$1" | cut -d ' ' -f 1; }
elif command -v shasum >/dev/null 2>&1; then
  digest() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
else
  fail "sha256sum or shasum is required to verify the download"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

if [ -z "$version" ]; then
  fetch "$PACKAGES_URL/channels/$channel" "$tmp/channel" || fail "cannot read the $channel channel at $PACKAGES_URL"
  version="$(tr -d ' \r\n' < "$tmp/channel")"
  [ -n "$version" ] || fail "the $channel channel has no release yet"
fi

base="$RELEASES_URL/v$version"
echo "Downloading skopea $version ($platform)..."
fetch "$base/skopea-$platform" "$tmp/skopea" || fail "no skopea $version for $platform at $base"
fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || fail "no SHA256SUMS for $version at $base"

expected="$(awk -v f="skopea-$platform" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS")"
[ -n "$expected" ] || fail "SHA256SUMS of $version lists no skopea-$platform"
actual="$(digest "$tmp/skopea")"
[ "$actual" = "$expected" ] || fail "checksum mismatch for skopea-$platform (expected $expected, got $actual): not installed"

mkdir -p "$dir"
chmod 0755 "$tmp/skopea"
mv "$tmp/skopea" "$dir/skopea"
echo "Installed $dir/skopea"
"$dir/skopea" --version 2>/dev/null || true

case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "Note: $dir is not on your PATH. Add it, for example: export PATH=\"$dir:\$PATH\"" ;;
esac
