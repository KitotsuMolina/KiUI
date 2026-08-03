#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/Cargo.toml" | head -n 1)"
VERSION="${VERSION:-$WORKSPACE_VERSION}"
TARGET="${TARGET:-x86_64-unknown-linux-gnu}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BINARY_PATH="${BINARY_PATH:-$ROOT/target/$TARGET/release/kiui}"
REPOSITORY="${REPOSITORY:-KitotsuMolina/KiUI}"
TAG="${TAG:-v$VERSION}"
CHANNEL="${CHANNEL:-stable}"
COMMIT="${COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
ARCHIVE_NAME="kiui-$VERSION-$TARGET.tar.zst"
SBOM_NAME="kiui-$VERSION-$TARGET.spdx.json"
MANIFEST_NAME="kiui-$VERSION-$TARGET.manifest.json"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
SBOM_PATH="$DIST_DIR/$SBOM_NAME"
MANIFEST_PATH="$DIST_DIR/$MANIFEST_NAME"
PACKAGE_ROOT="kiui-$VERSION"
APPLICATION_ID="dev.kitotsu.kiui"

for command in jq readelf sha256sum stat tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command" >&2
    exit 127
  fi
done

if [[ "$VERSION" != "$WORKSPACE_VERSION" ]]; then
  printf 'Requested version %s does not match Cargo.toml version %s\n' \
    "$VERSION" "$WORKSPACE_VERSION" >&2
  exit 1
fi

if [[ "$TAG" != "v$VERSION" ]]; then
  printf 'Tag %s does not match Cargo.toml version %s\n' "$TAG" "$VERSION" >&2
  exit 1
fi

if [[ ! "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'Commit must be a full 40-character Git SHA\n' >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" || ! -f "$SBOM_PATH" || ! -x "$BINARY_PATH" ]]; then
  printf 'Archive, SBOM, or release binary is missing\n' >&2
  exit 1
fi

DETECTED_GLIBC="$(
  readelf --version-info "$BINARY_PATH" |
    grep -oE 'GLIBC_[0-9]+\.[0-9]+' |
    sed 's/^GLIBC_//' |
    sort -V |
    tail -n 1
)"
GLIBC_MINIMUM="${GLIBC_MINIMUM:-$DETECTED_GLIBC}"
if [[ ! "$GLIBC_MINIMUM" =~ ^[0-9]+\.[0-9]+$ ]]; then
  printf 'Could not determine the minimum required glibc version\n' >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf -- "$STAGING"' EXIT
tar --zstd -xf "$ARCHIVE_PATH" -C "$STAGING"
PAYLOAD_ROOT="$STAGING/$PACKAGE_ROOT"

sha256() {
  sha256sum "$1" | cut -d ' ' -f 1
}

payload_entry() {
  local path="$1"
  local kind="$2"
  local mode="$3"
  local file="$PAYLOAD_ROOT/$path"
  jq -n \
    --arg path "$path" \
    --arg kind "$kind" \
    --arg mode "$mode" \
    --argjson size_bytes "$(stat -c %s "$file")" \
    --arg sha256 "$(sha256 "$file")" \
    '{path: $path, kind: $kind, mode: $mode, size_bytes: $size_bytes, sha256: $sha256}'
}

PAYLOAD="$(
  jq -s '.' <<EOF
$(payload_entry "bin/kiui" "executable" "0755")
$(payload_entry "share/applications/$APPLICATION_ID.desktop.in" "desktop-entry-template" "0644")
$(payload_entry "share/icons/hicolor/48x48/apps/$APPLICATION_ID.png" "icon" "0644")
$(payload_entry "share/icons/hicolor/64x64/apps/$APPLICATION_ID.png" "icon" "0644")
$(payload_entry "share/icons/hicolor/128x128/apps/$APPLICATION_ID.png" "icon" "0644")
$(payload_entry "share/icons/hicolor/256x256/apps/$APPLICATION_ID.png" "icon" "0644")
$(payload_entry "share/icons/hicolor/512x512/apps/$APPLICATION_ID.png" "icon" "0644")
$(payload_entry "share/licenses/kiui/LICENSE" "license" "0644")
$(payload_entry "share/licenses/kiui/MaterialSymbols-LICENSE.txt" "license" "0644")
EOF
)"

jq -n \
  --arg version "$VERSION" \
  --arg repository "$REPOSITORY" \
  --arg tag "$TAG" \
  --arg channel "$CHANNEL" \
  --arg commit "$COMMIT" \
  --arg target "$TARGET" \
  --arg glibc_minimum "$GLIBC_MINIMUM" \
  --arg archive_name "$ARCHIVE_NAME" \
  --arg archive_sha "$(sha256 "$ARCHIVE_PATH")" \
  --argjson archive_size "$(stat -c %s "$ARCHIVE_PATH")" \
  --arg sbom_name "$SBOM_NAME" \
  --arg sbom_sha "$(sha256 "$SBOM_PATH")" \
  --arg application_id "$APPLICATION_ID" \
  --argjson payload "$PAYLOAD" \
  '{
    schema_version: 1,
    kind: "kitotsu.release-artifact",
    distribution_contract: "1.0",
    product: {
      id: "kiui",
      version: $version,
      license: "GPL-3.0-or-later",
      repository: $repository,
      contract_version: "1.0"
    },
    release: {
      tag: $tag,
      channel: $channel,
      commit: $commit
    },
    platform: {
      os: "linux",
      arch: "x86_64",
      target: $target,
      libc: {
        family: "glibc",
        minimum: $glibc_minimum
      }
    },
    artifact: {
      file_name: $archive_name,
      format: "tar.zst",
      size_bytes: $archive_size,
      sha256: $archive_sha
    },
    payload: $payload,
    entrypoints: [
      {
        name: "kiui",
        path: "bin/kiui"
      }
    ],
    requirements: {
      modules: [
        {id: "kitsune-compositor", constraint: ">=0.1.0, <0.2.0", optional: false},
        {id: "kitowall", constraint: ">=0.1.0, <0.2.0", optional: true},
        {id: "kilivepaper", constraint: ">=0.1.0, <0.2.0", optional: true},
        {id: "kitsune", constraint: ">=0.1.0, <0.2.0", optional: true}
      ],
      host_capabilities: [
        {id: "session.wayland", optional: false},
        {id: "runtime.qt6", constraint: ">=6.4", optional: false}
      ]
    },
    integrations: {
      desktop_entries: [
        {
          application_id: $application_id,
          template: ("share/applications/" + $application_id + ".desktop.in"),
          entrypoint: "kiui",
          icons: [48, 64, 128, 256, 512] | map({
            source: ("share/icons/hicolor/" + (tostring) + "x" + (tostring) + "/apps/" + $application_id + ".png"),
            theme: "hicolor",
            size: .,
            format: "png"
          })
        }
      ]
    },
    sbom: {
      file_name: $sbom_name,
      format: "spdx-json",
      sha256: $sbom_sha
    }
  }' >"$MANIFEST_PATH"

jq -e '
  .schema_version == 1 and
  .kind == "kitotsu.release-artifact" and
  .product.id == "kiui" and
  (.payload | length) == 9 and
  (.integrations.desktop_entries | length) == 1
' "$MANIFEST_PATH" >/dev/null

printf '%s\n' "$MANIFEST_PATH"
