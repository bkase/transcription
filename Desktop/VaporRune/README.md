# Vapor on Rune

A macOS and iOS slice of Vapor's audio recording flow. Start from the Timeline, pause or resume the recording, choose a speaker count, optionally name the speakers, and stop and save. A saved recording can be found by title or speaker name and played from its detail screen. Back asks before discarding a take.

The port reads the shared [Vapor tokens](../../tokens.json) and uses San Francisco and SF Symbols from the host OS. The recording header and speaker card follow the SwiftUI layouts. The iOS host honors the safe areas and keyboard insets. Recording uses Rune's AVFoundation backend. Speaker names are local recording metadata. This slice records audio only.

## Run on macOS

From this directory, run `cargo run --locked`. To build a Finder-launchable app with its own microphone usage description, run `./bundle.sh` and open the printed app path. Recordings are stored in `~/Library/Application Support/Vapor Rune`.

## Run on iOS

The app embeds Rune's `LayerHost` in a UIKit view backed by `CAMetalLayer`. Rune draws the shared views and handles touch and motion. UIKit hosts the keyboard fields, presents Rune controls to accessibility, and configures the audio session. The [Rune fork](https://github.com/bkase/rune) enables native AVFoundation capture and playback for embedded iOS apps.

On Apple silicon, install the pinned Rust toolchain and its two iOS targets, then generate the Xcode project.

```sh
rustup target add aarch64-apple-ios-sim aarch64-apple-ios
xcodegen generate --spec ios/project.yml
```

For a headless simulator run, set `SIMULATOR_ID` to the desired device UDID and run the following from this directory. The permission grant applies to the simulator test app. A normal device launch asks for permission when recording starts.

```sh
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcodebuild build-for-testing -project ios/VaporRune.xcodeproj -scheme VaporRune \
  -derivedDataPath target/ios -destination "id=$SIMULATOR_ID" CODE_SIGNING_ALLOWED=NO
xcrun simctl install "$SIMULATOR_ID" target/ios/Build/Products/Debug-iphonesimulator/Vapor.app
xcrun simctl privacy "$SIMULATOR_ID" grant microphone com.vapor.rune-ios
xcodebuild test-without-building -project ios/VaporRune.xcodeproj -scheme VaporRune \
  -derivedDataPath target/ios -destination "id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

For a physical iPhone, select a signing team for the VaporRune app target in the generated Xcode project.

## Hot reload on the iOS Simulator

Use the pinned Rune fork checkout, Dioxus CLI 0.7.10, and Python 3.13 or later.
From this directory, start a native simulator dev session. The launcher boots
the selected simulator headlessly and installs a separate `com.vapor.rune-ios.hot`
bundle. Save a Rust view or handler body edit in `src/ui.rs` to patch the running app.
The launcher reports when the first patched frame is presented. Model layout,
Swift shell, and other incompatible changes rebuild and relaunch.

```sh
/path/to/rune/scripts/rune-hot --manifest "$PWD/Cargo.toml" --patch src/ui.rs \
  --ios-simulator "$SIMULATOR_ID" --prepare ios/prepare-hot.sh --features ios-hot
```

The repeatable check uses a disposable source copy and XCUITest. It pauses a
recording, exercises rejection of an incomplete edit, patches the view and Save
handler, resumes and saves the recording, then reverts the patch in the same process.

```sh
python3 ios/check-hot.py /path/to/rune/scripts/rune-hot "$SIMULATOR_ID"
```

The test launcher grants microphone permission to the simulator dev bundle.
Physical iPhones use the normal native build.

## Replay offscreen

```sh
cargo build --locked
python3 replays/check.py
target/debug/vapor-rune --script replays/record-save-play.json \
  --snap /tmp/vapor-recording.png --at mark:ready-to-save --scale 2 --theme light
target/debug/vapor-rune --script replays/record-save-play.json \
  --video /tmp/vapor-replay.mp4 --fps 30 --scale 2 --theme light
```

Rune uses a fake microphone, virtual time, and a temporary archive in headless mode. The check script gives each replay an isolated archive, confirms that repeated snapshots are byte-identical, validates the saved WAV and speaker metadata, and reopens the archive in a new process. Video output requires FFmpeg.

For optional state-preserving view edits, use Rune's pinned checkout, Python 3.13 or later, and Dioxus CLI 0.7.10. Start from this directory and use the absolute path to the Rune checkout. Function-body edits in `src/ui.rs` can patch in place.

```sh
/path/to/rune/scripts/rune-hot --manifest "$PWD/Cargo.toml" --patch src/ui.rs -- \
  --snap-on-patch /tmp/vapor-live.png --hot-control /tmp/vapor-control.json
```
