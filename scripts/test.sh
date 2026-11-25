#!/bin/bash
# Runs the Swift Testing suite. With full Xcode a plain `swift test` is enough; with only the
# Command Line Tools the Testing framework is installed but not on the default search paths.
set -euo pipefail
cd "$(dirname "$0")/.."

clt=/Library/Developer/CommandLineTools
if [ "$(xcode-select -p)" = "$clt" ] && [ -d "$clt/Library/Developer/Frameworks/Testing.framework" ]; then
  f="$clt/Library/Developer/Frameworks"
  l="$clt/Library/Developer/usr/lib"
  exec swift test -Xswiftc -F -Xswiftc "$f" -Xlinker -F -Xlinker "$f" \
    -Xlinker -rpath -Xlinker "$f" -Xlinker -rpath -Xlinker "$l" "$@"
fi
exec swift test "$@"
