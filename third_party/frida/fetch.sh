#!/bin/bash
# Fetch the frida-core devkit (arm64 + x86_64, combined into a universal static lib).
# Run once before the first build, or let the Xcode Run Script phase call it on demand.

set -euo pipefail

cd "$(dirname "$0")"
VERSION="$(cat VERSION)"

if [ -f libfrida-core.a ] && [ -f frida-core.h ]; then
  echo "frida-core devkit $VERSION already present; skipping."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

base="https://github.com/frida/frida/releases/download/${VERSION}"

for arch in arm64 x86_64; do
  tarball="frida-core-devkit-${VERSION}-macos-${arch}.tar.xz"
  echo "Downloading ${tarball}"
  curl --fail --location --silent --show-error --output "${tmp}/${tarball}" "${base}/${tarball}"
  mkdir -p "${tmp}/${arch}"
  tar -xf "${tmp}/${tarball}" -C "${tmp}/${arch}"
done

# Header is identical across arches; take one.
cp "${tmp}/arm64/frida-core.h" frida-core.h

# Fuse the two static libs into a universal one.
lipo -create \
  "${tmp}/arm64/libfrida-core.a" \
  "${tmp}/x86_64/libfrida-core.a" \
  -output libfrida-core.a

echo "frida-core devkit $VERSION installed:"
lipo -info libfrida-core.a
