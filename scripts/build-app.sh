#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${TINYSNAPPER_APP_NAME:-TinySnapper}"
APP_DIR="$REPO_ROOT/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BIN_NAME="${TINYSNAPPER_BIN_NAME:-tinysnapper}"
BUNDLE_ID="${TINYSNAPPER_BUNDLE_ID:-com.andreprado.tinysnapper.local}"
VERSION="${TINYSNAPPER_VERSION:-0.1.0}"
BUILD_NUMBER="${TINYSNAPPER_BUILD_NUMBER:-1}"
ARCHS_STRING="${TINYSNAPPER_ARCHS:-arm64}"
CODE_SIGN_IDENTITY="${TINYSNAPPER_CODESIGN_IDENTITY:--}"
ICON_SOURCE_PATH="$REPO_ROOT/tinysnapper-logo.png"
ICON_NAME="AppIcon"
ICON_PATH="$RESOURCES_DIR/$ICON_NAME.icns"
SCRATCH_PATH="${TINYSNAPPER_SCRATCH_PATH:-/tmp/tinysnapper-build-app}"

ARCHS=(${=ARCHS_STRING})
BUILD_ARGS=(-c release --scratch-path "$SCRATCH_PATH")

for arch in "${ARCHS[@]}"; do
  BUILD_ARGS+=(--arch "$arch")
done

codesign_path() {
  local path="$1"
  local identifier="${2:-}"
  local codesign_args=(--force --sign "$CODE_SIGN_IDENTITY")

  if [[ -n "$identifier" ]]; then
    codesign_args+=(--identifier "$identifier")
  fi

  if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign_args+=(--timestamp --options runtime)
  fi

  /usr/bin/codesign --remove-signature "$path" >/dev/null 2>&1 || true
  /usr/bin/codesign "${codesign_args[@]}" "$path"
}

mkdir -p "$REPO_ROOT/dist"

cd "$REPO_ROOT"
swift build "${BUILD_ARGS[@]}"

BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN_PATH="$BIN_DIR/$BIN_NAME"
RESOURCE_BUNDLE_PATH="$BIN_DIR/${BIN_NAME}_TinySnapper.bundle"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected executable not found at: $BIN_PATH" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE_PATH" ]]; then
  echo "Expected resource bundle not found at: $RESOURCE_BUNDLE_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$BIN_NAME"
codesign_path "$MACOS_DIR/$BIN_NAME" "$BUNDLE_ID"

cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"

if [[ -f "$ICON_SOURCE_PATH" ]]; then
  ICONSET_DIR="$(mktemp -d "$REPO_ROOT/dist/appicon.XXXXXX.iconset")"
  for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    /usr/bin/sips -z "$retina_size" "$retina_size" "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done
  /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"
  rm -rf "$ICONSET_DIR"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$BIN_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign_path "$APP_DIR" "$BUNDLE_ID"

echo "Built app bundle:"
echo "$APP_DIR"
