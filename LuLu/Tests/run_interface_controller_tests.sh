#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$ROOT_DIR/LuLu/App"
SHARED_DIR="$ROOT_DIR/LuLu/Shared"
mkdir -p "$ROOT_DIR/work"
BUILD_DIR="$(mktemp -d "$ROOT_DIR/work/interface-controller-tests.XXXXXX")"
TEST_APP="$BUILD_DIR/InterfaceControllerTests.app"
CONTENTS_DIR="$TEST_APP/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$CONTENTS_DIR/MacOS/InterfaceControllerTests"

cleanup()
{
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]
then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR

mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR/Base.lproj" "$BUILD_DIR/localizations"

cp "$APP_DIR/Assets.xcassets/PrefsList.imageset/icon.png" "$RESOURCES_DIR/PrefsList.png"
cp "$APP_DIR/Assets.xcassets/PrefsMode.imageset/prefsMode Any.pdf" "$RESOURCES_DIR/PrefsMode.pdf"
cp "$APP_DIR/Assets.xcassets/PrefsProfiles.imageset/profiles.png" "$RESOURCES_DIR/PrefsProfiles.png"
cp "$APP_DIR/Assets.xcassets/PrefsRules.imageset/prefsRules Any.pdf" "$RESOURCES_DIR/PrefsRules.pdf"
cp "$APP_DIR/Assets.xcassets/PrefsUpdate.imageset/prefsUpdate Any.pdf" "$RESOURCES_DIR/PrefsUpdate.pdf"
cp "$APP_DIR/Assets.xcassets/LuLuText.imageset/lulu_text.pdf" "$RESOURCES_DIR/LuLuText.pdf"
cp "$APP_DIR/Assets.xcassets/Signed.imageset/signed Any.pdf" "$RESOURCES_DIR/Signed.pdf"
cp "$APP_DIR/Assets.xcassets/Ancestry.imageset/parents any.pdf" "$RESOURCES_DIR/Ancestry.pdf"
cp "$APP_DIR/Assets.xcassets/VTIcon.imageset/VT Any-1.pdf" "$RESOURCES_DIR/VTIcon.pdf"
cp "$APP_DIR/Assets.xcassets/Icon.imageset/LoginItem Any.pdf" "$RESOURCES_DIR/Icon.pdf"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>InterfaceControllerTests</string>
    <key>CFBundleIdentifier</key><string>com.objective-see.lulu.interface-controller-tests</string>
    <key>CFBundleName</key><string>InterfaceControllerTests</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST

xcrun ibtool --compile "$RESOURCES_DIR/Base.lproj/Preferences.nib" "$APP_DIR/Base.lproj/Preferences.xib"
xcrun ibtool --compile "$RESOURCES_DIR/Base.lproj/Rules.nib" "$APP_DIR/Base.lproj/Rules.xib"
xcrun ibtool --compile "$RESOURCES_DIR/Base.lproj/AlertWindow.nib" "$APP_DIR/Base.lproj/AlertWindow.xib"

xcrun xcstringstool compile --output-directory "$BUILD_DIR/localizations" "$APP_DIR/mul.lproj/Preferences.xcstrings"
xcrun xcstringstool compile --output-directory "$BUILD_DIR/localizations" "$APP_DIR/mul.lproj/Rules.xcstrings"
xcrun xcstringstool compile --output-directory "$BUILD_DIR/localizations" "$APP_DIR/mul.lproj/AlertWindow.xcstrings"
xcrun xcstringstool compile --output-directory "$BUILD_DIR/localizations" "$SHARED_DIR/Localizable.xcstrings"

for language in zh-Hant ur
do
    mkdir -p "$RESOURCES_DIR/$language.lproj"
    xcrun ibtool --strings-file "$BUILD_DIR/localizations/$language.lproj/Preferences.strings" \
        --compile "$RESOURCES_DIR/$language.lproj/Preferences.nib" "$APP_DIR/Base.lproj/Preferences.xib"
    xcrun ibtool --strings-file "$BUILD_DIR/localizations/$language.lproj/Rules.strings" \
        --compile "$RESOURCES_DIR/$language.lproj/Rules.nib" "$APP_DIR/Base.lproj/Rules.xib"
    xcrun ibtool --strings-file "$BUILD_DIR/localizations/$language.lproj/AlertWindow.strings" \
        --compile "$RESOURCES_DIR/$language.lproj/AlertWindow.nib" "$APP_DIR/Base.lproj/AlertWindow.xib"
    cp "$BUILD_DIR/localizations/$language.lproj/Localizable.strings" "$RESOURCES_DIR/$language.lproj/Localizable.strings"
done

xcrun clang \
    -fobjc-arc -fblocks -fmodules -mmacosx-version-min=10.15 \
    -Wall -Wextra \
    -Wno-deprecated-declarations -Wno-objc-protocol-method-implementation \
    -Wno-incomplete-implementation \
    -Wno-sign-compare -Wno-unused-parameter -Wno-nonportable-include-path \
    -Wno-shadow-ivar -Wno-semicolon-before-method-body \
    -Wno-objc-property-implementation -Wno-unused-label \
    -I"$APP_DIR" -I"$SHARED_DIR" \
    -framework Cocoa -framework OSLog -framework Security \
    "$SCRIPT_DIR/test_interface_controllers.m" \
    "$APP_DIR/PrefsWindowController.m" \
    "$APP_DIR/RulesWindowController.m" \
    "$APP_DIR/AlertWindowController.m" \
    "$APP_DIR/ParentsWindowController.m" \
    "$APP_DIR/SigningInfoViewController.m" \
    "$APP_DIR/RuleRow.m" \
    "$APP_DIR/3rd-party/OrderedDictionary.m" \
    "$SHARED_DIR/Rule.m" \
    -o "$EXECUTABLE"

for language in en zh-Hant ur
do
    OS_ACTIVITY_MODE=disable TEST_LANGUAGE="$language" "$EXECUTABLE" -AppleLanguages "($language)"
done
