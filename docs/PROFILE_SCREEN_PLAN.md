# Profile Screen (Local-First) - Implementation Plan

## Goals

- Tapping the top-right user avatar opens the new **Profile Settings** screen (per `app.pen`).
- The profile screen supports editing:
  - Full name
  - Email (local-only for now)
  - Profile photo (tap to change)
- All profile data is stored **locally** (persisted across launches in live mode).
- Implementation uses **The Composable Architecture (TCA)** with explicit dependency clients for:
  - Loading/saving profile data
  - Photo selection + image processing (downscale/compress)
- Add **comprehensive tests**:
  - Reducer/unit tests (TCA `TestStore`)
  - Snapshot tests (SwiftUI + SnapshotTesting)
  - Headless XCUITest E2E flow (tap avatar -> edit -> verify)

## Non-goals (for this iteration)

- Real authentication / server-backed accounts.
- Cloud sync of profile data.
- Storing a real password (we should not persist passwords locally in plaintext).
- Sophisticated photo editing (crop/rotate). We can add later.

## UX Requirements (from `app.pen`)

The `Profile Settings` frame in `app.pen` includes:

- A custom nav header with a **Back** button (top-left) and small avatar (top-right).
- A profile section:
  - Large circular avatar with camera badge
  - "Tap to change photo"
- "Personal Information" section:
  - A card row for "Full Name" with pencil icon
- "Account" section:
  - Rows for "Change Email" and "Change Password" with icons and chevrons

Implementation detail: we can keep the overall styling/layout faithful, but we should make the rows reflect stored values (e.g. show email value) while preserving the design language.

## Architecture / Module Placement

### New Feature Module

Create a new feature package:

- `Packages/Features/ProfileFeature/`
  - `ProfileFeature.swift` (reducer)
  - `ProfileView.swift` (SwiftUI view)
  - `ProfileViewPreview.swift` (snapshot-only preview harness similar to other feature previews)

Add it to:

- `xcodegen/project.yml` as a new framework target `ProfileFeature`
- `Vapor` app target dependencies
- Any test targets that need to import it (SnapshotTests, VaporTests if reducer tests live there)

### Data Model

Add a small domain model (preferably in `Models` so the app + feature can share it cleanly):

- `Packages/Core/Models/Sources/Models/UserProfile.swift`

Proposed shape:

- `UserProfile`
  - `fullName: String`
  - `email: String?`
  - `avatar: Avatar`
- `UserProfile.Avatar`
  - `imageData: Data?` (MVP)
  - (optional future: `fileURL` or `relativePath` for file-based storage)

Keep this `Codable` so it can be stored in a single blob if we want.

### Persistence + Side Effects (Dependency Clients)

Create explicit clients for testability:

1) `UserProfileClient` (load/save profile)
2) `ProfileImageClient` (normalize image data: downscale + encode JPEG/PNG)

Suggested placement:

- `Packages/Core/Persistence/Sources/Persistence/UserProfileClient.swift`
  - This keeps "local persistence" concerns in the persistence layer and avoids coupling the app module to a feature for storage.
  - `Persistence` already uses `swift-dependencies` macros, so this matches existing patterns (`DatabaseClient`, `PreferencesClient`, etc.).

Proposed `UserProfileClient` API:

- `load: @Sendable () async throws -> UserProfile`
- `save: @Sendable (UserProfile) async throws -> Void`

Live implementation:

- Store a JSON-encoded `UserProfile` in `UserDefaults.standard` under a namespaced key.
- For avatar image data:
  - MVP: store `Data` in the same JSON (or separate `Data` key) after compressing.
  - Guardrails:
    - Downscale to a max dimension (e.g. 256px) before encoding
    - JPEG quality ~0.8
    - Consider a size cap (e.g. 512KB) to avoid huge UserDefaults writes

Test implementation:

- In-memory `Actor`/closure store that holds the current `UserProfile` and records saves (for assertions).

Why split `ProfileImageClient`?

- Lets reducers stay simple and testable (given raw picked image data, we normalize it deterministically).
- In tests we can bypass real UIKit image codecs and just return input.

## App Integration (Navigation + Shared Display)

### 1) Route to Profile Screen

In `App/Sources/AppFeature.swift`:

- Add a new case to `AppFeature.Path`:
  - `case profile(ProfileFeature)`

In `App/Sources/VaporApp.swift` (AppView destination switch):

