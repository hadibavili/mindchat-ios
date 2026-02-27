import SwiftUI

struct TopicTreeView: View {

    @StateObject private var vm = TopicsViewModel()
    @Binding var selectedTopicId: String?
    @State private var searchText = ""

    var filteredNodes: [TopicTreeNode] {
        guard !searchText.isEmpty else { return vm.rootTopics }
        return vm.rootTopics.compactMap { filterNode($0, query: searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search topics…", text: $searchText)
            }
            .padding(10)
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

            if vm.isLoading {
                ProgressView().padding()
            } else if filteredNodes.isEmpty {
                Text(vm.rootTopics.isEmpty ? "Topics appear here as you chat" : "No topics found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(filteredNodes, children: \.nonEmptyChildren) { node in
                    TopicNodeView(node: node, isSelected: selectedTopicId == node.id) {
                        selectedTopicId = node.id
                    }
                }
                .listStyle(.plain)
            }
        }
        .task { await vm.load() }
    }

    private func filterNode(_ node: TopicTreeNode, query: String) -> TopicTreeNode? {
        let nameMatch = node.name.localizedCaseInsensitiveContains(query)
        let filteredChildren = node.children.compactMap { filterNode($0, query: query) }
        guard nameMatch || !filteredChildren.isEmpty else { return nil }
        return TopicTreeNode(
            id: node.id, name: node.name, path: node.path,
            summary: node.summary, icon: node.icon,
            slug: node.slug, depth: node.depth,
            createdAt: node.createdAt, updatedAt: node.updatedAt,
            children: filteredChildren, factCount: node.factCount
        )
    }
}

extension TopicTreeNode {
    var nonEmptyChildren: [TopicTreeNode]? {
        children.isEmpty ? nil : children
    }
}

struct TopicNodeView: View {

    let node: TopicTreeNode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                TopicIconView(iconName: node.icon ?? node.name, size: 22)
                Text(node.name).font(.subheadline)
                Spacer()
                if node.totalFactCount > 0 {
                    Text("\(node.totalFactCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
