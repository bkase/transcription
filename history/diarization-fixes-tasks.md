# Diarization Fixes Tasks (End-Only Diarization, Constitution + PFW Aligned)

## Direction
- Keep live transcription enabled during recording.
- Remove live diarization entirely.
- Run diarization once after stop/finalization on the full recording.
- Defer UI changes to a follow-up pass.

## Engineering Constraints
- Functional core, imperative shell: keep mapping logic pure in `DiarizationMapping.swift`; keep SDK/DB IO in orchestration code.
- Unidirectional flow: audio capture -> live ASR segments (`speakerId=nil`) -> finalization enrichment -> persisted speaker tracks.
- Verifiable reward per task: each task ends with compile + targeted tests (no full-suite run).
- Single source of truth: this task doc plus code/tests in-repo are the spec.
- Use Point-Free conventions already in this module (`Dependencies`, `withDependencies`, Swift Testing); add more Point-Free libs only when they materially simplify correctness/testing.

## Platform Notes (FluidAudio)
- Official package targets are `macOS 14+` and `iOS 17+`.
- Diarization docs describe iOS/macOS support for real-time and offline managers.
- Simulator behavior is not guaranteed as a correctness target for real-model tests, so simulator lanes should use dependency-injected tests as required verification.

## Locked Behavioral Invariants (Verified)
- `I1` Live segments never carry speaker labels.
- `I2` Finalization/retry may enrich speakers later.
- `I3` Diarization failure must not delete or hide transcript text.

## Invariant Coverage Map
- Task 1 -> `I1`
- Task 2 -> `I1`, `I2`
- Task 3 -> `I2`, `I3`
- Task 4 -> `I2`
- Task 5 -> `I2`, `I3`
- Task 6 -> `I2`, `I3`
- Task 7 -> `I1`, `I2`, `I3` (verification)
- Task 8 -> `I1`, `I2`, `I3` (real-model verification)
- Task 9 -> `I1`, `I2`, `I3` (platform-safe verification)
- Task 10 -> `I1`, `I2`, `I3` (workflow clarity)

## Task 1: Remove Live Diarization From Streaming Path
**Files:** `Packages/Core/Processing/Sources/Processing/LiveFluidAudioClient.swift`

- Remove diarization calls from `processChunk()` and `processRemainingAudio()`.
- Keep live ASR output behavior.
- Emit live `TranscriptSegment`s with `speakerId = nil`.
- Ensure ASR emission is not coupled to any diarization-related failure.

**Acceptance criteria**
- No `performCompleteDiarization` calls in live chunk handlers.
- Live transcript text still streams while recording.
- Persisted live segments have `machineSpeakerId == nil`.

## Task 2: Split Model Lifecycle by Concern (ASR Live, Diarization Offline)
**Files:** `Packages/Core/Processing/Sources/Processing/LiveFluidAudioClient.swift`

- Make live start readiness ASR-only.
- Remove diarizer availability as a prerequisite for starting live transcription.
- Initialize diarization manager lazily for post-stop processing only.

**Acceptance criteria**
- Live transcription starts when ASR is ready even if diarization is not.
- Offline/finalization diarization can still initialize and run on demand.

## Task 3: Add End-Only Full-File Diarization API
**Files:** `Packages/Core/Processing/Sources/Processing/LiveFluidAudioClient.swift`

- Add a dedicated API for diarizing a completed recording file.
- Use full-session diarization in one pass (not 5-second chunks).
- Keep API boundaries clean: diarization API returns diarization data, not DB writes.
- Keep cancellation/error handling explicit so timeouts actually stop work.

**Acceptance criteria**
- Diarization runs exactly once per finalized file.
- Speaker identities are stable across the whole session.
- Failure is surfaced cleanly without breaking live ASR behavior.

## Task 4: Build a Pure Mapping Core for Speaker Assignment
**Files:** `Packages/Core/Processing/Sources/Processing/DiarizationMapping.swift`

- Add pure helper(s) to map diarization intervals onto transcript segment intervals via overlap.
- Define deterministic tie-break and no-overlap policy.
- Keep display-order assignment deterministic by first appearance.

**Acceptance criteria**
- Mapping is deterministic and SDK-independent.
- Mapping has no side effects and is unit-test friendly.

