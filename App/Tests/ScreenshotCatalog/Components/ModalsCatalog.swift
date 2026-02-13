import Testing
import SnapshotTesting
import SwiftUI
@testable import DesignSystem

// MARK: - Modals Catalog

extension CatalogBase {
    @Suite("Modal Components")
    @MainActor
    struct ModalsCatalog {

        @Test func testSessionActionsModal() {
            let view = VStack(alignment: .trailing) {
                SessionActionsModalPreview()
                    .frame(width: 260)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "session_actions_modal",
                                   section: "Components", description: "Session actions menu (Continue Recording, Export, Delete).")
        }

        @Test func testDeleteConfirmation() {
            let view = VStack(spacing: 0) {
                Text("Delete Recording")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VaporColor.textPrimary)
                    .padding(.top, 20).padding(.bottom, 8)
                Text("This will permanently delete this recording and its transcript. This action cannot be undone.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(VaporColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.bottom, 20)
                Divider().background(VaporColor.fog)
                Text("Delete")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VaporColor.recording)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                Divider().background(VaporColor.fog)
                Text("Cancel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(VaporColor.sky)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .frame(width: 270)
            .background(RoundedRectangle(cornerRadius: 14).fill(VaporColor.cloud))
            .padding(60)
            .background(VaporColor.mist)

            CatalogHarness.capture(of: view, named: "delete_confirmation",
                                   section: "Components", description: "Delete confirmation dialog with destructive action.")
        }
    }
}
