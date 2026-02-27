import SwiftUI

struct ConfirmDeleteAlert: View {

    let onConfirm: (Bool) -> Void
    @State private var confirmText = ""

    private let requiredPhrase = "delete my data"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentRed)

                Text("Delete all your data?")
                    .font(.title2.bold())

                Text("This will permanently erase all your conversations, messages, topics, and saved memories. Your account will remain active but completely empty. This action cannot be undone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Text("Type \"\(requiredPhrase)\" to confirm:")
                        .font(.subheadline.bold())

                    TextField(requiredPhrase, text: $confirmText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }

                Button("Delete Everything", role: .destructive) {
                    onConfirm(true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(confirmText != requiredPhrase)

                Button("Cancel") {
                    onConfirm(false)
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
