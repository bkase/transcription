import ComposableArchitecture
import DesignSystem
import Models
import Observability
import Persistence
import SwiftUI

// MARK: - Timeline View

/// Main timeline (archive) screen displaying sessions grouped by date.
/// Matches the Home screens from app.pen design.
public struct TimelineView: View {
    @Bindable var store: StoreOf<TimelineFeature>

    public init(store: StoreOf<TimelineFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                // Header with avatar
                headerSection

                // Search row
                searchSection

                // Sessions content
                ScrollView {
                    sessionsContent
                        .padding(.top, VaporSpacing.lg)
                        .padding(.horizontal, VaporSpacing.lg)
                        .padding(.bottom, 120) // Space for FAB
                }
            }

            // Floating action button
            fabSection
        }
        .background(VaporColor.mist)
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            item: Binding(
                get: { store.alertInfo },
                set: { if $0 == nil { store.send(.alertDismissed) } }
            )
        ) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                primaryButton: alertButton(for: alertInfo.primaryButton),
                secondaryButton: alertInfo.secondaryButton.map { alertButton(for: $0) } ?? .cancel()
            )
        }
    }

    private func alertButton(for button: AlertInfo.AlertButton) -> Alert.Button {
        if button.isDestructive {
            return .destructive(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        } else if button.action == .dismiss {
            return .cancel(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        } else {
            return .default(Text(button.title)) {
                store.send(.alertActionTapped(button.action))
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            PageHeader(kicker: "Archive", title: "Timeline")
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
            placeholder: "Search transcripts..."
        )
        .padding(.horizontal, VaporSpacing.lg)
    }

    // MARK: - Sessions Content

    @ViewBuilder
    private var sessionsContent: some View {
        if store.isSearching {
            searchResultsContent
        } else {
            groupedSessionsContent
        }
    }

    private var groupedSessionsContent: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.xl + VaporSpacing.sm) {
            if store.sessionGroups.isEmpty && !store.isLoading {
                emptyStateContent
            } else {
                ForEach(store.sessionGroups, id: \.bucket) { group in
                    sessionSection(for: group)
                }
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.lg) {
            Spacer()
                .frame(height: VaporSpacing.xl * 4)

            Text("No recordings yet")
                .vaporTextStyle(.title)
                .foregroundColor(VaporColor.textSecondary)

            Text("Tap the record button to start capturing")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchResultsContent: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.md) {
            if store.searchResults.isEmpty {
                emptySearchState
            } else {
                DateHeader("RESULTS")

                VStack(spacing: VaporSpacing.sm) {
                    ForEach(store.searchResults, id: \.id) { session in
                        sessionCard(for: session)
                            .onTapGesture {
                                store.send(.sessionTapped(SessionID(rawValue: session.id)))
                            }
                    }
                }
            }
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: VaporSpacing.md) {
            Text("No results found")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }

    private func sessionSection(for group: SessionGroup) -> some View {
        VStack(alignment: .leading, spacing: VaporSpacing.md) {
            // Date header
            dateHeader(for: group.bucket)

            // Session cards
            VStack(spacing: VaporSpacing.sm) {
                ForEach(group.sessions, id: \.id) { session in
                    sessionCard(for: session)
                        .onTapGesture {
                            store.send(.sessionTapped(SessionID(rawValue: session.id)))
                        }
                }
            }
        }
    }

    private func dateHeader(for bucket: DateBucket) -> some View {
        switch bucket {
        case .today:
            return DateHeader.today
        case .yesterday:
            return DateHeader.yesterday
        case .thisWeek:
            return DateHeader("THIS WEEK")
        case .lastWeek:
            return DateHeader("LAST WEEK")
        case .thisMonth:
            return DateHeader("THIS MONTH")
        case .older:
            return DateHeader("OLDER")
        }
    }

    private func sessionCard(for session: SessionRecord) -> some View {
        let viewModel = SessionCardViewModel.from(session: session)
        return SessionCard(
            title: viewModel.title,
            time: viewModel.time,
            previewText: viewModel.previewText,
            speakerCount: viewModel.speakerCount,
            duration: viewModel.duration
        )
    }

    // MARK: - FAB Section

    private var fabSection: some View {
        HStack {
            Spacer()
            RecordButton(isRecording: false) {
                store.send(.newRecordingTapped)
            }
            Spacer()
        }
        .padding(.bottom, VaporSpacing.lg)
    }

}

// MARK: - Timeline View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct TimelineViewPreview: View {
    public struct SessionData: Identifiable {
        public let id: String
        public let title: String
        public let time: String
        public let previewText: String
        public let speakerCount: Int?
        public let duration: String?
        public let showMetadata: Bool

        public init(
            id: String = UUID().uuidString,
            title: String,
            time: String,
            previewText: String,
            speakerCount: Int? = nil,
            duration: String? = nil,
            showMetadata: Bool = false
        ) {
            self.id = id
            self.title = title
            self.time = time
            self.previewText = previewText
            self.speakerCount = speakerCount
            self.duration = duration
            self.showMetadata = showMetadata
        }
    }

    public struct SectionData: Identifiable {
        public let id: String
        public let header: String
        public let sessions: [SessionData]

        public init(header: String, sessions: [SessionData]) {
            self.id = header
            self.header = header
            self.sessions = sessions
        }
    }

    /// Display mode for the timeline preview
    public enum DisplayMode {
        /// Normal grouped timeline view
        case grouped
        /// Empty state with no sessions
        case empty
        /// Search results mode
        case searchResults(results: [SessionData])
    }

    private let sections: [SectionData]
    private let searchText: String
    private let displayMode: DisplayMode

    public init(sections: [SectionData], searchText: String = "") {
        self.sections = sections
        self.searchText = searchText
        self.displayMode = .grouped
    }

    public init(displayMode: DisplayMode, searchText: String = "") {
        self.displayMode = displayMode
        self.searchText = searchText
        switch displayMode {
        case .grouped:
            self.sections = []
        case .empty:
            self.sections = []
        case .searchResults:
            self.sections = []
        }
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    PageHeader(kicker: "Archive", title: "Timeline")
                    Spacer()
                    Avatar(size: .medium)
                }
                .padding(.top, 56)
                .padding(.horizontal, VaporSpacing.lg)
                .padding(.bottom, VaporSpacing.md)

                // Search
                SearchFieldPreview(text: searchText)
                    .padding(.horizontal, VaporSpacing.lg)

                // Content
                ScrollView {
                    contentView
                        .padding(.top, VaporSpacing.lg)
                        .padding(.horizontal, VaporSpacing.lg)
                        .padding(.bottom, 120)
                }
            }

            // FAB
            HStack {
                Spacer()
                RecordButton(isRecording: false) {}
                Spacer()
            }
            .padding(.bottom, VaporSpacing.lg)
        }
        .background(VaporColor.mist)
    }

    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .grouped:
            groupedContent
        case .empty:
            emptyStateContent
        case .searchResults(let results):
            searchResultsContent(results: results)
        }
    }

    private var groupedContent: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.xl + VaporSpacing.sm) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: VaporSpacing.md) {
                    DateHeader(section.header)

                    VStack(spacing: VaporSpacing.sm) {
                        ForEach(section.sessions) { session in
                            SessionCard(
                                title: session.title,
                                time: session.time,
                                previewText: session.previewText,
                                speakerCount: session.speakerCount,
                                duration: session.duration,
                                showMetadata: session.showMetadata
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.lg) {
            Spacer()
                .frame(height: VaporSpacing.xl * 4)

            Text("No recordings yet")
                .vaporTextStyle(.title)
                .foregroundColor(VaporColor.textSecondary)

            Text("Tap the record button to start capturing")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func searchResultsContent(results: [SessionData]) -> some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.md) {
            if results.isEmpty {
                emptySearchResultsContent
            } else {
                DateHeader("RESULTS")

                VStack(spacing: VaporSpacing.sm) {
                    ForEach(results) { session in
                        SessionCard(
                            title: session.title,
                            time: session.time,
                            previewText: session.previewText,
                            speakerCount: session.speakerCount,
                            duration: session.duration,
                            showMetadata: session.showMetadata
                        )
                    }
                }
            }
        }
    }

    private var emptySearchResultsContent: some View {
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
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineViewPreview(
            sections: [
                .init(
                    header: "TODAY",
                    sessions: [
                        .init(
                            title: "Architecture Review",
                            time: "9:41 AM",
                            previewText: "So we're looking at the Vapor direction...",
                            speakerCount: 2,
                            duration: "42:10",
                            showMetadata: true
                        ),
                        .init(
                            title: "Morning Reflection",
                            time: "7:30 AM",
                            previewText: "The light in the studio was particularly interesting this morning..."
                        )
                    ]
                ),
                .init(
                    header: "YESTERDAY",
                    sessions: [
                        .init(
                            title: "Product Strategy",
                            time: "4:20 PM",
                            previewText: "If we pivot to a local-first model, the database sync..."
                        )
                    ]
                )
            ]
        )
    }
}
#endif
