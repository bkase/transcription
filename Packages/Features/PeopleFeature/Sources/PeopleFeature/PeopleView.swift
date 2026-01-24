import ComposableArchitecture
import DesignSystem
import Models
import Persistence
import SwiftUI

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
            // Header with avatar
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
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            PageHeader(kicker: "Directory", title: "People")
            Spacer()
            Avatar(size: .medium)
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
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
        // Note: conversationCount would come from a separate query/join in a full implementation
        return PersonCard(
            name: person.name,
            conversationCount: 0,
            color: speakerColor
        )
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
