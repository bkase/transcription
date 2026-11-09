# Vapor on Rune

A macOS desktop slice of Vapor's audio recording flow. Start from the Timeline, pause or resume the recording, choose a speaker count, optionally name the speakers, and stop and save. A saved recording can be found by title or speaker name and played from its detail screen. Back asks before discarding a take.

The port reads the shared [Vapor tokens](../../tokens.json) and uses San Francisco and SF Symbols from the running Mac. The recording header and speaker card follow the SwiftUI layouts. The native window replaces the iPhone safe areas. Recording uses Rune's AVFoundation backend. Speaker names are local recording metadata. This slice records audio only.

## Run on macOS

From this directory, run `cargo run --locked`. To build a Finder-launchable app with its own microphone usage description, run `./bundle.sh` and open the printed app path. Recordings are stored in `~/Library/Application Support/Vapor Rune`.

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
