VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "Release/LuLu.app/Contents/Info.plist")

printf "\nCreating LuLu Disk Image...\n\n"

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
  "LuLu_$VERSION.dmg" \
  "Release/"

printf "\nCode signing dmg...\n"

codesign --force --sign "Developer ID Application: Objective-See, LLC (VBG97UB4TA)" LuLu_$VERSION.dmg

printf "Done!\n"
