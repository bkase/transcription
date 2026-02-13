# Vapor iOS — Engineering Architecture (SwiftUI + TCA + SQLiteData + FluidAudio)

*(Constitution-aligned in design and workflow; structured as a standard architecture doc.)*

## 1) Overview

Vapor is a **local-first conversation capture** app. It records real-world audio, produces a time-coded transcript with diarized speaker tracks, lets users map “Speaker 1 / Speaker 2” to real people, supports fast search, and exports clean artifacts (audio + structured transcript).

### Primary user flows (from your mockups)

1. **Timeline (Archive)**

   * Date-grouped sessions (“TODAY”, “YESTERDAY”, etc.)
   * Search transcripts
   * Tap a session → Session Detail
   * Tap FAB → start Recording
2. **Recording**

   * “Listening…” (before any transcript appears)
   * Live transcript segments appear while recording
   * Speaker chips show “Speaker 1/2” until assigned
   * Pause/Stop controls
3. **Session Detail**

   * Script-like transcript (no bubbles)
   * Speaker + timestamp per segment
   * Floating audio mini-player
   * Share / More actions
4. **People Directory**

   * List/search people
   * Conversation counts
   * Add new person
5. **Assign Speaker modal**

   * Select existing person, or create a new one
   * Assignment is per-session (speaker tracks) but can later support cross-session recognition

---

## 2) Goals and non-goals

### Goals

* **Correctness by construction**: typed IDs, explicit state machines, reducer-driven state.
* **Functional core / imperative shell**: pure domain transforms; IO behind dependency clients.
* **Fast iteration**: codegen for project + tokens; snapshots; deterministic tests.
* **Real-world reliability**: resilient recording, partial results, safe finalization, resumable processing.
* **Exportability**: stable schemas and boring, composable outputs (JSON/MD/VTT + audio).
* **Test suite discipline**: `make test` is the “reward”—it must be fast and deterministic.

### Non-goals (v1)

* Cloud sync, server accounts, sharing links.
* Perfect speaker recognition across sessions (we’ll structure for it, but treat as future).
* Long-running real ML inference inside UI tests (UI tests use mocked ML; real-model integration runs in a separate parallel lane within `make test`).

---

## 3) Technology decisions

### Dependency management: **Standard Swift Package Manager**

All third-party dependencies are managed via **Swift Package Manager** (SPM) and resolved by Xcode/SwiftPM:

* Packages are declared in **XcodeGen**’s `project.yml` under `packages:` so generation is reproducible.
* We **commit `Package.resolved`** (the SwiftPM lockfile) so CI and local builds resolve identically; note that when using XcodeGen, packages are defined in `project.yml` and `Package.resolved` is still the source of truth for exact versions. ([jessesquires.com][1])

FluidAudio supports installation via Swift Package Manager (repo URL + version). ([GitHub][2])

### UI + State management

* **SwiftUI**
* **The Composable Architecture (TCA)** for strict unidirectional data flow and deterministic tests.
* **swift-identified-collections** for identity-safe collections in state. ([GitHub][2])
* **swift-tagged** for strongly typed identifiers (eliminate ID mixups). ([GitHub][2])
* **swift-clocks** for deterministic time (recording timers, pacing, throttling). ([GitHub][2])
* **SnapshotTesting** for SwiftUI snapshots (golden verification).
* **XCUITest** for agentic E2E.

### Persistence

* **SQLiteData (Point-Free SQL stack)** as the local database (SQLite-first).
  SQLite is the source of truth for sessions, segments, speaker tracks, people, mappings, exports metadata.

### Audio + ML

* **FluidAudio SDK** for on-device transcription + diarization (production). ([GitHub][2])
* In `make test`, ML is **mocked** (deterministic scripted outputs). Audio input is **generated** (deterministic PCM frames + file).

### Routing

* **swift-url-routing** for typed deep links and testable navigation. ([GitHub][2])

### Property testing / generators

* **swift-gen** for deterministic generators used by unit/property tests (and for generating test audio payloads / long transcripts). ([GitHub][2])

### Project management / “everything is code”

* **XcodeGen** for generating the `.xcodeproj`. The project file is a generated artifact; the YAML spec is committed. ([GitHub][3])

---

## 4) Repository layout and build system

### Repo layout (SPM-first, XcodeGen for the project)

