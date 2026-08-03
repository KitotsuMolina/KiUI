#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/Cargo.toml" | head -n 1)"
VERSION="${VERSION:-$WORKSPACE_VERSION}"
TARGET="${TARGET:-x86_64-unknown-linux-gnu}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BINARY_PATH="${BINARY_PATH:-$ROOT/target/$TARGET/release/kiui}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct)}"
PACKAGE_ROOT="kiui-$VERSION"
ARCHIVE_NAME="$PACKAGE_ROOT-$TARGET.tar.zst"
APPLICATION_ID="dev.kitotsu.kiui"

if [[ "$VERSION" != "$WORKSPACE_VERSION" ]]; then
  printf 'Requested version %s does not match Cargo.toml version %s\n' \
    "$VERSION" "$WORKSPACE_VERSION" >&2
  exit 1
fi

for command in convert install tar zstd; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command" >&2
    exit 127
  fi
done

if [[ ! -x "$BINARY_PATH" ]]; then
  printf 'Release binary not found or not executable: %s\n' "$BINARY_PATH" >&2
  exit 1
fi

if [[ ! "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]]; then
  printf 'SOURCE_DATE_EPOCH must be an integer\n' >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf -- "$STAGING"' EXIT

install -d "$STAGING/$PACKAGE_ROOT/bin"
install -d "$STAGING/$PACKAGE_ROOT/share/applications"
install -d "$STAGING/$PACKAGE_ROOT/share/licenses/kiui"
install -m 0755 "$BINARY_PATH" "$STAGING/$PACKAGE_ROOT/bin/kiui"
install -m 0644 "$ROOT/packaging/linux/$APPLICATION_ID.desktop.in" \
  "$STAGING/$PACKAGE_ROOT/share/applications/$APPLICATION_ID.desktop.in"
install -m 0644 "$ROOT/LICENSE" \
  "$STAGING/$PACKAGE_ROOT/share/licenses/kiui/LICENSE"
install -m 0644 "$ROOT/THIRD_PARTY_LICENSES/MaterialSymbols-LICENSE.txt" \
  "$STAGING/$PACKAGE_ROOT/share/licenses/kiui/MaterialSymbols-LICENSE.txt"

for size in 48 64 128 256 512; do
  icon_dir="$STAGING/$PACKAGE_ROOT/share/icons/hicolor/${size}x${size}/apps"
  install -d "$icon_dir"
  convert "$ROOT/qml/assets/kiui-logo.png" \
    -background none \
    -gravity center \
    -resize "${size}x${size}" \
    -extent "${size}x${size}" \
    -strip \
    "$icon_dir/$APPLICATION_ID.png"
done

install -d "$DIST_DIR"
tar \
  --sort=name \
  --mtime="@$SOURCE_DATE_EPOCH" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --format=posix \
  --pax-option=delete=atime,delete=ctime \
  -C "$STAGING" \
  -cf - \
  "$PACKAGE_ROOT" |
  zstd --compress --ultra -19 --threads=1 --no-progress --force \
    -o "$DIST_DIR/$ARCHIVE_NAME"

printf '%s\n' "$DIST_DIR/$ARCHIVE_NAME"
