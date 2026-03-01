import SwiftUI

struct PersonaSelectorSheet: View {

    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(PersonaType.allCases, id: \.self) { mode in
                    Button {
                        Task { await vm.updatePersona(mode) }
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(mode.color)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.label)
                                    .foregroundStyle(Color.primary)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if vm.persona == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.mcTextLink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
