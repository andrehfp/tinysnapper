#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP_PATH="$REPO_ROOT/dist/TinySnapper.app"
TARGET_APP_PATH="/Applications/TinySnapper.app"
BUNDLE_ID="${TINYSNAPPER_BUNDLE_ID:-com.andreprado.tinysnapper.local}"
CODE_SIGN_IDENTITY="${TINYSNAPPER_CODESIGN_IDENTITY:--}"

"$REPO_ROOT/scripts/build-app.sh" >/dev/null

rm -rf "$TARGET_APP_PATH"
cp -R "$SOURCE_APP_PATH" "$TARGET_APP_PATH"
codesign_args=(--force --sign "$CODE_SIGN_IDENTITY" --identifier "$BUNDLE_ID")

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--timestamp --options runtime)
fi

/usr/bin/codesign --remove-signature "$TARGET_APP_PATH" >/dev/null 2>&1 || true
/usr/bin/codesign "${codesign_args[@]}" "$TARGET_APP_PATH" >/dev/null 2>&1 || true

echo "Installed app:"
echo "$TARGET_APP_PATH"
