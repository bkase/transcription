import ComposableArchitecture
import DesignSystem
import Models
import Persistence
import SwiftUI

// MARK: - Speaker Picker View

/// Modal view for selecting or creating a speaker assignment.
/// Uses the SpeakerPickerModal component from DesignSystem.
public struct SpeakerPickerView: View {
    @Bindable var store: StoreOf<SpeakerPickerFeature>

    public init(store: StoreOf<SpeakerPickerFeature>) {
        self.store = store
    }

    public var body: some View {
        SpeakerPickerModal(
            title: "Assign Speaker \(store.displayOrder)",
            onClose: { store.send(.closeModal) }
        ) {
            modalContent
        }
        .padding(VaporSpacing.lg)
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var modalContent: some View {
        if store.isLoading {
            loadingContent
        } else if store.isShowingNewPersonForm {
            newPersonFormContent
        } else {
            pickerContent
        }
    }

    // MARK: - Loading Content

    private var loadingContent: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(VaporSpacing.lg)
            Spacer()
        }
    }

    // MARK: - Picker Content

    @ViewBuilder
    private var pickerContent: some View {
        // Error display
        if let error = store.error {
            Text(error)
                .vaporTextStyle(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }

        // Existing speakers section
        if !store.people.isEmpty {
            SpeakerPickerSectionLabel("Existing Speakers")

            ForEach(store.people, id: \.id) { person in
                personOption(for: person)
            }

            // Divider
            Rectangle()
                .fill(VaporColor.fog)
                .frame(height: 1)
                .padding(.vertical, 4)
        }

        // Create new section
        SpeakerPickerSectionLabel("Create New")

        Button {
            store.send(.addNewPersonTapped)
        } label: {
            NewSpeakerOption()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addNewPersonOption")

        // Confirm button if a selection is made
        if store.selectedPersonId != nil && store.selectedPersonId != store.currentPersonId {
            confirmButton
        }
    }

    private func personOption(for person: PersonRecord) -> some View {
        let speakerColor = SpeakerColor(rawValue: person.colorToken) ?? .sky
        let isSelected = store.selectedPersonId?.rawValue == person.id

        return Button {
            store.send(.personSelected(PersonID(person.id)))
        } label: {
            SpeakerOption(
                name: person.name,
                color: speakerColor,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("personOption_\(person.id)")
    }

    private var confirmButton: some View {
        HStack {
            Spacer()
            Button {
                store.send(.confirmSelection)
            } label: {
                Text("Confirm")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(
                        Capsule()
                            .fill(VaporColor.deep)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("confirmSelectionButton")
            Spacer()
        }
        .padding(.top, VaporSpacing.md)
        .padding(.horizontal, 20)
    }

    // MARK: - New Person Form Content

    @ViewBuilder
    private var newPersonFormContent: some View {
        VStack(spacing: VaporSpacing.md) {
            // Back button
            HStack {
                Button {
                    store.send(.cancelNewPerson)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(VaporColor.deep)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backButton")
                Spacer()
            }
            .padding(.horizontal, 20)

            // Name input
            SpeakerNameInput(
                name: $store.newPersonName.sending(\.newPersonNameChanged),
                onSave: { store.send(.saveNewPerson) }
            )
            .padding(.horizontal, 20)
            .accessibilityIdentifier("newPersonNameInput")

            // Color picker
            colorPicker
                .padding(.horizontal, 20)

            // Error display
            if let error = store.error {
                Text(error)
                    .vaporTextStyle(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }

            // Saving indicator
            if store.isSaving {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(VaporSpacing.sm)
                    Spacer()
                }
            }
        }
        .padding(.vertical, VaporSpacing.sm)
    }

    private var colorPicker: some View {
        HStack(spacing: VaporSpacing.sm) {
            Text("Color")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VaporColor.textSecondary)

            Spacer()

            ForEach(SpeakerColor.allCases, id: \.rawValue) { color in
                colorButton(for: color)
            }
        }
    }

    private func colorButton(for color: SpeakerColor) -> some View {
        let isSelected = store.newPersonColorToken == color.rawValue
        return Button {
            store.send(.newPersonColorChanged(color.rawValue))
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 28, height: 28)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(VaporColor.textPrimary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("newPersonColor_\(color.rawValue)")
    }
}

// MARK: - Speaker Picker View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
public struct SpeakerPickerViewPreview: View {
    public struct PersonData: Identifiable {
        public let id: String
        public let name: String
        public let color: SpeakerColor
        public let isSelected: Bool

        public init(
            id: String = UUID().uuidString,
            name: String,
            color: SpeakerColor = .sky,
            isSelected: Bool = false
        ) {
            self.id = id
            self.name = name
            self.color = color
            self.isSelected = isSelected
        }
    }

    public enum DisplayMode {
        case loading
        case picker(people: [PersonData], showNewOption: Bool)
        case newPersonForm(name: String)
    }

    private let displayOrder: Int
    private let displayMode: DisplayMode

    public init(displayOrder: Int = 1, displayMode: DisplayMode) {
        self.displayOrder = displayOrder
        self.displayMode = displayMode
    }

    public var body: some View {
        SpeakerPickerModal(
            title: "Assign Speaker \(displayOrder)",
            onClose: {}
        ) {
            contentView
        }
        .padding(VaporSpacing.lg)
    }

    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                    .padding(VaporSpacing.lg)
                Spacer()
            }

        case let .picker(people, showNewOption):
            pickerContent(people: people, showNewOption: showNewOption)

        case let .newPersonForm(name):
            newPersonFormContent(name: name)
        }
    }

    @ViewBuilder
    private func pickerContent(people: [PersonData], showNewOption: Bool) -> some View {
        if !people.isEmpty {
            SpeakerPickerSectionLabel("Existing Speakers")

            ForEach(people) { person in
                SpeakerOption(
                    name: person.name,
                    color: person.color,
                    isSelected: person.isSelected
                )
            }

            Rectangle()
                .fill(VaporColor.fog)
                .frame(height: 1)
                .padding(.vertical, 4)
        }

        if showNewOption {
            SpeakerPickerSectionLabel("Create New")
            NewSpeakerOption()
        }
    }

    @ViewBuilder
    private func newPersonFormContent(name: String) -> some View {
        VStack(spacing: VaporSpacing.md) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(VaporColor.deep)
                Spacer()
            }
            .padding(.horizontal, 20)

            SpeakerNameInputPreview(name: name)
                .padding(.horizontal, 20)

            HStack(spacing: VaporSpacing.sm) {
                Text("Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VaporColor.textSecondary)

                Spacer()

                ForEach(SpeakerColor.allCases, id: \.rawValue) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if color == .sky {
                                Circle()
                                    .stroke(VaporColor.textPrimary, lineWidth: 2)
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, VaporSpacing.sm)
    }
}

// MARK: - Previews

#if DEBUG
struct SpeakerPickerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            SpeakerPickerViewPreview(
                displayOrder: 1,
                displayMode: .picker(
                    people: [
                        .init(name: "Sarah Chen", color: .sky, isSelected: false),
                        .init(name: "Marcus Kim", color: .lavender, isSelected: true)
                    ],
                    showNewOption: true
                )
            )

            SpeakerPickerViewPreview(
                displayOrder: 2,
                displayMode: .newPersonForm(name: "John Doe")
            )
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
