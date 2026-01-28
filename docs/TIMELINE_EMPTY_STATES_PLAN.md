# Timeline Blank States Plan (Downloading / Error / Ready)

## Design references (Pencil MCP)
Source: `app.pen` frames `Home - Downloading` (3cHnT), `Home - Error` (atOm1), `Home - Ready` (ZVW0U).

Downloading state
- Icon: cloud-download (48), color overcast
- Title: "Setting up Vapor"
- Body: "Downloading speech models for\noffline transcription..." (width ~240, centered)
- FAB: disabled, haze background + overcast dot (0.4), status text "Downloading models..."

Error state
- Icon: cloud-off (48), color recording
- Title: "Unable to connect"
- Body: "Check your connection and try again.\nVapor needs to download models\nto enable recording." (width ~260, centered)
- FAB: disabled, haze background + overcast dot (0.4), status text "Something went wrong"

Ready state
- Icon: mic (48), color sky
- Title: "Ready to record"
- Body: "Tap the button below to start\nyour first transcription." (width ~220, centered)
- FAB: standard enabled appearance

## Plan (linked to beads)
1. Model preparation API in Processing (bd-af4)
   - Add a shared ModelPreparationState enum and expose prepareModels()/modelStatus on FluidAudioClient.
   - Live client downloads + caches ASR/diarizer models; Mock client can simulate ready/downloading/error.

2. RecordButton disabled styling (bd-1yh)
   - Add an isEnabled/style parameter to RecordButton and implement the disabled visuals from Pencil.

3. TimelineFeature model state wiring (bd-jip)
   - Track modelPreparationState + error message in state; compute isRecordEnabled.
   - On appear, kick off preparation and update state as downloading/ready/error.
   - Ignore newRecordingTapped when record is disabled.

4. TimelineView empty-state UI (bd-3n4)
   - Replace current empty timeline content with the three Pencil states.
   - Show status text under FAB for downloading/error, and use disabled RecordButton there.
   - Keep grouped sessions/search results unchanged when sessions exist or search is active.

5. Tests and snapshots (bd-w94)
   - Extend TimelineViewPreview display modes for downloading/error/ready.
   - Add snapshot tests for all three empty states and record-button disabled style.
   - Add TimelineFeature reducer tests for model preparation success/failure + record gating.
   - Ensure UI testing environment uses a ready mock so E2E record flows remain stable.

## Assumptions / Questions
- Confirm whether the record button should remain disabled in the Ready empty state; Pencil shows enabled but the request mentioned disabling "in those states." If you want Ready disabled too, we will update the plan and visuals accordingly.
