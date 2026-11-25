#!/bin/bash
# Builds dist/Orbitile.app (release, menu bar only, no Dock icon).
#
#   scripts/build-app.sh                       ad-hoc signature (local use)
#   SIGN_IDENTITY="Developer ID ..." scripts/build-app.sh
#
# macOS ties the Accessibility grant to the code signature. An ad-hoc signature changes on every
# build, so after rebuilding you may have to remove and re-add Orbitile in
# System Settings > Privacy & Security > Accessibility. A stable identity avoids that.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${VERSION:-0.1.0}"
identity="${SIGN_IDENTITY:--}"
app="dist/Orbitile.app"

swift build -c release --product Orbitile
bin="$(swift build -c release --show-bin-path)/Orbitile"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Orbitile"
[ -f Resources/Orbitile.icns ] || scripts/make-icon.sh
cp Resources/Orbitile.icns "$app/Contents/Resources/Orbitile.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Orbitile</string>
  <key>CFBundleDisplayName</key><string>Orbitile</string>
  <key>CFBundleIdentifier</key><string>app.orbitile.Orbitile</string>
  <key>CFBundleExecutable</key><string>Orbitile</string>
  <key>CFBundleIconFile</key><string>Orbitile</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${version}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signatures default to a cdhash requirement, which changes on every build and makes macOS
# drop the Accessibility/Input Monitoring grant. Pin the requirement to the bundle id instead.
req=()
[ "$identity" = "-" ] && req=(-r='designated => identifier "app.orbitile.Orbitile"')
codesign --force --options runtime --sign "$identity" ${req[@]+"${req[@]}"} "$app"
codesign --verify --verbose=1 "$app"
echo "built $app (signed with: $identity)"