- Add `ProfileView` as another `NavigationStack` destination.
- Ensure `.navigationBarHidden(true)` remains consistent so our custom header shows.

Back behavior:

- `ProfileFeature.Action.backTapped` should be handled like `SessionDetailFeature.backTapped`:
  - `AppFeature` handles `.path(.element(... .profile(.backTapped)))` by popping the stack.

### 2) Trigger Navigation from the Avatar

In `TimelineFeature`:

- Add an action: `avatarTapped` (or `headerAvatarTapped`)
- Wrap the header avatar in a `Button` that sends the action.
- Give it an accessibility identifier (e.g. `"profileAvatarButton"`) so E2E tests can tap it.

In `AppFeature`:

- Handle `.timeline(.avatarTapped)` by pushing `.profile(ProfileFeature.State(...))` onto `path`.

In `PeopleFeature`:

- The current header is "Add" only; the design previews show an avatar.
- Update `PeopleView` header to include:
  - Avatar button (opens profile)
  - Add button

### 3) Keeping the Avatar in Sync Across Screens

We want:

- Timeline/People headers show the current avatar/initials
- Changing photo/name in Profile updates those headers immediately

Recommended approach (explicit + minimal coupling):

- Store `UserProfile` in `AppFeature.State` as the single source of truth.
- On app `.onAppear`, load profile and put it into `AppFeature.State`.
- When profile changes in `ProfileFeature`, send a delegate action back to `AppFeature` to update the app-level `UserProfile`.

Implementation shape:

- `ProfileFeature.Action` includes `delegate(Delegate)` (TCA pattern)
  - `case delegate(Delegate)`
  - `enum Delegate { case didSaveProfile(UserProfile) }`
- `AppFeature` listens to `.path(.element(... .profile(.delegate(.didSaveProfile(profile)))))`
  - Update `state.userProfile = profile`

Feeding avatar into feature views:

Two viable options:

1) Pass a lightweight `AvatarViewModel` into `TimelineView` / `PeopleView` as a parameter from `AppView`.
   - Pros: explicit, no global environment magic
   - Cons: touches view signatures in feature packages

2) Inject `UserProfile` via a SwiftUI `EnvironmentKey` from `AppView`.
   - Pros: no signature changes, easy to consume in headers
   - Cons: less explicit wiring

I recommend (1) unless we strongly want to avoid changing view APIs.

## ProfileFeature Design (TCA)

### State

Suggested `ProfileFeature.State`:

- `profile: UserProfile` (current working copy)
- `isLoading: Bool`
- `alert: AlertState<Action>?` (or existing AlertInfo pattern if preferred)

Editing flows:

- `@Presents var editName: EditTextFeature.State?`
- `@Presents var editEmail: EditTextFeature.State?`

Photo picker:

- `@Presents var photoPicker: PhotoPickerFeature.State?` (if we model it)
  - OR keep it view-driven and send `.photoPicked(Data)` into the reducer when the user picks.

### Actions

- `onAppear`
- `backTapped`
- `changePhotoTapped`
- `photoPicked(Data)`
- `editNameTapped`
- `editEmailTapped`
- `saveProfileResponse(Result<UserProfile, Error>)` (if save is async)
- `delegate(Delegate)`

### Dependencies

- `@Dependency(\.userProfileClient) var userProfileClient`
- `@Dependency(\.profileImageClient) var profileImageClient`

### Reducer responsibilities

- Load profile on appear (if needed)
- Update `profile` in response to edit actions
- On save:
  - Normalize avatar image data
  - Persist via `userProfileClient.save`
  - Emit delegate so `AppFeature` updates global profile state
- Handle errors with an alert/inline error state

## Photo Picking Strategy

### Live

Use `PhotosUI`:

- The UI layer presents a `PhotosPicker`.
- When a `PhotosPickerItem` is selected, load its data and send `.photoPicked(data)` to the reducer.
- The reducer normalizes/compresses and saves.

### Deterministic Testing

Unit tests:

- Skip PhotosUI entirely:
  - Send `.photoPicked(Data(...))` directly.
  - Override `profileImageClient` to return deterministic output.
  - Assert `userProfileClient.save` is called with expected data.

E2E tests (headless):

We have two options; choose the least flaky:

1) **Mock picker flow for UI tests**
   - When `AppEnvironment.current == .uiTesting`, profile photo change uses a simple in-app sheet with a few bundled sample images.
   - This avoids Photos permissions + system UI complexity.
   - Still verifies "tap to change photo" end-to-end within our app.

