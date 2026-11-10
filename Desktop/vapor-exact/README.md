# Vapor on Exact

This macOS and iOS port covers the audio-only slice of Vapor Rune. Record from the Timeline, pause and resume, choose and name speakers, discard or save a take, then search and play saved recordings. Exact uses AppKit and UIKit for presentation and its standard microphone and recording packages for audio. Contract implements the controls, transitions, reduced-motion behavior, and recording state. A TypeScript data module stores the archive.

The palette, spacing, radii, and motion constants come from [Vapor's shared tokens](../../tokens.json). Run `python3 tools/sync-theme.py` after changing them. Exact uses SF Symbols and the native system font. Rasterization and animation curves differ between the two ports.

## Build

Use Bun 1.4.2 and Xcode. From the transcription repository root, clone the pinned Exact revision next to the transcription checkout.

```sh
git clone https://github.com/expo/exact.git ../exact-vapor
git -C ../exact-vapor checkout 956ae33a35ffa5313d7be3cebc55ed84f9480e0a
cd Desktop/vapor-exact
git -C ../../../exact-vapor apply "$PWD/tools/exact-native.patch"
export EXACT_FEEDBACK=0
bun ../../../exact-vapor/scripts/exact.mjs setup
rustup target add --toolchain 1.97.0 aarch64-apple-ios-sim
bun install --frozen-lockfile
bun exact.mjs mac --bundle
bun exact.mjs ios --no-install
```

The build prints each `.app` path. The Exact patch gates UIKit's arrangement controller on an SDK that includes it. The Xcode 27.0 SDK can build the single-pane Vapor port.

## Live edits

Start Exact's loopback development server in one terminal.

```sh
bun exact.mjs web --port 18765
```

In another terminal, build the macOS development bundle. Set `MAC_APP` to the bundle path the build prints.

```sh
bun exact.mjs mac --bundle --url http://127.0.0.1:18765
EXACT_DEV_PLAN=http://127.0.0.1:18765/ "$MAC_APP/Contents/MacOS/Vapor"
```

For the iOS Simulator, set `SIMULATOR_ID` to the simulator UDID and `IOS_APP` to the development bundle the build prints. The launcher uses `simctl`.

```sh
bun exact.mjs ios --no-install --url http://127.0.0.1:18765
python3 tools/hot-ios.py "$SIMULATOR_ID" "$IOS_APP"
```

Exact watches `app.contract` and `app.ts`. The first connection warms the native plan compiler. Native capability, signing, and shell changes require a native rebuild.

From a disposable checkout with the development server running, exercise live edits during a paused take. The checks try an incomplete edit, replace the view, Save action and TypeScript source, then restore the original files.

```sh
bun tools/replay.mjs macos http://127.0.0.1:18765/
python3 tools/check-hot-ios.py "$SIMULATOR_ID" "$IOS_APP" .exact/hot-results
```

The simulator check grants microphone access for the test app and saves a test recording.

## Replay and benchmark

`bun tools/replay.mjs macos` and `bun tools/replay.mjs ios` run the recording flow with Exact's synthetic microphone, isolated storage, and virtual clock. Build the respective development app first. For the real microphone flow and the Exact-versus-Rune release comparison, see [the benchmark](BENCHMARK.md).
