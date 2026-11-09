#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -sdk "$sdk" \
  -target arm64-apple-ios17.0-simulator -parse-as-library \
  -module-name VaporHotShell -D RUNE_HOT_HOST -D DEBUG \
  -import-objc-header ios/Sources/VaporBridge.h -emit-library -static \
  ios/Sources/VaporApp.swift ios/Sources/VaporSurface.swift -o "$1"