## Task 5: Orchestrate Post-Stop Enrichment in Finalization + Retry
**Files:** `Packages/Core/Processing/Sources/Processing/Processing.swift`

- Update `runOfflineTranscription` and `retryOfflineTranscription` to perform speaker enrichment only after recording stops.
- Apply mapped speaker IDs to persisted transcript segments.
- Recreate speaker tracks from final mapped transcript state.
- Preserve text-first fallback: if diarization fails, keep transcript data intact.

**Acceptance criteria**
- Normal stop flow ends in `.processed` with speaker labels when successful.
- Failure path preserves transcript text and lands in correct state (`.partial`/`.failed`).
- Retry flow follows the same enrichment contract.

## Task 6: Retention + Continuation Policy Clarification
**Files:** `Packages/Core/Processing/Sources/Processing/Processing.swift`

- Decide transcript-only behavior and codify it as policy.
- Choose one: diarize before deleting audio, or explicitly skip diarization.
- Decide continuation behavior (currently skips offline processing) and codify expected speaker outcome.
- Ensure state transitions and error messages are consistent with policy.

**Acceptance criteria**
- Transcript-only behavior is documented and implemented.
- Continuation behavior is documented and implemented.
- No contradictory processing-state transitions.

## Task 7: Tests (Swift Testing + Dependencies Style)
**Files:** `Packages/Core/Processing/Tests/ProcessingTests/*` (new and existing)

- Add `DiarizationMapping` unit tests for overlap, tie, and no-overlap cases.
- Add processing flow tests with dependency-controlled clients for successful end-only diarization.
- Add processing flow tests with dependency-controlled clients for diarization failure fallback.
- Add processing flow tests with dependency-controlled clients for transcript-only policy path.
- Add processing flow tests with dependency-controlled clients for continuation policy path.
- Add/adjust assertions that live segments have `speakerId == nil` before enrichment.

**Acceptance criteria**
- Targeted test suites pass with deterministic results.
- New tests enforce the contract: live text now, speakers later.

## Task 8: Real-Model Iteration Test Lane in Default `make test`
**Files:** `Tests/CoreProcessingTests/FluidAudioIntegrationTests.swift`, `Tests/CoreProcessingTests/Fixtures/*`, `scripts/run-tests.py`, `Makefile`

- Add one real-model integration test using a small committed fixture audio file (for example `test-speech.wav`).
- Run this test in the default `make test` path, but on its own lane/phase so it does not block unrelated suites.
- Prefer a dedicated `FluidAudioIntegration` invocation/section in the test runner instead of piggybacking on generic package test output.
- Keep assertions focused on contract-level checks (successful processing, non-empty/valid segment timing), not exact transcript text.
- Keep fast deterministic behavior in package tests (`Packages/Core/Processing`) using dependency-controlled clients.

**Acceptance criteria**
- `make test` includes a dedicated real-model lane for `FluidAudioIntegration`.
- The lane runs in parallel with other suites so critical-path duration does not materially increase.
- Fixture is small, deterministic, and stored in-repo.

## Task 9: Platform/Runtime Gating for Real-Model Tests
**Files:** `Tests/CoreProcessingTests/FluidAudioIntegrationTests.swift`

- Gate real-model tests to supported host environments.
- Treat Apple Silicon macOS host execution as authoritative for real-model CI/local verification.
- Skip or soft-disable real-model assertions on simulator environments.
- For simulator/unsupported environments, rely on dependency-injected tests from Task 7 as the required signal.

**Acceptance criteria**
- Real-model tests do not create flaky failures on simulator lanes.
- Unsupported environments skip with clear reason.
- Required coverage is still provided by deterministic SwiftPM tests.

## Task 10: Remove or Downgrade `test-slow` Target
**Files:** `Makefile`, `docs/testing` (if present)

- After Task 8 is stable in default `make test`, remove `test-slow` as a required workflow path.
- Either delete `test-slow` or keep it as an alias to the default integration lane for local debugging only.
- Update help text and contributor docs to reflect one canonical path.

**Acceptance criteria**
- No ambiguity about where real-model integration runs.
- Default CI/local command path is consistent (`make test`).

## Deferred Follow-Up (UI)
- Represent live segments without speaker labels while recording.
- Show post-stop enrichment progress and refresh labels when ready.
- Handle diarization failure/no-speaker states without degrading transcript readability.
