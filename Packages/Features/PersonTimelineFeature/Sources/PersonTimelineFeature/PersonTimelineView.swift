import ComposableArchitecture
import DesignSystem
import Models
import Persistence
import SwiftUI
import TimelineFeature

#if os(iOS)
import UIKit
#endif

// MARK: - Person Timeline View

/// Shows a filtered timeline of sessions for a specific person.
public struct PersonTimelineView: View {
    @Bindable var store: StoreOf<PersonTimelineFeature>

    public init(store: StoreOf<PersonTimelineFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with back button and person's name
            headerSection

            // Sessions content
            ScrollView {
                sessionsContent
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
        VStack(alignment: .leading, spacing: VaporSpacing.md) {
            // Top nav row: Back button on left, avatar on right
            navHeader

            // Page title row: "Conversations with [Person Name]"
            pageHeader
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
    }

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back") {
                store.send(.backTapped)
            }

            Spacer()

            Button {
                store.send(.avatarTapped)
            } label: {
                avatarView
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("profileAvatarButton")
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
            Text("CONVERSATIONS WITH")
                .font(.system(size: 11, weight: .light))
                .tracking(2)
                .foregroundColor(VaporColor.textTertiary)

            Text(store.personName)
                .font(.system(size: 28, weight: .thin))
                .tracking(-0.5)
                .foregroundColor(VaporColor.textPrimary)
                .accessibilityIdentifier("personTimelineName")
        }
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

    // MARK: - Sessions Content

    @ViewBuilder
    private var sessionsContent: some View {
        if store.isLoading {
            loadingContent
        } else if store.sessions.isEmpty {
            emptyStateContent
        } else {
            sessionsListContent
        }
    }

    private var loadingContent: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }

    private var sessionsListContent: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.md) {
            // Header showing count
            DateHeader(sessionCountHeader)

            VStack(spacing: VaporSpacing.sm) {
                ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, session in
                    sessionCard(for: session)
                        .vaporAppear(index: index)
                        .onTapGesture {
                            store.send(.sessionTapped(SessionID(rawValue: session.id)))
                        }
                }
            }
        }
    }

    private var sessionCountHeader: String {
        let count = store.sessions.count
        if count == 1 {
            return "1 CONVERSATION"
        } else {
            return "\(count) CONVERSATIONS"
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.md) {
            Text("No conversations yet")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textSecondary)

            Text("Sessions with \(store.personName) will appear here")
                .vaporTextStyle(.caption)
                .foregroundColor(VaporColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }

    private func sessionCard(for session: SessionRecord) -> some View {
        let viewModel = SessionCardViewModel.from(session: session)
        return SessionCard(
            title: viewModel.title,
            time: viewModel.time,
            previewText: viewModel.previewText,
            speakerCount: viewModel.speakerCount,
            duration: viewModel.duration,
            statusPillType: viewModel.statusPillType
        )
    }
}

// MARK: - Person Timeline View Preview (for snapshots)

/// Non-interactive preview variant for snapshot testing.
public struct PersonTimelineViewPreview: View {
    public struct SessionData: Identifiable {
        public let id: String
        public let title: String
        public let time: String
        public let previewText: String
        public let speakerCount: Int?
        public let duration: String?
        public let statusPillType: StatusPillType?

        public init(
            id: String = UUID().uuidString,
            title: String,
            time: String,
            previewText: String,
            speakerCount: Int? = nil,
            duration: String? = nil,
            statusPillType: StatusPillType? = nil
        ) {
            self.id = id
            self.title = title
            self.time = time
            self.previewText = previewText
            self.speakerCount = speakerCount
            self.duration = duration
            self.statusPillType = statusPillType
        }
    }

    public enum DisplayMode {
        case list
        case empty
    }

    private let personName: String
    private let sessions: [SessionData]
    private let displayMode: DisplayMode

    public init(personName: String, sessions: [SessionData]) {
        self.personName = personName
        self.sessions = sessions
        self.displayMode = .list
    }

    public init(personName: String, displayMode: DisplayMode) {
        self.personName = personName
        self.displayMode = displayMode
        self.sessions = []
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: VaporSpacing.md) {
                // Top nav row: Back button on left, avatar on right
                HStack {
                    NavButton(label: "Back") {}

                    Spacer()

                    Avatar(size: .medium)
                }

                // Page title row: "Conversations with [Person Name]"
                VStack(alignment: .leading, spacing: VaporSpacing.xs) {
                    Text("CONVERSATIONS WITH")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(VaporColor.textTertiary)

                    Text(personName)
                        .font(.system(size: 28, weight: .thin))
                        .tracking(-0.5)
                        .foregroundColor(VaporColor.textPrimary)
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, VaporSpacing.lg)
            .padding(.bottom, VaporSpacing.md)

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
            sessionsListContent
        case .empty:
            emptyStateContent
        }
    }

    private var sessionsListContent: some View {
        LazyVStack(alignment: .leading, spacing: VaporSpacing.md) {
            DateHeader(sessionCountHeader)

            VStack(spacing: VaporSpacing.sm) {
                ForEach(sessions) { session in
                    SessionCard(
                        title: session.title,
                        time: session.time,
                        previewText: session.previewText,
                        speakerCount: session.speakerCount,
                        duration: session.duration,
                        statusPillType: session.statusPillType
                    )
                }
            }
        }
    }

    private var sessionCountHeader: String {
        let count = sessions.count
        if count == 1 {
            return "1 CONVERSATION"
        } else {
            return "\(count) CONVERSATIONS"
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: VaporSpacing.md) {
            Text("No conversations yet")
                .vaporTextStyle(.body)
                .foregroundColor(VaporColor.textSecondary)

            Text("Sessions with \(personName) will appear here")
                .vaporTextStyle(.caption)
                .foregroundColor(VaporColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VaporSpacing.xl)
    }
}

// MARK: - Previews

#if DEBUG
struct PersonTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        PersonTimelineViewPreview(
            personName: "Sarah Chen",
            sessions: [
                .init(
                    title: "Product Strategy",
                    time: "2:30 PM",
                    previewText: "We discussed the Q4 roadmap priorities...",
                    speakerCount: 2,
                    duration: "45:12"
                ),
                .init(
                    title: "Morning Standup",
                    time: "9:00 AM",
                    previewText: "Quick sync on sprint progress..."
                )
            ]
        )
    }
}
#endif
