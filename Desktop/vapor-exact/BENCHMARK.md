# Vapor on Exact and Rune

For development-build latency after a source save, see the [matched hot reload benchmark](HOT-RELOAD-BENCHMARK.md).

Both ports exercise the same audio-only recording slice. The measurements are from an Apple M4 Max MacBook Pro with 128 GB of RAM, macOS 26.6.2, Xcode 27.0, and the iOS 26.2 simulator. Both apps use optimized release builds. The comparison uses the Rune fork at `394428df` and Exact at `956ae33a` with [the native patch](tools/exact-native.patch).

## Results

| Platform and metric | Exact | Rune |
| --- | ---: | ---: |
| macOS process launch to visible window, median of 7 | 239 ms | 237 ms |
| macOS idle RSS, median of 7 | 118.7 MiB | 115.8 MiB |
| iOS Simulator XCTest launch to Start Recording, median of 5 | 1.95 s | 2.32 s |
| iOS Simulator idle RSS, median of 5 | 250.2 MiB | 254.0 MiB |
| iOS Simulator recording RSS, one four-second sample | 287.8 MiB | 280.7 MiB |
| iOS Simulator recording CPU, same four seconds | 7.3% | 15.2% |
| iOS Simulator tap to recording controls | 353 ms | 382 ms |
| iOS Simulator tap to expanded speaker controls | 335 ms | 322 ms |
| iOS Simulator tap to saved Timeline | 459 ms | 321 ms |

macOS launch ranges overlapped (Exact 221–342 ms, Rune 205–305 ms). Idle CPU rounded to 0.0% of one core for both ports in the desktop sampling window. The simulator's five launch times ranged from 1.77 to 2.07 seconds for Exact and 1.81 to 2.43 seconds for Rune. In an earlier pass the launch medians were 1.89 seconds for both. The simulator launch difference is sensitive to run conditions and XCTest's startup overhead.

Exact used 3 MiB more idle RSS on macOS, 4 MiB less idle RSS in the simulator, and 7 MiB more RSS during the measured capture. Exact's capture CPU was lower in both observed simulator passes. The active and interaction rows are single-run observations. They measure the entire app, including audio handling and animation, with XCTest input overhead in the interaction times.

## Measurement

- On macOS, the harness times process launch to the first on-screen app window using Core Graphics. It samples app-only resident memory and CPU time with `proc_pid_rusage`. Seven measured launches per port follow one warm-up. The harness alternates which port goes first.
- On iOS Simulator, one XCUITest runner alternates five process launches per port and observes the same Start Recording control. Startup includes XCTest's launch and accessibility overhead. The same runner exercises actual capture, pause, resume, speaker count and naming, save, search, and playback in each app.
- The simulator sampler reads the app process RSS and cumulative CPU from `ps` every 200 ms. It takes a median RSS in each two-second idle window and the four-second active capture window. CPU is the share of one core over the sampled interval.
- RSS excludes the system processes, XCTest, and the development server. The values describe this app and these builds. Simulator results do not establish performance on a physical iPhone.

## Reproduce

Build release bundles for Exact with `bun exact.mjs mac --bundle --release` and `bun exact.mjs ios --release --no-install`. Keep the bundle paths for each benchmark.

For Rune on macOS, run the following from the Rune app directory.

```sh
cargo build --locked --release
rune_debug="$(./bundle.sh)"
rune_release="$(dirname "$rune_debug")/Vapor Rune Release.app"
ditto "$rune_debug" "$rune_release"
install -m 755 target/release/vapor-rune "$rune_release/Contents/MacOS/vapor-rune"
codesign --force --sign - "$rune_release"
```

For Rune on the simulator, generate the Xcode project and build its release configuration.

```sh
xcodegen generate --spec ios/project.yml
xcodebuild build -project ios/VaporRune.xcodeproj -scheme VaporRune \
  -configuration Release -derivedDataPath target/ios-bench \
  -destination "id=$SIMULATOR_ID" CODE_SIGNING_ALLOWED=NO
```

Run both measurements from the Exact app directory. Use a dedicated simulator with comparable archive contents in each app. The measured simulator had small local archives. The simulator flow records and saves a test take.

```sh
mkdir -p .exact/benchmark
xcrun swiftc -O tools/bench/mac-launch.swift -o .exact/benchmark/mac-launch
.exact/benchmark/mac-launch "$EXACT_MAC_APP" "$RUNE_MAC_APP"
python3 tools/bench/run.py --sim "$SIMULATOR_ID" --exact "$EXACT_IOS_APP" \
  --rune "$RUNE_IOS_APP" --output .exact/benchmark/ios-results
```

The simulator runner writes the XCTest log and result bundle, RSS samples, and summarized metrics in its output directory.

## Architecture

Exact compiles Contract into a plan, runs it in Rust, and uses AppKit or UIKit to present native views and controls. A TypeScript module handles this port's archive using Exact's storage grants. The development server supplies a replacement plan and module. The Apple host swaps runners while keeping the application and compatible state, then reconnects the existing native recorder to the new runner. [Exact architecture](https://github.com/expo/exact#how-it-works)

Rune compiles the views and handlers as Rust and paints with its own GPU renderer. The iOS host bridges its controls into UIKit for input and accessibility. The development toolchain patches compatible Rust functions in place, which lets the existing runtime and recorder continue. Incompatible Rust changes rebuild and relaunch. [Rune renderer](https://github.com/bkase/rune/blob/394428df307394f61bd3e9eed2e8a8c9b0a28cf9/crates/rune/README.md)
