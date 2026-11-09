#!/bin/bash
set -euo pipefail
cd "$SRCROOT/.."
export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/target}"
case "$PLATFORM_NAME" in
  iphonesimulator) rust_target=aarch64-apple-ios-sim ;;
  iphoneos) rust_target=aarch64-apple-ios ;;
  *) echo "Unsupported iOS platform $PLATFORM_NAME" >&2; exit 1 ;;
esac
case "$CONFIGURATION" in
  Release) rust_profile=release ;;
  *) rust_profile=dev ;;
esac
cargo build --locked --lib --profile "$rust_profile" --target "$rust_target"
if [[ "$rust_profile" == dev ]]; then rust_profile=debug; fi
mkdir -p "$DERIVED_FILE_DIR"
/usr/bin/install -m 644 "$CARGO_TARGET_DIR/$rust_target/$rust_profile/libvapor_rune.a" "$DERIVED_FILE_DIR/libvapor_rune.a"
