#!/bin/bash
# Regenerates Resources/Orbitile.icns from docs/images/icon-light.svg (needs macOS qlmanage, sips, iconutil).
set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

qlmanage -t -s 1024 -o "$work" docs/images/icon-light.svg >/dev/null 2>&1
base="$work/icon-light.svg.png"
[ -f "$base" ] || { echo "qlmanage could not render the SVG" >&2; exit 1; }

set="$work/Orbitile.iconset"
mkdir "$set"
for size in 16 32 128 256 512; do
  sips -z $size $size "$base" --out "$set/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$base" --out "$set/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p Resources
iconutil -c icns "$set" -o Resources/Orbitile.icns
echo "wrote Resources/Orbitile.icns"
