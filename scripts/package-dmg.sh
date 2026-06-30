#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Pan Notes"
EXECUTABLE_NAME="PanNotes"
BUNDLE_ID="dev.xuqingru.pannotes"
VERSION="0.3.1"
BUILD_CONFIG="release"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/PanNotes-$VERSION.dmg"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG" --product "$EXECUTABLE_NAME"

rm -rf "$APP_PATH" "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$DMG_ROOT"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
cp -R "$BUILD_DIR/MASShortcut_MASShortcut.bundle" "$APP_PATH/Contents/Resources/MASShortcut_MASShortcut.bundle"
cp "$ROOT_DIR/Sources/PanNotesApp/Resources/pan.svg" "$APP_PATH/Contents/Resources/pan.svg"
cp "$ROOT_DIR/Sources/PanNotesApp/Resources/pan.png" "$APP_PATH/Contents/Resources/pan.png"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>pan.png</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

test -f "$APP_PATH/Contents/Resources/pan.png"
test "$(plutil -extract CFBundleIconFile raw -o - "$APP_PATH/Contents/Info.plist")" = "pan.png"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

cp -R "$APP_PATH" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"
rm -rf "$DMG_ROOT"

echo "$APP_PATH"
echo "$DMG_PATH"