```
Vapor/
  xcodegen/
    project.yml
    configs/*.xcconfig
  App/
    Sources/...
  Packages/
    Core/
      Models/
      Persistence/
      Audio/
      Processing/
      Export/
      Observability/
      Routing/
      DesignSystem/
    Features/
      TimelineFeature/
      RecordingFeature/
      SessionDetailFeature/
      PeopleFeature/
      SpeakerPickerFeature/
      AudioPlayerFeature/
    TestsSupport/
  tools/
    Package.swift          # pinned build tools (optional but recommended)
    Package.resolved
    Sources/
      TokenGen/
      DocGen/
  docs/
    ARCHITECTURE.md
    SCHEMA.md
    EXPORT_FORMAT.md
    DEPENDENCIES.md
  Makefile
  scripts/
    gen.sh
    ci.sh
```

### Make targets (verifiable, single canonical entrypoints)

* `make bootstrap`
  Builds pinned tools (XcodeGen + TokenGen + DocGen) if you choose to vendor them via a tools SwiftPM workspace.
* `make gen`

  * Generates `.xcodeproj` via XcodeGen
  * Generates design tokens → Swift
  * Generates schema docs from migrations
  * Ensures SwiftPM resolution is present/updated (Package.resolved tracked)
* `make test` *(PR gate)*
  Runs **unit + snapshot + agentic E2E + real-model integration** (FluidAudio lane runs in parallel via `run-tests.py`).
* `make test-slow` *(optional local debug alias)*
  Runs only the FluidAudio integration lane directly. Not a separate workflow -- `make test` is the canonical command for all coverage.
* `make ci`
  Exactly what CI runs locally (bootstrap → gen → fmt → test → docs-check).

**Key discipline:** “silence on success.” Tools should print minimal output when passing; structured logs and traces only on failure.

---

## 5) Architecture: modules and boundaries

### 5.1 Package boundaries (functional core / imperative shell)

**Core packages**

* `Core/Models`
  Domain types (typed IDs, value types, invariants).
* `Core/Persistence`
  SQLiteData tables, migrations, query helpers, repositories.
* `Core/Audio`
  Audio capture client(s), audio file writer, format conversion.
* `Core/Processing`
  Recording processor orchestration (actor), ML client boundary.
* `Core/Export`
  Export schema + writers (JSON/MD/VTT, zip/bundle).
* `Core/Observability`
  Structured logging, trace IDs, error envelopes.
* `Core/Routing`
  AppRoute, url parsers/formatters.
* `Core/DesignSystem`
  Typography/colors/components + generated tokens.

**Feature packages**

* `TimelineFeature`
* `RecordingFeature`
* `SessionDetailFeature`
* `PeopleFeature`
* `SpeakerPickerFeature`
* `AudioPlayerFeature`

### 5.2 Dependency injection (testable edges)

Every IO boundary is behind a dependency client:

* `DatabaseClient`
* `AudioCaptureClient`
* `FluidAudioClient`
* `RecordingProcessorClient` (thin façade that starts/stops a processor and streams events)
* `AudioPlayerClient`
* `ExportClient`
* `FileClient`
* `Clock`, `UUID`, `Date`

Reducers never touch AVFoundation/CoreML/SQLite directly.

---

## 6) Domain model and persistence

### 6.1 Typed IDs and invariants (invalid states unrepresentable)

Use `Tagged` IDs:

* `SessionID`, `PersonID`, `SpeakerTrackID`, `TranscriptSegmentID`

Use value types for invariants:

* `Milliseconds(Int)` wrapper
* `TimeRangeMs(start:end:)` validated initializer (`start < end`)
* `MachineSpeakerID` wrapper around a string (non-empty)

### 6.2 Database schema (SQLite as source of truth)

**sessions**

* `id: SessionID`
* `startedAt`, `endedAt?`
* `title?`
* `previewText?` (cached for cards)
* `durationMs?`
* `audioPath?`
* `processingState` enum (`recording | partial | processed | failed`)
* `speakerCount` cached
* `updatedAt`

**people**

* `id: PersonID`
* `name`
* `colorToken` (ties to your design dots)
* timestamps

**speaker_tracks** (per-session diarization tracks)

* `id: SpeakerTrackID`
* `sessionId: SessionID`
* `machineSpeakerId: MachineSpeakerID` (e.g. `spk_0`)
* `displayOrder: Int` (1 => “Speaker 1”)
* `personId: PersonID?`

**transcript_segments**

* `id: TranscriptSegmentID`
* `sessionId`
* `rangeMs (startMs,endMs)`
* `machineSpeakerId?` (can be filled later)
* `text`
* `confidence?`
* `isFinal` (partial vs final)
* timestamps

**speaker_segments** (optional but recommended for future overlap/quality)

* `sessionId`, `rangeMs`, `machineSpeakerId`, `score?`, `isOverlap`

### 6.3 Search

Use SQLite FTS5:

* `transcript_fts(text, sessionId, segmentId)`
* Timeline search flow:

  1. FTS query → ranked session IDs
  2. fetch sessions, group by date, render cards

