import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Persistence
import DesignSystem

@Reducer
public struct SpeakerPickerFeature {
    public init() {}

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    @ObservableState
    public struct State: Equatable {
        /// The speaker track being assigned
        public var speakerTrackId: String
        /// The session this speaker track belongs to
        public var sessionId: SessionID
        /// Display order of the speaker (for UI label like "Speaker 1")
        public var displayOrder: Int
        /// Currently assigned person ID (if any)
        public var currentPersonId: PersonID?

        /// Available people to choose from
        public var people: [PersonRecord] = []
        /// Currently selected person ID (may differ from currentPersonId during selection)
        public var selectedPersonId: PersonID?
        /// Loading state for fetching people
        public var isLoading: Bool = false
        /// Error message if loading fails
        public var error: String?

        /// Whether we're showing the new person form
        public var isShowingNewPersonForm: Bool = false
        /// New person name input
        public var newPersonName: String = ""
        /// New person color token
        public var newPersonColorToken: String = SpeakerColor.sky.rawValue
        /// Saving state for creating new person
        public var isSaving: Bool = false

        /// Current user profile (for "You" option in picker)
        public var userProfile: UserProfile = .empty

        /// Special PersonID representing the current user ("You")
        public static let currentUserPersonId = PersonID("__current_user__")

        /// Whether the current user is selected
        public var isCurrentUserSelected: Bool {
            selectedPersonId == Self.currentUserPersonId
        }

        /// Whether to show the "You" option (only if user has a name)
        public var showCurrentUserOption: Bool {
            !userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        public init(
            speakerTrackId: String,
            sessionId: SessionID,
            displayOrder: Int,
            currentPersonId: PersonID? = nil,
            people: [PersonRecord] = [],
            selectedPersonId: PersonID? = nil,
            isLoading: Bool = false,
            error: String? = nil,
            isShowingNewPersonForm: Bool = false,
            newPersonName: String = "",
            newPersonColorToken: String = SpeakerColor.sky.rawValue,
            isSaving: Bool = false,
            userProfile: UserProfile = .empty
        ) {
            self.speakerTrackId = speakerTrackId
            self.sessionId = sessionId
            self.displayOrder = displayOrder
            self.currentPersonId = currentPersonId
            self.people = people
            self.selectedPersonId = selectedPersonId ?? currentPersonId
            self.isLoading = isLoading
            self.error = error
            self.isShowingNewPersonForm = isShowingNewPersonForm
            self.newPersonName = newPersonName
            self.newPersonColorToken = newPersonColorToken
            self.isSaving = isSaving
            self.userProfile = userProfile
        }
    }

    public enum Action: Sendable {
        case onAppear
        case loadPeople
        case peopleLoaded([PersonRecord])
        case peopleFailed(String)

        case personSelected(PersonID)
        case confirmSelection
        case selectionConfirmed(PersonID)
        case selectionFailed(String)

        case addNewPersonTapped
        case cancelNewPerson
        case newPersonNameChanged(String)
        case newPersonColorChanged(String)
        case saveNewPerson
        case newPersonSaved(PersonRecord)
        case newPersonFailed(String)

        case closeModal
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.people.isEmpty && !state.isLoading else {
                    return .none
                }
                return .send(.loadPeople)

            case .loadPeople:
                state.isLoading = true
                state.error = nil

                return .run { send in
                    let people = try await databaseClient.fetchPeople()
                    await send(.peopleLoaded(people))
                } catch: { error, send in
                    await send(.peopleFailed(error.localizedDescription))
                }

            case let .peopleLoaded(people):
                state.isLoading = false
                state.people = people
                return .none

            case let .peopleFailed(errorMessage):
                state.isLoading = false
                state.error = errorMessage
                return .none

            case let .personSelected(personId):
                state.selectedPersonId = personId
                return .none

            case .confirmSelection:
                guard let selectedPersonId = state.selectedPersonId else {
                    return .none
                }

