import SwiftUI

struct MergeTopicSheet: View {

    @ObservedObject var vm: TopicDetailViewModel
    @StateObject private var topicsVm = TopicsViewModel()
    @State private var searchText       = ""
    @State private var selectedTargetId: String?
    @State private var isMerging          = false
    @State private var errorMessage: String?
    @State private var showConfirmation   = false
    @Environment(\.dismiss) private var dismiss

    private var selectedTargetName: String? {
        guard let id = selectedTargetId else { return nil }
        return flatTopics.first(where: { $0.id == id })?.name
    }

    var flatTopics: [TopicTreeNode] {
        topicsVm.rootTopics.flatMap { flattenTree($0) }
    }

    var filteredTopics: [TopicTreeNode] {
        guard !searchText.isEmpty else { return flatTopics }
        return flatTopics.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search topics…", text: $searchText)
                }
                .padding(10)
                .background(Color.mcBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()

                List(filteredTopics) { topic in
                    Button {
                        selectedTargetId = topic.id
                    } label: {
                        HStack {
                            TopicIconView(iconName: topic.icon ?? topic.name, size: 24)
                            VStack(alignment: .leading) {
                                Text(topic.name).font(.subheadline)
                                Text(topic.path).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedTargetId == topic.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let err = errorMessage {
                    Text(err).foregroundStyle(Color.accentRed).padding()
                }
            }
            .navigationTitle("Move to Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        showConfirmation = true
                    }
                    .disabled(selectedTargetId == nil || isMerging)
                }
            }
            .task { await topicsVm.load() }
            .alert("Merge Topic?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Merge", role: .destructive) {
                    Task { await performMerge() }
                }
            } message: {
                let source = vm.detail?.topic.name ?? "this topic"
                let target = selectedTargetName ?? "the selected topic"
                Text("All facts and subtopics from \"\(source)\" will be moved into \"\(target)\". This cannot be undone.")
            }
        }
    }

    private func performMerge() async {
        guard let targetId = selectedTargetId else { return }
        isMerging = true
        do {
            try await vm.merge(into: targetId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isMerging = false
    }

    private func flattenTree(_ node: TopicTreeNode) -> [TopicTreeNode] {
        [node] + node.children.flatMap { flattenTree($0) }
    }
}
