# Vapor hot reload on Exact and Rune

## Warm save to first updated frame

Median milliseconds from 10 pixel-verified saves per row. The last column gives the minimum and maximum across those 10 saves.

| Platform | Framework | Edit | Compile / build | Apply | Render | Other | Save → frame | Range |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| macOS | Exact | Color | 52.5 | 17.1 | 2.7 | 2,914.4 | 3,036.6 | 2,856–3,742 |
| macOS | Exact | Structure | 49.5 | 17.5 | 2.7 | 2,848.4 | 2,925.6 | 2,866–3,044 |
| macOS | Rune | Color | 1,286.0 | 305.5 | 13.1 | 114.8 | 1,667.1 | 1,309–1,868 |
| macOS | Rune | Structure | 1,186.5 | 304.6 | 14.4 | 121.5 | 1,607.8 | 1,325–1,884 |
| iOS Simulator | Exact | Color | 52.0 | 20.3 | 1.4 | 2,896.1 | 2,969.6 | 2,899–3,120 |
| iOS Simulator | Exact | Structure | 52.0 | 20.6 | 1.5 | 2,872.1 | 2,946.7 | 2,832–3,416 |
| iOS Simulator | Rune | Color | 1,556.7 | 5.6 | 22.1 | 140.5 | 1,719.1 | 1,591–2,389 |
| iOS Simulator | Rune | Structure | 1,540.9 | 6.4 | 24.8 | 132.6 | 1,713.4 | 1,588–2,587 |

The medians are computed separately for each column. `Other` is the per-save time outside compile, apply, and render. It includes source watching, delivery, and any preparation before the apply probe starts. [Individual trials](hot-reload-samples.csv)

Exact’s compile stage was 24–30× faster on these edits. Its median publish-to-apply interval was 2.82–2.86 seconds across the two platforms. A separate probe received the generation event about 3.48 seconds after publication at both the resident server and the forwarding server. The resident server synchronously runs `cargo run -q -p contract -- sources …` to refresh its dependency watchers immediately after queuing the event. The same command took 3.19 seconds on its own with the same target directory, which points to that synchronous refresh as the source of the wait.

## Workload and controls

- Both apps were on the empty Vapor Timeline. The color edit changed a 96 × 32 point badge between magenta and green. The structure edit inserted or removed the same badge in the same place, below the Timeline header. Exact edited an inline Contract property or element. Rune edited the equivalent Rust view body. Both Exact edits used its plan generation path.
- Each series used the same atomic source-save procedure. A cycle inserted magenta, changed to green, changed back to magenta, then removed the badge. One cycle warmed each app and five cycles supplied the measurements. The Timeline entrance animation was disabled in the temporary benchmark sources so the marker appeared on the first updated frame.
- The host was an Apple M4 Max with 128 GB RAM, macOS 26.6.2, and Xcode 27.0. The iOS 26.2 simulator ran headlessly. Each measured series used one running app process and a warm compiler, with the other benchmark compilers idle. The Rune desktop benchmark window floated to prevent macOS from suppressing redraws when covered.
- The SDKs were Rune `394428df` and Exact `956ae33a` with the Vapor [native compatibility patch](tools/exact-native.patch). Rune used Dioxus CLI 0.7.10. Exact used Bun 1.4.2 and the standard loopback dev server. The Rune desktop entry point was corrected to compile the app views into the patchable binary crate under the `hot` feature. Before that fix, the desktop patch acknowledged the update without changing the visible Timeline.

## Timing boundaries

| Phase | Exact | Rune |
| --- | --- | --- |
| Compile / build | Resident producer request to compiled Contract and baked module reply. Generation packaging is measured separately in the samples. | Thin Rust compile and link through patch creation. macOS uses Dioxus’s reported build and jump-table generation time. The simulator uses elapsed time for `dx tools hotpatch`, which includes CLI startup and opening its patch cache. |
| Apply | Verified candidate ready to apply through return from the native generation swap. | Start to return of Subsecond’s dynamic-library load and jump-table install. |
| Render | Apply return to the session’s first native draw callback for the updated generation. | Apply return to the first updated frame queued for GPU presentation. Includes redraw scheduling, view construction, layout, and rendering work on that path. |

The application-side frame markers measure draw or submission before compositor presentation. A separate screenshot after each marker had to contain the expected badge pixels, or confirm their absence on removal. Cold builds, production installs, restarts, and other edit classes such as Exact design-token batches were outside the measurements.
