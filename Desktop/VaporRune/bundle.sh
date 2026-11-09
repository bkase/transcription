#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

cargo build --locked
build_dir=$(cargo metadata --locked --no-deps --format-version 1 | python3 -c 'import json, sys; print(json.load(sys.stdin)["target_directory"])')
bundle="$build_dir/Vapor Rune.app"
mkdir -p "$bundle/Contents/MacOS"
install -m 755 "$build_dir/debug/vapor-rune" "$bundle/Contents/MacOS/vapor-rune"
install -m 644 Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign - "$bundle"
printf '%s\n' "$bundle"
