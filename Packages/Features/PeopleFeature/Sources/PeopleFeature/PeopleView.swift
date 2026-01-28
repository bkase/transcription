import ComposableArchitecture
import DesignSystem
import Models
import Persistence
import PhotosUI
import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - People View

/// Main people directory screen displaying contacts.
/// Matches the People Directory screen from app.pen design.
public struct PeopleView: View {
    @Bindable var store: StoreOf<PeopleFeature>

    public init(store: StoreOf<PeopleFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with avatar and add button
            headerSection

            // Search row
            searchSection

            // People content
            ScrollView {
                peopleContent
                    .padding(.top, VaporSpacing.lg)
                    .padding(.horizontal, VaporSpacing.lg)
                    .padding(.bottom, VaporSpacing.xl)
            }
        }
        .background(VaporColor.mist)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingAddPersonSheet },
            set: { if !$0 { store.send(.dismissSheet) } }
        )) {
            PersonFormSheet(store: store)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            PageHeader(kicker: "Directory", title: "People")
            Spacer()
            Button {
                store.send(.addPersonTapped)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(VaporColor.deep)
            }
            .accessibilityIdentifier("addPersonButton")

            Button {
                store.send(.avatarTapped)
            } label: {
                avatarView
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("profileAvatarButton")
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
    }

    @ViewBuilder
    private var avatarView: some View {
        #if os(iOS)
        if let imageData = store.userProfile.avatar.imageData,
           let uiImage = UIImage(data: imageData) {
            Avatar(image: Image(uiImage: uiImage), size: .medium)
        } else if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .medium)
        } else {
            Avatar(size: .medium)
        }
        #else
        if !store.initials.isEmpty {
            Avatar(initials: store.initials, size: .medium)
        } else {
            Avatar(size: .medium)
        }
        #endif
    }

    // MARK: - Search Section

    private var searchSection: some View {
        SearchField(
            text: $store.searchQuery.sending(\.searchQueryChanged),
            placeholder: "Search..."
        )
        .padding(.horizontal, VaporSpacing.lg)
    }

    // MARK: - People Content

    @ViewBuilder
    private var peopleContent: some View {
        if store.filteredPeople.isEmpty {
            emptyStateContent
        } else {
            peopleListContent
        }
    }

    private var peopleListContent: some View {
        LazyVStack(spacing: VaporSpacing.sm) {
            ForEach(store.filteredPeople, id: \.id) { person in
                personCard(for: person)
                    .contextMenu {
                        Button {
                            store.send(.editPersonTapped(person))
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            store.send(.deletePersonTapped(PersonID(rawValue: person.id)))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        store.send(.personTapped(PersonID(rawValue: person.id)))
                    }
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.md) {
            if store.searchQuery.isEmpty {
                Text("No people yet")
                    .vaporTextStyle(.body)
                    .foregroundColor(VaporColor.textSecondary)

                Button {
                    store.send(.addPersonTapped)
                } label: {
                    Text("Add a person")
                        .vaporTextStyle(.body)
                        .foregroundColor(VaporColor.deep)
                }
            } else {
                Text("No results found")
                    .vaporTextStyle(.body)
                    .foregroundColor(VaporColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }

    private func personCard(for person: PersonRecord) -> some View {
        let speakerColor = SpeakerColor(rawValue: person.colorToken) ?? .sky
        return PersonCard(
            name: person.name,
            imageData: person.imageData,
            conversationCount: store.state.conversationCount(for: person.id),
            color: speakerColor
        )
    }
}

// MARK: - Person Form Sheet

struct PersonFormSheet: View {
    @Bindable var store: StoreOf<PeopleFeature>
    @State private var selectedPhoto: PhotosPickerItem?

    /// Whether we're running in UI testing mode
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: VaporSpacing.lg) {
                // Avatar/Photo section
                avatarSection

                // Name field
                VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                    Text("Name")
                        .vaporTextStyle(.caption)
                        .foregroundColor(VaporColor.textSecondary)

                    TextField("Enter name", text: $store.formName.sending(\.formNameChanged))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("personNameField")
                }

                // Color picker
                VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                    Text("Color")
                        .vaporTextStyle(.caption)
                        .foregroundColor(VaporColor.textSecondary)

                    HStack(spacing: VaporSpacing.sm) {
                        ForEach(SpeakerColor.allCases, id: \.rawValue) { color in
                            colorButton(for: color)
                        }
                    }
                }

                // Error display
                if let error = store.error {
                    Text(error)
                        .vaporTextStyle(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding(VaporSpacing.lg)
            .background(VaporColor.mist)
            .navigationTitle(store.isEditing ? "Edit Person" : "Add Person")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismissSheet)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.savePerson)
                    }
                    .disabled(store.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSaving)
                    .accessibilityIdentifier("savePersonButton")
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.send(.photoPicked(data))
                    }
                }
                selectedPhoto = nil
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isShowingMockPhotoPicker },
                    set: { if !$0 { store.send(.dismissMockPhotoPicker) } }
                )
            ) {
                PersonMockPhotoPickerSheet(store: store)
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: VaporSpacing.sm) {
            // Avatar with camera badge
            if isUITesting {
                // Mock picker button for UI tests
                Button {
                    store.send(.showMockPhotoPicker)
                } label: {
                    avatarWithBadge
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("personChangePhotoButton")
            } else {
                // Real PhotosPicker for live mode
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatarWithBadge
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("personChangePhotoButton")
            }

            // Helper text and remove button
            if store.formImageData != nil {
                Button {
                    store.send(.removePhotoTapped)
                } label: {
                    Text("Remove photo")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(VaporColor.recording)
                }
                .accessibilityIdentifier("removePhotoButton")
            } else {
                Text("Tap to add photo")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, VaporSpacing.sm)
    }

    private var avatarWithBadge: some View {
        let speakerColor = SpeakerColor(rawValue: store.formColorToken) ?? .sky

        return ZStack(alignment: .bottomTrailing) {
            avatarImage(size: 80, fontSize: 28, color: speakerColor)

            // Camera badge
            ZStack {
                Circle()
                    .fill(VaporColor.cloud)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .strokeBorder(VaporColor.fog, lineWidth: 1)
                    )

                Image(systemName: "camera")
                    .font(.system(size: 14))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private func avatarImage(size: CGFloat, fontSize: CGFloat, color: SpeakerColor) -> some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(VaporColor.fog, lineWidth: size > 50 ? 2 : 1)
                )

            #if os(iOS)
            if let imageData = store.formImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                initialsView(fontSize: fontSize)
            }
            #else
            initialsView(fontSize: fontSize)
            #endif
        }
    }

    @ViewBuilder
    private func initialsView(fontSize: CGFloat) -> some View {
        let initials = generateInitials(from: store.formName)
        if !initials.isEmpty {
            Text(initials)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(VaporColor.cloud)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: fontSize))
                .foregroundColor(VaporColor.cloud.opacity(0.8))
        }
    }

    private func generateInitials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let components = trimmed.split(separator: " ")
        let first = components.first?.prefix(1) ?? ""
        let last = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return String(first + last).uppercased()
    }

    private func colorButton(for color: SpeakerColor) -> some View {
        let isSelected = store.formColorToken == color.rawValue
        return Button {
            store.send(.formColorChanged(color.rawValue))
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 40, height: 40)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(VaporColor.textPrimary, lineWidth: 3)
                    }
                }
        }
        .accessibilityIdentifier("color_\(color.rawValue)")
    }
}

