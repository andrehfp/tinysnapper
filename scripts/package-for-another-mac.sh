#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="TinySnapper"
APP_PATH="$REPO_ROOT/dist/$APP_NAME.app"
PACKAGE_DIR="$REPO_ROOT/dist/$APP_NAME-portable"
INSTALLER_PATH="$PACKAGE_DIR/install-tinysnapper.sh"
README_PATH="$PACKAGE_DIR/README.txt"
ZIP_PATH="$REPO_ROOT/dist/$APP_NAME-another-mac.zip"

"$REPO_ROOT/scripts/build-app.sh" >/dev/null

rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"
cp -R "$APP_PATH" "$PACKAGE_DIR/"

cat > "$INSTALLER_PATH" <<'EOF'
#!/bin/zsh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP_PATH="$SOURCE_DIR/TinySnapper.app"
TARGET_APP_PATH="/Applications/TinySnapper.app"

if [[ ! -d "$SOURCE_APP_PATH" ]]; then
  echo "TinySnapper.app was not found next to this installer." >&2
  exit 1
fi

rm -rf "$TARGET_APP_PATH"
cp -R "$SOURCE_APP_PATH" "$TARGET_APP_PATH"
xattr -dr com.apple.quarantine "$TARGET_APP_PATH" >/dev/null 2>&1 || true

open "$TARGET_APP_PATH"

cat <<'MSG'
Installed TinySnapper:
/Applications/TinySnapper.app

Next steps on this Mac:
1. Open TinySnapper from /Applications if it did not launch automatically.
2. Run "Capture and Copy Styled" once.
3. When macOS asks for Screen Recording, click Allow.
4. If macOS asks to quit and reopen TinySnapper, do that.
5. Test by pasting into Notes or Preview.

Screen Recording permission cannot be pre-approved by script on another Mac.
MSG
EOF

chmod +x "$INSTALLER_PATH"

cat > "$README_PATH" <<'EOF'
TinySnapper portable package

How to use this on another Mac:
1. Copy this folder or the zip to the other Mac.
2. Unzip it.
3. Run install-tinysnapper.sh.
4. Approve Screen Recording for TinySnapper when macOS prompts.
EOF

cd "$REPO_ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent "$(basename "$PACKAGE_DIR")" "$ZIP_PATH"

echo "Portable package created:"
echo "$ZIP_PATH"
