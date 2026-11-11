#!/usr/bin/env bash
# Assembles the apt and dnf repositories of the public `skopea` distribution, signed.
#
#   packaging/build-repos.sh <packages-dir> <plan.json> <out-dir> <base-url>
#
# It runs in the `publish` job of .github/workflows/publish.yml, the only job that holds the
# signing key: it lives in THIS repository so that what runs next to the key is reviewed here,
# never fetched from elsewhere (moved from the private repository, #965 S6 there).
#
# <packages-dir>/<version>/ holds the .deb and .rpm files of each published version.
# <plan.json> is the `stage` job's plan (the private repository's channels rule): the versions each channel
# serves, newest first. The tree is rebuilt from scratch every time, from the published releases:
# no state lives in the bucket, so a lost or damaged bucket is one workflow run away.
#
# SKOPEA_GPG_KEY_ID names the signing key, already imported into the gpg keyring.
# Requires apt-ftparchive (apt-utils), createrepo_c, gpg and jq.
#
# Layout (served as is under <base-url>):
#   gpg.key                                   the public key (armored)
#   channels/<channel>                        the newest version of the channel (install.sh)
#   apt/dists/<channel>/{InRelease,Release,Release.gpg,main/binary-<arch>/Packages{,.gz}}
#   apt/pool/<channel>/*.deb
#   rpm/<channel>/{*.rpm,repodata/}           repodata/repomd.xml.asc signs the metadata
#   rpm/skopea[-preview].repo                 the .repo file a dnf client adds
set -euo pipefail

packages_dir="$(cd "$1" && pwd)"
plan="$2"
out="$3"
base_url="${4%/}"
key="${SKOPEA_GPG_KEY_ID:?SKOPEA_GPG_KEY_ID names the signing key}"

rm -rf "$out"
mkdir -p "$out/channels"
gpg --batch --armor --export "$key" > "$out/gpg.key"
test -s "$out/gpg.key" || { echo "no public key for $key in the keyring" >&2; exit 1; }

sign_detached() { gpg --batch --yes --local-user "$key" --armor --detach-sign --output "$2" "$1"; }

for channel in $(jq -r 'keys[]' "$plan"); do
  versions="$(jq -r --arg c "$channel" '.[$c][]' "$plan")"
  if [ -z "$versions" ]; then
    echo "channel $channel: no version yet, not published"
    continue
  fi
  newest="$(printf '%s\n' "$versions" | head -n 1)"
  printf '%s\n' "$newest" > "$out/channels/$channel"

  apt_pool="$out/apt/pool/$channel"
  rpm_dir="$out/rpm/$channel"
  mkdir -p "$apt_pool" "$rpm_dir"
  for version in $versions; do
    found=0
    for file in "$packages_dir/$version"/*.deb; do [ -e "$file" ] && cp "$file" "$apt_pool/" && found=1; done
    for file in "$packages_dir/$version"/*.rpm; do [ -e "$file" ] && cp "$file" "$rpm_dir/"; done
    [ "$found" = 1 ] || echo "channel $channel: $version has no Linux packages (released before they existed), skipped"
  done

  # apt: one suite per channel, one component, two architectures.
  (
    cd "$out/apt"
    for arch in amd64 arm64; do
      dir="dists/$channel/main/binary-$arch"
      mkdir -p "$dir"
      apt-ftparchive --arch "$arch" packages "pool/$channel" > "$dir/Packages"
      gzip -9nkf "$dir/Packages"
    done
    apt-ftparchive \
      -o APT::FTPArchive::Release::Origin=Skopea \
      -o APT::FTPArchive::Release::Label=Skopea \
      -o APT::FTPArchive::Release::Suite="$channel" \
      -o APT::FTPArchive::Release::Codename="$channel" \
      -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
      -o APT::FTPArchive::Release::Components=main \
      -o APT::FTPArchive::Release::Description="Skopea terminal, $channel channel" \
      release "dists/$channel" > "dists/$channel/Release.tmp"
    mv "dists/$channel/Release.tmp" "dists/$channel/Release"
    gpg --batch --yes --local-user "$key" --clearsign --output "dists/$channel/InRelease" "dists/$channel/Release"
    sign_detached "dists/$channel/Release" "dists/$channel/Release.gpg"
  )

  # dnf: one repository per channel; dnf picks the architecture.
  createrepo_c --quiet --update "$rpm_dir"
  sign_detached "$rpm_dir/repodata/repomd.xml" "$rpm_dir/repodata/repomd.xml.asc"

  name="skopea"; title="Skopea terminal"
  if [ "$channel" != stable ]; then name="skopea-$channel"; title="Skopea terminal ($channel)"; fi
  cat > "$out/rpm/$name.repo" <<EOF
[$name]
name=$title
baseurl=$base_url/rpm/$channel
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$base_url/gpg.key
EOF
done

find "$out" -type f | sort | sed "s|^$out/||"
