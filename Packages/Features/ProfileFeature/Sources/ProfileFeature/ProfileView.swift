import ComposableArchitecture
import DesignSystem
import Models
import PhotosUI
import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Profile View

/// Profile settings screen matching the Profile Settings design in app.pen.
/// Shows user avatar, name, and account sections.
public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    @State private var selectedPhoto: PhotosPickerItem?

    /// Whether we're running in UI testing mode
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
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
        .onAppear {
            store.send(.onAppear)
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
            MockPhotoPickerSheet(store: store)
        }
        #if os(iOS)
        .sheet(
            isPresented: Binding(
                get: { store.shareURL != nil },
                set: { if !$0 { store.send(.shareSheetDismissed) } }
            )
        ) {
            if let shareURL = store.shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        #endif
        .accessibilityIdentifier("profileScreen")
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        HStack {
            NavButton(label: "Back") {
                store.send(.backTapped)
            }

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
            if isUITesting {
                // Mock picker button for UI tests
                Button {
                    store.send(.showMockPhotoPicker)
                } label: {
                    avatarWithBadge
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("profileChangePhotoButton")
            } else {
                // Real PhotosPicker for live mode
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatarWithBadge
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("profileChangePhotoButton")
            }

            // Helper text and remove button
            if store.profile.avatar.imageData != nil {
                Button {
                    store.send(.removePhotoTapped)
                } label: {
                    Text("Remove photo")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(VaporColor.recording)
                }
                .accessibilityIdentifier("profileRemovePhotoButton")
            } else {
                Text("Tap to change photo")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            }
        }
        .padding(.horizontal, VaporSpacing.lg)
        .padding(.bottom, VaporSpacing.lg)
    }

    private var avatarWithBadge: some View {
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
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: VaporSpacing.xl) {
            // Personal Information section
            personalSection

            // Account section
            accountSection

            // Data section
            dataSection
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
            if store.isEditingName {
                nameEditField
            } else {
                nameDisplayField
            }
        }
    }

    private var nameDisplayField: some View {
        Button {
            store.send(.editNameTapped)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Name")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(VaporColor.textTertiary)

                    Text(store.profile.name.isEmpty ? "Add your name" : store.profile.name)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(store.profile.name.isEmpty ? VaporColor.textTertiary : VaporColor.textPrimary)
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("profileNameRow")
    }

    private var nameEditField: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
            Text("Full Name")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(VaporColor.textTertiary)

            HStack(spacing: VaporSpacing.sm) {
                TextField("Enter your name", text: $store.editingNameText.sending(\.editingNameChanged))
                    .font(.system(size: 16, weight: .light))
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("profileNameTextField")

                Button {
                    store.send(.cancelEditNameTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VaporColor.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    store.send(.saveNameTapped)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VaporColor.deep)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(store.editingNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("profileNameSaveButton")
            }
            .padding(VaporSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VaporRadius.sm)
                    .fill(VaporColor.cloud)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            )

            if let error = store.error {
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

            // Email row (placeholder - not functional in MVP)
            accountRow(icon: "envelope", title: "Change Email")
                .accessibilityIdentifier("profileEmailRow")

            // Password row (placeholder - not functional in MVP)
            accountRow(icon: "lock", title: "Change Password")
                .accessibilityIdentifier("profilePasswordRow")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.sm) {
            Text("Data")
                .font(.system(size: 16, weight: .medium))
                .tracking(0.16)
                .foregroundColor(VaporColor.textPrimary)

            // Export All Conversations button
            Button {
                store.send(.exportAllTapped)
            } label: {
                HStack {
                    HStack(spacing: VaporSpacing.sm) {
                        if store.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(VaporColor.textSecondary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(VaporColor.textSecondary)
                        }

                        Text(store.isExporting ? "Exporting..." : "Export All Conversations")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(VaporColor.textPrimary)
                    }

                    Spacer()

                    if !store.isExporting {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18))
                            .foregroundColor(VaporColor.textTertiary)
                    }
                }
                .padding(VaporSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: VaporRadius.sm)
                        .fill(VaporColor.cloud)
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.isExporting)
            .accessibilityIdentifier("exportAllConversationsButton")
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
            if let imageData = store.profile.avatar.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if !store.initials.isEmpty {
                Text(store.initials)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
            }
            #else
            if !store.initials.isEmpty {
                Text(store.initials)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
            }
            #endif
        }
    }
}

// MARK: - Mock Photo Picker Sheet (for UI Testing)

/// A simple sheet with pre-defined photo options for deterministic UI testing.
/// Avoids system Photos picker which is difficult to automate in XCUITest.
struct MockPhotoPickerSheet: View {
    let store: StoreOf<ProfileFeature>

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
                    .accessibilityIdentifier("mockPhotoOption-\(index)")
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
                    .accessibilityIdentifier("mockPhotoPickerCancel")
                }
            }
        }
        .accessibilityIdentifier("mockPhotoPickerSheet")
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

// MARK: - Share Sheet (UIActivityViewController wrapper)

#if os(iOS)
/// A SwiftUI wrapper for UIActivityViewController to share files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Previews

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileViewPreview(
            name: "Brandon Kase",
            initials: "BK"
        )
    }
}
#endif
