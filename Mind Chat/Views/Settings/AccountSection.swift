import SwiftUI

struct AccountSection: View {

    @ObservedObject var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var isExporting       = false
    @State private var exportData: Data?
    @State private var showShareSheet    = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Account") {
            if let user = appState.currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading) {
                        if let name = user.name, !name.isEmpty {
                            Text(name).fontWeight(.medium)
                        }
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
        .sheet(isPresented: $showShareSheet) {
            if let data = exportData {
                ActivitySheet(data: data)
            }
        }
    }

    private func exportUserData() async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportData    = try await AccountService.shared.exportData()
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteData() async {
        do {
            try await AccountService.shared.deleteAllData()
            // Navigate to clean chat state — account remains active
            appState.selectedConversationId = nil
            appState.selectedTab = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Activity Sheet

struct ActivitySheet: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "mindchat-export-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
