#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${TINYSNAPPER_APP_NAME:-TinySnapper}"
APP_PATH="$REPO_ROOT/dist/$APP_NAME.app"
RELEASE_DIR="$REPO_ROOT/dist/release"
BUNDLE_ID="${TINYSNAPPER_BUNDLE_ID:-com.andreprado.tinysnapper}"
VERSION="${TINYSNAPPER_VERSION:-}"
BUILD_NUMBER="${TINYSNAPPER_BUILD_NUMBER:-}"
CODE_SIGN_IDENTITY="${TINYSNAPPER_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${TINYSNAPPER_NOTARY_PROFILE:-}"
ARCHS_STRING="${TINYSNAPPER_ARCHS:-arm64}"
SKIP_NOTARIZATION="${TINYSNAPPER_SKIP_NOTARIZATION:-0}"
SUBMISSION_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-build-$BUILD_NUMBER-notary.zip"
FINAL_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-mac.zip"

if [[ -z "$VERSION" ]]; then
  echo "TINYSNAPPER_VERSION is required." >&2
  exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "TINYSNAPPER_BUILD_NUMBER is required." >&2
  exit 1
fi

if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  echo "TINYSNAPPER_CODESIGN_IDENTITY is required for production releases." >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
  echo "TINYSNAPPER_NOTARY_PROFILE is required unless TINYSNAPPER_SKIP_NOTARIZATION=1." >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -f "$SUBMISSION_ZIP" "$FINAL_ZIP"

export TINYSNAPPER_BUNDLE_ID="$BUNDLE_ID"
export TINYSNAPPER_VERSION="$VERSION"
export TINYSNAPPER_BUILD_NUMBER="$BUILD_NUMBER"
export TINYSNAPPER_CODESIGN_IDENTITY="$CODE_SIGN_IDENTITY"
export TINYSNAPPER_ARCHS="$ARCHS_STRING"

"$REPO_ROOT/scripts/build-app.sh"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$SUBMISSION_ZIP"

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  /usr/bin/xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$APP_PATH"
  /usr/bin/xcrun stapler validate "$APP_PATH"
fi

/usr/sbin/spctl -a -vv "$APP_PATH"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"

echo "Release app:"
echo "$APP_PATH"
echo "Release zip:"
echo "$FINAL_ZIP"