---

## 7) Audio and processing pipeline

### 7.1 Pipeline goals

* Incremental: produce segments while recording.
* Resilient: app can crash/restart without corrupting DB.
* Deterministic: core logic is pure; pipeline emits events.
* Cancel-safe: stop cancels streaming tasks and transitions into finalize.

### 7.2 Key components

#### AudioCaptureClient

Two implementations:

1. **LiveMicrophoneCapture** (production)

* configure AVAudioSession
* capture PCM frames via AVAudioEngine tap
* write to file as it streams
* produce `AsyncStream<AudioFrame>`

2. **GeneratedAudioCapture** (tests + UI tests)

* generates deterministic PCM frames (e.g., noise or tone), writes `.caf`/`.wav`
* emits frames as fast as possible (or paced via `Clock` if needed)
* no microphone permission needed

**Important:** Because ML is mocked in `make test`, generated audio does not need to be “real speech” to drive transcript. It only needs to exercise the audio file path + time progression.

#### FluidAudioClient

* Production: wraps FluidAudio SDK (added via SPM). ([GitHub][2])
* Test: **MockFluidAudioClient** emits a scripted sequence:

  * diarization track creation (`spk_0`, `spk_1`)
  * transcript segments with time ranges and speaker IDs
  * optional “listening” transitions / partial segments

#### RecordingProcessor (actor)

Single orchestrator for a recording session:

* creates a session row
* starts audio capture and writes audio
* starts ML stream (real or mock)
* appends transcript segments and speaker tracks to DB incrementally
* on stop: finalizes session metadata (duration, preview, speakerCount, processingState)

**Events emitted to the feature layer**:

* `.didStart(sessionID)`
* `.listeningChanged(Bool)`
* `.didAppendSegment(segmentID)`
* `.didUpdateProcessingState(state)`
* `.didFinish(sessionID)`
* `.didFail(errorEnvelope)`

Reducer listens to events and updates UI state (timer, banners, finalizing state), while **the transcript content is always read from DB**.

### 7.3 Speaker assignment semantics

* Machine speakers are per-session (`spk_0`, `spk_1`).
* UI shows:

  * unset: “Speaker 1” derived from `displayOrder`
  * set: person name + color
* Assigning a speaker updates `speaker_tracks.personId`. We do **not** rewrite segments.

---

## 8) Routing and navigation

### 8.1 Typed routing (swift-url-routing)

Define:

* `AppRoute.timeline`
* `AppRoute.session(SessionID)`
* `AppRoute.people`
* `AppRoute.record`

Use swift-url-routing to parse URLs into routes, then route into TCA navigation actions. This enables deep linking and deterministic routing tests.

### 8.2 Navigation architecture

Use a root `AppFeature` with a navigation stack:

* Timeline → SessionDetail → (SpeakerPicker modal)
* Timeline → Recording
* Timeline → People

---

## 9) UI architecture and design system

### 9.1 Design tokens (from your mockups)

Your JSON includes colors/typography tokens (cloud/mist/haze/sky/lavender/etc., fonts, radii, spacing). We’ll treat that as a **source asset** and generate Swift:

* `DesignTokens.swift` (colors, spacing, radius)
* `VaporTextStyle.swift` (Display/Title/Headline/Body/Caption/Timestamp)
* `VaporComponents.swift` (RecordButton, SessionCard, SpeakerChip, SearchField, PlayerCard)

Generation happens in `make gen` via `tools/TokenGen`.

### 9.2 SwiftUI view composition

Views stay thin:

* `TimelineView` renders sessions from DB query results and sends user intents to the store.
* `SessionDetailView` renders segments from DB queries and delegates assignment actions to store.
* `RecordingView` renders live segments from DB queries and timer/listening state from store.

Snapshot testing targets **these views** across key states.

---

## 10) Testing strategy (including agentic E2E in `make test`)

### 10.1 Test lanes (what runs where)

**`make test` (PR gate, deterministic)**

1. **Unit tests** (reducers + pure transforms)
2. **Property tests** (swift-gen generators; transcript invariants; export roundtrips)
3. **Snapshot tests** (SwiftUI goldens)
4. **Agentic E2E tests (XCUITest)**

   * ML mocked
   * Audio generated (no microphone)

**`make test-slow` (optional local debug alias)**

* Runs only the FluidAudio integration lane (same tests that `make test` runs via `run-tests.py`)
* Useful for isolating integration failures without running the full suite
* Not a separate workflow -- `make test` is the single canonical command

### 10.2 Unit tests (TCA TestStore)

* Reducer correctness: state machine transitions, navigation, assignment flows
* Deterministic time via `TestClock`
* Deterministic IDs via injected UUID generator
* In-memory SQLite database