// MARK: - Mock Photo Picker Sheet (for UI Testing)

/// A simple sheet with pre-defined photo options for deterministic UI testing.
/// Avoids system Photos picker which is difficult to automate in XCUITest.
struct PersonMockPhotoPickerSheet: View {
    let store: StoreOf<PeopleFeature>

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(MockPhotoData.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        store.send(.mockPhotoSelected(index))
                    } label: {
                        HStack {
                            Circle()
                                .fill(colorForName(option.color))
                                .frame(width: 44, height: 44)

                            Text(option.name)
                                .foregroundColor(VaporColor.textPrimary)
                        }
                    }
                    .accessibilityIdentifier("personMockPhotoOption-\(index)")
                }
            }
            .navigationTitle("Choose Photo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismissMockPhotoPicker)
                    }
                    .accessibilityIdentifier("personMockPhotoPickerCancel")
                }
            }
        }
        .accessibilityIdentifier("personMockPhotoPickerSheet")
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - People View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct PeopleViewPreview: View {
    public struct PersonData: Identifiable {
        public let id: String
        public let name: String
        public let conversationCount: Int
        public let color: SpeakerColor

        public init(
            id: String = UUID().uuidString,
            name: String,
            conversationCount: Int,
            color: SpeakerColor = .sky
        ) {
            self.id = id
            self.name = name
            self.conversationCount = conversationCount
            self.color = color
        }
    }

    /// Display mode for the people preview
    public enum DisplayMode {
        /// Normal people list view
        case list
        /// Empty state with no people
        case empty
        /// Search results with no matches
        case emptySearch
    }

    private let people: [PersonData]
    private let searchText: String
    private let displayMode: DisplayMode

    public init(people: [PersonData], searchText: String = "") {
        self.people = people
        self.searchText = searchText
        self.displayMode = .list
    }

    public init(displayMode: DisplayMode, searchText: String = "") {
        self.displayMode = displayMode
        self.searchText = searchText
        switch displayMode {
        case .list:
            self.people = []
        case .empty:
            self.people = []
        case .emptySearch:
            self.people = []
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                PageHeader(kicker: "Directory", title: "People")
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(VaporColor.deep)
                Avatar(size: .medium)
            }
            .padding(.top, 56)
            .padding(.horizontal, VaporSpacing.lg)
            .padding(.bottom, VaporSpacing.md)

            // Search
            SearchFieldPreview(text: searchText, placeholder: "Search...")
                .padding(.horizontal, VaporSpacing.lg)

            // Content
            ScrollView {
                contentView
                    .padding(.top, VaporSpacing.lg)
                    .padding(.horizontal, VaporSpacing.lg)
                    .padding(.bottom, VaporSpacing.xl)
            }
        }
        .background(VaporColor.mist)
    }

    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .list:
            peopleListContent
        case .empty:
            emptyStateContent
        case .emptySearch:
            emptySearchContent
        }
    }

    private var peopleListContent: some View {
        LazyVStack(spacing: VaporSpacing.sm) {
            ForEach(people) { person in
                PersonCardPreview(
                    name: person.name,
                    conversationCount: person.conversationCount,
                    color: person.color
                )
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.md) {
            Text("No people yet")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }

    private var emptySearchContent: some View {
        VStack(spacing: VaporSpacing.md) {
            Text("No results found")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }
}

// MARK: - Previews

#if DEBUG
struct PeopleView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleViewPreview(
            people: [
                .init(name: "Sarah Chen", conversationCount: 12, color: .sky),
                .init(name: "Marcus Kim", conversationCount: 8, color: .lavender),
                .init(name: "Alex Rivera", conversationCount: 3, color: .deep),
                .init(name: "Jordan Lee", conversationCount: 1, color: .dusk)
            ]
        )
    }
}
#endif
