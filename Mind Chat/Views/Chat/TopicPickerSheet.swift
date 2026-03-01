import SwiftUI

struct TopicPickerSheet: View {

    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var topics: [TopicTreeNode] = []

    private var filtered: [TopicTreeNode] {
        if searchText.isEmpty { return topics }
        let q = searchText.lowercased()
        return topics.filter {
            $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { node in
                Button {
                    vm.topicFocus = TopicFocus(
                        id: node.id,
                        name: node.name,
                        factCount: node.totalFactCount
                    )
                    Haptics.light()
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        TopicIconView(iconName: node.icon ?? node.name, size: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.mcTextPrimary)

                            if node.path.contains("/") {
                                Text(node.path)
                                    .font(.caption2)
                                    .foregroundStyle(Color.mcTextTertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text("\(node.totalFactCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.mcTextTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("Focus on Topic")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search topics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if vm.topicFocus != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") {
                            vm.clearTopicFocus()
                            dismiss()
                        }
                        .foregroundStyle(Color.accentRed)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            // Load from cache first
            if let cached: [TopicTreeNode] = CacheStore.shared.get(.topicsTree) {
                topics = TopicTreeNode.flattenAll(cached)
            }
            // Refresh from network
            do {
                let fresh = try await TopicService.shared.topicsTree()
                topics = TopicTreeNode.flattenAll(fresh)
            } catch {
                // Keep cached data if network fails
            }
        }
    }
}
