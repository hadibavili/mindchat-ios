import SwiftUI
import UIKit

struct AccountSection: View {

    @ObservedObject var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var isExporting       = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Account") {
            let displayName = appState.currentUser?.name ?? (appState.persistedUserName.isEmpty ? nil : appState.persistedUserName)
            let displayEmail = appState.currentUser?.email ?? appState.persistedUserEmail

            if !displayEmail.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName ?? displayEmail)
                            .fontWeight(.semibold)
                        if displayName != nil {
                            Text(displayEmail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                Task { await exportUserData() }
            } label: {
                HStack {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if isExporting { ProgressView().scaleEffect(0.7) }
                }
            }
            .disabled(isExporting)

            Button(role: .destructive) {
                appState.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.accentRed)
            }
        }

        Section(header: Text("Danger Zone").foregroundStyle(Color.accentRed)) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Delete All Data", systemImage: "trash")
                    Text("Permanently delete all your data. This cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Delete Account — not yet implemented on backend
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.secondary)
                    Text("Permanently delete your account and all associated data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Coming soon")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .opacity(0.5)
        }
        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmDeleteAlert { confirmed in
                if confirmed {
                    Task { await deleteData() }
                }
                showDeleteConfirm = false
            }
        }
    }

    // MARK: - Export

    private func exportUserData() async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }
        do {
            let data = try await AccountService.shared.exportData()

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "mindchat-export-\(formatter.string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url)

            presentShareSheet(for: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentShareSheet(for url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Required on iPad to avoid crash
        avc.popoverPresentationController?.sourceView = root.view
        avc.popoverPresentationController?.sourceRect = CGRect(
            x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
        )
        avc.popoverPresentationController?.permittedArrowDirections = []

        // Find the topmost presented view controller so the share sheet
        // sits above the settings sheet, not below it.
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(avc, animated: true)
    }

    // MARK: - Delete

    private func deleteData() async {
        do {
            try await AccountService.shared.deleteAllData()
            appState.selectedConversationId = nil
            appState.selectedTab = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
