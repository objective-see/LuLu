printf "\nCreating LuLu Disk Image...\n\n"

create-dmg \
  --volname "LuLu v2.6.3" \
  --volicon "LuLu.icns" \
  --background "background.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "LuLu.app" 200 190 \
  --hide-extension "LuLu.app" \
  --app-drop-link 600 190 \
  "LuLu_2.6.3.dmg" \
  "Release/"

printf "\nCode signing dmg...\n"

codesign --force --sign "Developer ID Application: Objective-See, LLC (VBG97UB4TA)" LuLu_2.6.3.dmg

printf "Done!\n"
