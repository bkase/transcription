import SwiftUI

// MARK: - Session Actions Modal

/// Modal for session actions (Share, Export, Delete).
/// Uses the same design pattern as SpeakerPickerModal - positioned near trigger with fade overlay.
public struct SessionActionsModal: View {
    private let onShare: () -> Void
    private let onExport: () -> Void
    private let onDelete: () -> Void
    private let onDismiss: () -> Void

    public init(
        onShare: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onShare = onShare
        self.onExport = onExport
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Actions")
                    .font(.system(size: 16))
                    .foregroundColor(VaporColor.textPrimary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(VaporColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("actionsModalClose")
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .overlay(
                Rectangle()
                    .fill(VaporColor.fog)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Action buttons
            VStack(spacing: 0) {
                SessionActionRow(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    action: onShare
                )
                .accessibilityIdentifier("shareAction")

                SessionActionRow(
                    icon: "arrow.down.doc",
                    label: "Export",
                    action: onExport
                )
                .accessibilityIdentifier("exportAction")

                Rectangle()
                    .fill(VaporColor.fog)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                SessionActionRow(
                    icon: "trash",
                    label: "Delete",
                    isDestructive: true,
                    action: onDelete
                )
                .accessibilityIdentifier("deleteAction")
            }
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(VaporColor.cloud)
                .shadow(
                    color: Color.black.opacity(0.12),
                    radius: 32,
                    y: 8
                )
        )
    }
}

// MARK: - Session Action Row

/// A single action row in the session actions modal.
private struct SessionActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? VaporColor.recording : VaporColor.textSecondary)

                Text(label)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(isDestructive ? VaporColor.recording : VaporColor.textPrimary)

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Actions Modal Preview

/// Preview variant for snapshot testing.
public struct SessionActionsModalPreview: View {
    public init() {}

    public var body: some View {
        SessionActionsModal(
            onShare: {},
            onExport: {},
            onDelete: {},
            onDismiss: {}
        )
    }
}

// MARK: - Previews

#if DEBUG
struct SessionActionsModal_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack {
                    Spacer()
                    SessionActionsModalPreview()
                        .frame(width: 280)
                        .padding(.trailing, 24)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
#endif
