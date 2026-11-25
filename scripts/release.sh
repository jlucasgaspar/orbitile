#!/bin/bash
# Builds a release zip of Orbitile.app, ready for GitHub Releases.
#
#   scripts/release.sh 0.1.0                      ad-hoc signed .dmg and .zip (Gatekeeper will warn on first open)
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=orbitile-notary scripts/release.sh 0.1.0
#                                                 signed, notarized and stapled: opens without warnings
#   scripts/release.sh 0.1.0 --publish            also creates the GitHub release (needs gh, signed in)
#
# One-time notarization setup (needs an Apple Developer account):
#   xcrun notarytool store-credentials orbitile-notary --apple-id <id> --team-id <TEAMID> --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: scripts/release.sh <x.y.z> [--publish]" >&2; exit 1; }
publish=false
[ "${2:-}" = "--publish" ] && publish=true

identity="${SIGN_IDENTITY:--}"
profile="${NOTARY_PROFILE:-}"
app="dist/Orbitile.app"
zip="dist/Orbitile-${version}.zip"
dmg="dist/Orbitile-${version}.dmg"

if $publish; then
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit your changes before publishing a release" >&2; exit 1; }
  command -v gh >/dev/null || { echo "gh (GitHub CLI) is required for --publish" >&2; exit 1; }
fi

VERSION="$version" SIGN_IDENTITY="$identity" scripts/build-app.sh

if [ -n "$profile" ]; then
  [ "$identity" != "-" ] || { echo "notarization needs a Developer ID identity in SIGN_IDENTITY" >&2; exit 1; }
  echo "notarizing (this can take a few minutes)..."
  ditto -c -k --norsrc --noextattr --keepParent "$app" dist/notarize.zip
  xcrun notarytool submit dist/notarize.zip --keychain-profile "$profile" --wait
  xcrun stapler staple "$app"
  rm -f dist/notarize.zip
fi

# ditto keeps the code signature intact (plain zip can break it); --norsrc/--noextattr avoid ._ files.
rm -f "$zip"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$zip"
(cd dist && shasum -a 256 "Orbitile-${version}.zip" > "Orbitile-${version}.zip.sha256")

# Disk image: the app next to an Applications shortcut, so installing is one drag.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto --norsrc --noextattr "$app" "$stage/Orbitile.app"
ln -s /Applications "$stage/Applications"
rm -f "$dmg"
hdiutil create -volname "Orbitile" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
if [ "$identity" != "-" ]; then
  codesign --force --sign "$identity" "$dmg"
fi
if [ -n "$profile" ]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
  xcrun stapler staple "$dmg"
fi
(cd dist && shasum -a 256 "Orbitile-${version}.dmg" > "Orbitile-${version}.dmg.sha256")

echo
echo "release artifacts:"
ls -lh "$dmg" "$zip"
cat "$dmg.sha256" "$zip.sha256"
if [ -z "$profile" ]; then
  echo
  echo "note: not notarized. Users must right-click > Open the first time, or run:"
  echo "  xattr -dr com.apple.quarantine /Applications/Orbitile.app"
fi

if $publish; then
  tag="v${version}"
  notes="Orbitile ${version}"
  [ -z "$profile" ] && notes="${notes}"$'\n\n'"Not notarized: right-click the app and choose Open the first time, or run \`xattr -dr com.apple.quarantine /Applications/Orbitile.app\`."
  gh release create "$tag" "$dmg" "$dmg.sha256" "$zip" "$zip.sha256" --title "Orbitile ${version}" --notes "$notes"
else
  echo
  echo "to publish: scripts/release.sh ${version} --publish"
  echo "or upload $dmg, $zip and their .sha256 files at https://github.com/jlucasgaspar/orbitile/releases/new"
fi