### 10.3 Property tests (swift-gen)

Examples:

* Segment compaction preserves ordering and non-overlap
* Speaker assignment join is deterministic
* Export schemas decode/encode stable

### 10.4 Snapshot tests

Cover:

* Timeline: empty/populated/search
* Recording: listening/live segments/paused/finalizing
* Session detail: speaker set/unset, long transcript, mini-player
* People directory: empty/search/add

### 10.5 Agentic E2E (XCUITest) **inside `make test`**

We’ll keep E2E tests **small and surgical** so they run fast:

* “Record → see live segments → stop → session appears in timeline”
* “Assign speaker → chip updates → persists after back/forward”
* “Search transcript → filters sessions”

#### How E2E becomes deterministic

On launch with `-uiTesting`:

* App config switches dependencies to:

  * `GeneratedAudioCapture` (writes a short audio file quickly)
  * `MockFluidAudioClient` (script emits segments immediately)
  * ephemeral DB location (per test)

E2E tests do **not** depend on microphone permission or real ML.

---

## 11) Observability, error handling, and recoverability

### 11.1 Structured logging

All runtime logs are structured events:

* `trace_id`
* `session_id`
* `event`
* `latency_ms`
* small state snapshot when failing (not on success)

### 11.2 Error envelopes

All failures propagate as typed error envelopes:

* user-facing message
* internal code
* trace ID
* optional recovery action (`retryFinalize`, `keepPartial`, `deleteSession`)

### 11.3 Crash-only posture

* DB is authoritative.
* Writes are transactional.
* Finalization is idempotent.
* On restart, any session left in `.recording` is reconciled into `.failed(interrupted)` or `.partial` with preserved artifacts.

---

## 12) Export architecture

Exports should be boring, stable, and testable with goldens.

**Export bundle**

* `audio.caf` / `audio.m4a`
* `transcript.json` (segments, speaker tracks, mappings, metadata)
* `transcript.md` (human readable)
* `transcript.vtt` (time-coded captions)
* `metadata.json` (model versions, app version, trace IDs, timings)

Export outputs are golden-tested in unit tests (JSON structure snapshots).

---

## 13) Implementation plan (milestones)

### M0 — Repo + tooling foundation

* XcodeGen spec + `make gen`
* SPM package declarations in XcodeGen + committed `Package.resolved` ([jessesquires.com][1])
* Design token generation scaffold
* Core packages skeleton + dependency clients

### M1 — Persistence + timeline

* SQLite schema + migrations
* Timeline + Session detail read paths
* Snapshot baseline for key screens

### M2 — Recording shell (no real ML)

* Audio capture to file (live + generated)
* RecordingProcessor actor + DB writes
* Mock ML scripted segments
* E2E smoke test included in `make test`

### M3 — Speaker assignment + People directory

* speaker_tracks mapping + modal
* people CRUD + counts
* E2E: assign speaker persists

### M4 — Real FluidAudio integration (production only)

* FluidAudioClient live implementation (via SPM) ([GitHub][2])
* Chunking/streaming policy tuned
* Real-model integration lane in `make test` (via `run-tests.py`)

### M5 — Search + Export

* FTS search
* export bundle + goldens
* share sheet

---

## 14) Key design choices recap

* **Swift Package Manager is the standard dependency mechanism**; packages are declared via XcodeGen spec and pinned via `Package.resolved` for reproducibility. ([jessesquires.com][1])
* **SQLite is the source of truth**; TCA state is UI intent and ephemeral control state.
* **ML is mocked in UI/unit tests**; audio is **generated** to exercise the recording shell deterministically. Real-model integration runs in a dedicated lane within `make test`.
* **Agentic E2E runs in `make test`**, but kept small and fast.
* **Typed IDs + explicit state machines** eliminate whole categories of bugs.
* **Time is injected**; no hidden sleeps; determinism everywhere.
* **Project is generated**; `.xcodeproj` is not a hand-edited artifact.

If you’d like, I can also provide the minimal **XcodeGen `packages:` stanza** (with the FluidAudio SPM URL + Point-Free packages) and a concrete policy for where `Package.resolved` lives and how `make gen` ensures it’s preserved.

[1]: https://www.jessesquires.com/blog/2024/05/29/swiftpm-package-resolved-xcode/?utm_source=chatgpt.com "Workaround: Xcode deletes Package.resolved file and ..."
[2]: https://github.com/FluidInference/FluidAudio?utm_source=chatgpt.com "FluidInference/FluidAudio: Frontier CoreML audio models ..."
[3]: https://github.com/yonaskolb/XcodeGen?utm_source=chatgpt.com "yonaskolb/XcodeGen: A Swift command line tool ..."
