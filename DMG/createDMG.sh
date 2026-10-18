#!/bin/bash

# creates, signs, notarizes & staples the LuLu disk image
# expects the (notarized) app at Release/LuLu.app (see: ../build.sh)
#
# Environment overrides:
#   NOTARIZE=0              skip notarization
#   KEYCHAIN_PROFILE=<name> notarytool profile (defaults to objective-see)

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "Release/LuLu.app/Contents/Info.plist")
DMG="LuLu_$VERSION.dmg"

KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-objective-see}"
NOTARIZE="${NOTARIZE:-1}"

printf "\nCreating LuLu Disk Image...\n\n"

#remove any old ones
rm -f LuLu_*.dmg

create-dmg \
  --volname "LuLu v$VERSION" \
  --volicon "LuLu.icns" \
  --background "background.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "LuLu.app" 200 190 \
  --hide-extension "LuLu.app" \
  --app-drop-link 600 190 \
  "$DMG" \
  "Release/"

printf "\nCode signing dmg...\n"

#code sign
codesign --force --sign "Developer ID Application: Objective-See, LLC (VBG97UB4TA)" "$DMG"

if [[ "$NOTARIZE" != "0" ]]; then

    printf "\nNotarizing dmg (this can take a few minutes)...\n"

    #submit & wait
    # note: capture output, so (on failure) we can fetch the log
    SUBMIT_OUTPUT="$(xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1 | tee /dev/stderr)"
    SUBMISSION_ID="$(printf '%s' "$SUBMIT_OUTPUT" | awk '/^ *id:/ {print $2; exit}')"
    STATUS="$(printf '%s' "$SUBMIT_OUTPUT" | awk '/^ *status:/ {print $2}' | tail -1)"

    if [[ "$STATUS" != "Accepted" ]]; then
        printf "\nERROR: notarization failed (status: %s)\n" "${STATUS:-unknown}" >&2
        [[ -n "$SUBMISSION_ID" ]] && xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$KEYCHAIN_PROFILE"
        exit 1
    fi

    printf "\nStapling dmg...\n"

    #staple & validate
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"

    #verify w/ Gatekeeper
    spctl -a -vv -t open --context context:primary-signature "$DMG"
fi

printf "\nDone: %s\n" "$DMG"
shasum -a 256 "$DMG"
