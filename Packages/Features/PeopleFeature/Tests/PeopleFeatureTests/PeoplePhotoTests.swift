import Testing
import Foundation
import ComposableArchitecture
import Models
import Persistence
import DesignSystem
@testable import PeopleFeature

@MainActor
struct PeoplePhotoTests {

    // MARK: - Photo Picking Flow

    @Test
    func testPhotoPickedTriggersNormalization() async {
        let mockImageData = Data([0x89, 0x50, 0x4E, 0x47])
        let normalizedData = Data([0x01, 0x02, 0x03])

        var normalizeCalledWith: Data?
        var normalizeMaxDimension: Int?
        var normalizeCompressionQuality: Double?

        let store = TestStore(initialState: PeopleFeature.State(destination: .addPersonSheet)) {
            PeopleFeature()
        } withDependencies: {
            $0.profileImageClient.normalize = { data, maxDim, compression in
                normalizeCalledWith = data
                normalizeMaxDimension = maxDim
                normalizeCompressionQuality = compression
                return normalizedData
            }
        }

        await store.send(.photoPicked(mockImageData))

        await store.receive(\.photoProcessed) {
            $0.formImageData = normalizedData
        }

        #expect(normalizeCalledWith == mockImageData)
        #expect(normalizeMaxDimension == 256)
        #expect(normalizeCompressionQuality == 0.8)
    }

    @Test
    func testPhotoProcessedFailure() async {
        let mockImageData = Data([0x89, 0x50, 0x4E, 0x47])

        let store = TestStore(initialState: PeopleFeature.State(destination: .addPersonSheet)) {
            PeopleFeature()
        } withDependencies: {
            $0.profileImageClient.normalize = { _, _, _ in nil }
        }

        await store.send(.photoPicked(mockImageData))

        await store.receive(\.photoProcessed) {
            $0.error = "Failed to process image"
        }
    }