                // Update the speaker track with the selected person
                let speakerTrackId = state.speakerTrackId
                let sessionId = state.sessionId
                let isCurrentUser = selectedPersonId == State.currentUserPersonId
                let userProfile = state.userProfile

                return .run { [speakerTrackId, sessionId, isCurrentUser, userProfile, uuid, date] send in
                    // Fetch current speaker track to update it
                    let tracks = try await databaseClient.fetchSpeakerTracks(sessionId)
                    guard let track = tracks.first(where: { $0.id == speakerTrackId }) else {
                        await send(.selectionFailed("Speaker track not found"))
                        return
                    }

                    // Determine the actual person ID to use
                    let actualPersonId: String
                    if isCurrentUser {
                        // Check if a person with this user's name already exists
                        let existingPeople = try await databaseClient.fetchPeople()
                        let userName = userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let existingPerson = existingPeople.first(where: {
                            $0.name.lowercased() == userName.lowercased()
                        }) {
                            // Use existing person
                            actualPersonId = existingPerson.id
                        } else {
                            // Create a new person for the current user
                            let newPerson = PersonRecord(
                                id: uuid().uuidString,
                                name: userName,
                                colorToken: SpeakerColor.sky.rawValue,
                                createdAt: date.now,
                                updatedAt: date.now
                            )
                            try await databaseClient.createPerson(newPerson)
                            actualPersonId = newPerson.id
                        }
                    } else {
                        actualPersonId = selectedPersonId.rawValue
                    }

                    let updatedTrack = SpeakerTrackRecord(
                        id: track.id,
                        sessionId: track.sessionId,
                        machineSpeakerId: track.machineSpeakerId,
                        displayOrder: track.displayOrder,
                        personId: actualPersonId
                    )

                    try await databaseClient.updateSpeakerTrack(updatedTrack)
                    await send(.selectionConfirmed(PersonID(actualPersonId)))
                } catch: { error, send in
                    await send(.selectionFailed(error.localizedDescription))
                }

            case .selectionConfirmed:
                // Parent will handle dismissal and any follow-up
                return .none

            case let .selectionFailed(errorMessage):
                state.error = errorMessage
                return .none

            case .addNewPersonTapped:
                state.isShowingNewPersonForm = true
                state.newPersonName = ""
                state.newPersonColorToken = SpeakerColor.forIndex(state.people.count).rawValue
                state.error = nil
                return .none

            case .cancelNewPerson:
                state.isShowingNewPersonForm = false
                state.newPersonName = ""
                state.newPersonColorToken = SpeakerColor.sky.rawValue
                return .none

            case let .newPersonNameChanged(name):
                state.newPersonName = name
                return .none

            case let .newPersonColorChanged(colorToken):
                state.newPersonColorToken = colorToken
                return .none

            case .saveNewPerson:
                let trimmedName = state.newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.error = "Name cannot be empty"
                    return .none
                }

                state.isSaving = true
                state.error = nil

                let newPerson = PersonRecord(
                    id: uuid().uuidString,
                    name: trimmedName,
                    colorToken: state.newPersonColorToken,
                    createdAt: date.now,
                    updatedAt: date.now
                )

                return .run { [newPerson] send in
                    try await databaseClient.createPerson(newPerson)
                    await send(.newPersonSaved(newPerson))
                } catch: { error, send in
                    await send(.newPersonFailed(error.localizedDescription))
                }

            case let .newPersonSaved(person):
                state.isSaving = false
                state.isShowingNewPersonForm = false
                state.newPersonName = ""
                state.newPersonColorToken = SpeakerColor.sky.rawValue

                // Add new person to list and select them
                state.people.append(person)
                state.people.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                state.selectedPersonId = PersonID(person.id)
                return .none

            case let .newPersonFailed(errorMessage):
                state.isSaving = false
                state.error = errorMessage
                return .none

            case .closeModal:
                // Parent will handle dismissal
                return .none
            }
        }
    }
}
