import DesignSystem
import SwiftUI

// MARK: - Profile View Preview

/// Non-interactive preview variant of ProfileView for snapshot testing.
/// Uses static data instead of Store for deterministic snapshots.
public struct ProfileViewPreview: View {
    /// Display mode for the profile preview
    public enum DisplayMode {
        /// Default view with name and avatar
        case normal
        /// View with photo set (shows remove option)
        case withPhoto
        /// Editing name mode
        case editingName
        /// Empty state (new user)
        case empty
        /// Editing name with error message
        case editingNameWithError
    }

    private let name: String
    private let initials: String
    private let imageData: Data?
    private let displayMode: DisplayMode
    private let editingNameText: String
    private let errorMessage: String?

    public init(
        name: String,
        initials: String,
        imageData: Data? = nil,
        displayMode: DisplayMode = .normal,
        editingNameText: String = "",
        errorMessage: String? = nil
    ) {
        self.name = name
        self.initials = initials
        self.imageData = imageData
        self.displayMode = displayMode
        self.editingNameText = editingNameText
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            navHeader

            // Page header
            pageHeader

            // Profile content
            ScrollView {
                VStack(spacing: 0) {
                    // Avatar section
                    avatarSection

                    // Content sections
                    contentArea
                }
            }
        }
        .background(VaporColor.mist)
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        HStack {
            HStack(spacing: VaporSpacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)

                Text("Back")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }
            .padding(VaporSpacing.sm)

            Spacer()

            // Small avatar in header
            avatarImage(size: 32, fontSize: 12)
        }
        .padding(.top, 56)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.md)
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
            Text("SETTINGS")
                .font(.system(size: 11, weight: .light))
                .tracking(2)
                .foregroundColor(VaporColor.textTertiary)

            Text("Profile")
                .font(.system(size: 28, weight: .thin))
                .tracking(-0.5)
                .foregroundColor(VaporColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.lg)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: VaporSpacing.sm) {
            // Large avatar with camera badge
            ZStack(alignment: .bottomTrailing) {
                avatarImage(size: 80, fontSize: 28)

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

            // Helper text and remove button
            if displayMode == .withPhoto {
                Text("Remove photo")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.recording)
            } else {
                Text("Tap to change photo")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            }
        }
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.lg)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: VaporSpacing.xl) {
            // Personal Information section
            personalSection

            // Account section
            accountSection
        }
        .padding(.horizontal, VaporSpacing.lg)
    }

    // MARK: - Personal Information Section

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.sm) {
            Text("Personal Information")
                .font(.system(size: 16, weight: .medium))
                .tracking(0.16)
                .foregroundColor(VaporColor.textPrimary)

            // Name field
            if displayMode == .editingName || displayMode == .editingNameWithError {
                nameEditField
            } else {
                nameDisplayField
            }
        }
    }

    private var nameDisplayField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Name")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)

                Text(displayMode == .empty ? "Add your name" : name)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(displayMode == .empty ? VaporColor.textTertiary : VaporColor.textPrimary)
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 18))
                .foregroundColor(VaporColor.textTertiary)
        }
        .padding(VaporSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VaporRadius.sm)
                .fill(VaporColor.cloud)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }

    private var nameEditField: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
            Text("Full Name")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(VaporColor.textTertiary)

            HStack(spacing: VaporSpacing.sm) {
                Text(editingNameText)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(VaporColor.textTertiary)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(VaporColor.deep)
            }
            .padding(VaporSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VaporRadius.sm)
                    .fill(VaporColor.cloud)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.recording)
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.sm) {
            Text("Account")
                .font(.system(size: 16, weight: .medium))
                .tracking(0.16)
                .foregroundColor(VaporColor.textPrimary)

            // Email row
            accountRow(icon: "envelope", title: "Change Email")

            // Password row
            accountRow(icon: "lock", title: "Change Password")
        }
    }

    private func accountRow(icon: String, title: String) -> some View {
        HStack {
            HStack(spacing: VaporSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(VaporColor.textSecondary)

                Text(title)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18))
                .foregroundColor(VaporColor.textTertiary)
        }
        .padding(VaporSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VaporRadius.sm)
                .fill(VaporColor.cloud)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Avatar Image Helper

    @ViewBuilder
    private func avatarImage(size: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(VaporColor.sky)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(VaporColor.fog, lineWidth: size > 50 ? 2 : 1)
                )

            #if os(iOS)
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
            }
            #else
            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
            }
            #endif
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ProfileViewPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProfileViewPreview(
                name: "Brandon Kase",
                initials: "BK"
            )
            .previewDisplayName("Normal")

            ProfileViewPreview(
                name: "Brandon Kase",
                initials: "BK",
                imageData: Data([0x89, 0x50, 0x4E, 0x47]),
                displayMode: .withPhoto
            )
            .previewDisplayName("With Photo")

            ProfileViewPreview(
                name: "",
                initials: "",
                displayMode: .empty
            )
            .previewDisplayName("Empty")

            ProfileViewPreview(
                name: "Brandon Kase",
                initials: "BK",
                displayMode: .editingName,
                editingNameText: "Brandon K"
            )
            .previewDisplayName("Editing Name")

            ProfileViewPreview(
                name: "Brandon Kase",
                initials: "BK",
                displayMode: .editingNameWithError,
                editingNameText: "",
                errorMessage: "Name cannot be empty"
            )
            .previewDisplayName("Editing Name Error")
        }
    }
}
#endif