    @Test
    func testRemovePhotoTapped() async {
        let imageData = Data([0x01, 0x02, 0x03])

        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            formImageData: imageData
        )) {
            PeopleFeature()
        }

        await store.send(.removePhotoTapped) {
            $0.formImageData = nil
        }
    }

    // MARK: - Mock Photo Picker

    @Test
    func testShowMockPhotoPicker() async {
        let store = TestStore(initialState: PeopleFeature.State(destination: .addPersonSheet)) {
            PeopleFeature()
        }

        await store.send(.showMockPhotoPicker) {
            $0.isShowingMockPhotoPicker = true
        }
    }

    @Test
    func testMockPhotoSelectedTriggersPhotoPicked() async {
        let normalizedData = Data([0x01, 0x02, 0x03])

        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            isShowingMockPhotoPicker: true
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.profileImageClient.normalize = { _, _, _ in normalizedData }
        }

        await store.send(.mockPhotoSelected(0)) {
            $0.isShowingMockPhotoPicker = false
        }

        // The mock photo selected triggers photoPicked with generated data
        await store.receive(\.photoPicked)

        await store.receive(\.photoProcessed) {
            $0.formImageData = normalizedData
        }
    }

    @Test
    func testDismissMockPhotoPicker() async {
        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            isShowingMockPhotoPicker: true
        )) {
            PeopleFeature()
        }

        await store.send(.dismissMockPhotoPicker) {
            $0.isShowingMockPhotoPicker = false
        }
    }

    // MARK: - Create/Edit with Image

    @Test
    func testCreatePersonWithImage() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let mockUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let imageData = Data([0x01, 0x02, 0x03])

        var createdPerson: PersonRecord?

        let store = TestStore(initialState: PeopleFeature.State(
            destination: .addPersonSheet,
            formName: "Alice Smith",
            formColorToken: "lavender",
            formImageData: imageData
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.uuid = .constant(mockUUID)
            $0.date = .constant(mockDate)
            $0.databaseClient.createPerson = { person in
                createdPerson = person
            }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let expectedPerson = PersonRecord(
            id: mockUUID.uuidString,
            name: "Alice Smith",
            colorToken: "lavender",
            imageData: imageData,
            createdAt: mockDate,
            updatedAt: mockDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.destination = nil
            $0.people = [expectedPerson]
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
        }

        #expect(createdPerson?.imageData == imageData)
    }

    @Test
    func testEditPersonLoadsExistingImage() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let imageData = Data([0x01, 0x02, 0x03])
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            imageData: imageData,
            createdAt: mockDate,
            updatedAt: mockDate
        )

        let store = TestStore(initialState: PeopleFeature.State(people: [existingPerson])) {
            PeopleFeature()
        }

        await store.send(.editPersonTapped(existingPerson)) {
            $0.editingPerson = existingPerson
            $0.formName = "Alice"
            $0.formColorToken = "sky"
            $0.formImageData = imageData
            $0.destination = .addPersonSheet
        }
    }

    @Test
    func testUpdatePersonPreservesImageWhenNotChanged() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let updatedDate = Date(timeIntervalSince1970: 2000000)
        let imageData = Data([0x01, 0x02, 0x03])
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            imageData: imageData,
            createdAt: mockDate,
            updatedAt: mockDate
        )

        var updatedPerson: PersonRecord?

        let store = TestStore(initialState: PeopleFeature.State(
            people: [existingPerson],
            destination: .addPersonSheet,
            editingPerson: existingPerson,
            formName: "Alice Updated",
            formColorToken: "deep",
            formImageData: imageData
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.date = .constant(updatedDate)
            $0.databaseClient.updatePerson = { person in
                updatedPerson = person
            }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let expectedPerson = PersonRecord(
            id: "person-1",
            name: "Alice Updated",
            colorToken: "deep",
            imageData: imageData,
            createdAt: mockDate,
            updatedAt: updatedDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.destination = nil
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.people = [expectedPerson]
        }

        #expect(updatedPerson?.imageData == imageData)
    }

    @Test
    func testUpdatePersonRemovesImage() async {
        let mockDate = Date(timeIntervalSince1970: 1000000)
        let updatedDate = Date(timeIntervalSince1970: 2000000)
        let imageData = Data([0x01, 0x02, 0x03])
        let existingPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            imageData: imageData,
            createdAt: mockDate,
            updatedAt: mockDate
        )

        var updatedPerson: PersonRecord?

        let store = TestStore(initialState: PeopleFeature.State(
            people: [existingPerson],
            destination: .addPersonSheet,
            editingPerson: existingPerson,
            formName: "Alice",
            formColorToken: "sky",
            formImageData: nil  // User removed the image
        )) {
            PeopleFeature()
        } withDependencies: {
            $0.date = .constant(updatedDate)
            $0.databaseClient.updatePerson = { person in
                updatedPerson = person
            }
        }

        await store.send(.savePerson) {
            $0.isSaving = true
        }

        let expectedPerson = PersonRecord(
            id: "person-1",
            name: "Alice",
            colorToken: "sky",
            imageData: nil,
            createdAt: mockDate,
            updatedAt: updatedDate
        )

        await store.receive(\.personSaved) {
            $0.isSaving = false
            $0.destination = nil
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil
            $0.people = [expectedPerson]
        }

        #expect(updatedPerson?.imageData == nil)
    }

    // MARK: - Add Person Resets Form Image

    @Test
    func testAddPersonTappedResetsFormImage() async {
        let imageData = Data([0x01, 0x02, 0x03])

        let store = TestStore(initialState: PeopleFeature.State(
            formImageData: imageData  // Leftover from previous interaction
        )) {
            PeopleFeature()
        }

        await store.send(.addPersonTapped) {
            $0.destination = .addPersonSheet
            $0.editingPerson = nil
            $0.formName = ""
            $0.formColorToken = SpeakerColor.sky.rawValue
            $0.formImageData = nil  // Should be reset
        }
    }
}