2) **Use PhotosPicker in UI tests**
   - Pre-seed the simulator photo library with a test image using `simctl addmedia`.
   - Pre-grant Photos permission for the app in setup to avoid prompts.
   - Interact with the system picker via XCUI queries.

Recommendation: start with (1) for reliability and speed; we can add (2) later if we really want to validate system integration.

## Accessibility Identifiers (for E2E)

Add stable identifiers for UI testing:

- Timeline / People header avatar button: `"profileAvatarButton"`
- Profile screen root: `"profileScreen"`
- Back button: `"profileBackButton"`
- Large avatar / change-photo tap target: `"profileChangePhotoButton"`
- Full name row: `"profileNameRow"`
- Name edit text field: `"profileNameTextField"`
- Save name button: `"profileNameSaveButton"`
- Email row / edit field equivalents if implemented:
  - `"profileEmailRow"`, `"profileEmailTextField"`, `"profileEmailSaveButton"`

## Tests

### 1) Reducer Tests (fast, deterministic)

Where: `App/Tests/VaporTests/` (or a new `ProfileFeatureTests` folder if we keep tests near feature)

Add tests for:

- `ProfileFeature` loads an existing profile on `.onAppear`
- Editing name/email updates state and persists on save
- `.photoPicked(data)`:
  - Normalizes via `profileImageClient`
  - Persists via `userProfileClient`
  - Emits `.delegate(.didSaveProfile(...))`
- Error handling: simulated save failure sets alert state

Add `AppFeature` integration tests for:

- `.timeline(.avatarTapped)` pushes profile onto `path`
- `.profile(.delegate(.didSaveProfile))` updates `AppFeature.State.userProfile`

### 2) Snapshot Tests (visual regression)

Where: `App/Tests/SnapshotTests/`

Add:

- `ProfileViewSnapshotTests.swift`
  - Default state (no photo, placeholder initials)
  - With photo + name/email set
  - Editing name sheet shown (if we use a sheet)
  - Error alert shown (optional)

Implementation pattern:

- Create `ProfileViewPreview` (like `TimelineViewPreview`) so snapshots don’t rely on async dependencies.

### 3) E2E Tests (headless)

Where: `App/Tests/E2ETests/`

Add:

- `ProfileE2ETests.swift`

Test flow:

1) Launch with `-uiTesting`.
2) Tap `"profileAvatarButton"` on Timeline.
3) Assert `"profileScreen"` exists.
4) Tap `"profileNameRow"` -> edit UI appears.
5) Enter new name -> tap save.
6) Verify updated name is visible on profile screen.
7) Tap `"profileBackButton"` -> return to Timeline.
8) Verify avatar initials update OR verify some other UI reflects the new name (depending on what we surface in header).
9) Tap `"profileAvatarButton"` again -> verify the saved name persists within the running app.

If we implement the UI-test mock photo picker:

10) Tap `"profileChangePhotoButton"` -> pick sample image -> verify avatar updates visually (or via a label/identifier state).

## Step-by-step Implementation Sequence

1) Add `UserProfile` model (Models).
2) Add `UserProfileClient` + `ProfileImageClient` (Persistence or another Core module).
3) Create `ProfileFeature` package (reducer + view) matching `app.pen` layout.
4) Wire navigation:
   - Add `AppFeature.Path.profile`
   - Add destination in `AppView`
   - Add avatar tap action(s) in Timeline/People headers
5) Add app-level `userProfile` state:
   - Load on `AppFeature.onAppear`
   - Pass avatar info down to headers
   - Handle profile delegate updates
6) Implement edit flows (name/email) and photo change.
7) Add accessibility identifiers.
8) Add reducer tests (Profile + App integration).
9) Add snapshot tests for Profile view states.
10) Add E2E tests for navigation + editing + photo change (mock picker recommended).

## Open Questions / Decisions to Confirm

- Should profile open as a **push** on the navigation stack (matches current SessionDetail pattern) or a **sheet**? (Plan assumes push.)
- Which "Account" fields are in scope for v1?
  - Email is safe to store; password should likely remain a stub UI.
- For avatar persistence:
  - Are we okay with `UserDefaults`-backed `Data` for MVP, or should we do file storage immediately?
- Do we want to show user name in the main header (Timeline/People) to make E2E verification easier?

