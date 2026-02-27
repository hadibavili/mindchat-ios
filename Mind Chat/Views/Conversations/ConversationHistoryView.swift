import SwiftUI

// MARK: - Conversation History View

struct ConversationHistoryView: View {

    @ObservedObject var conversationsVM: ConversationsViewModel
    let onSelect: (Conversation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText            = ""
    @State private var renamingConversation: Conversation?
    @State private var renameText            = ""

    // MARK: - Filtered & Grouped

    private var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else { return conversationsVM.conversations }
        return conversationsVM.conversations.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedConversations: [ConversationDateGroup] {
        let calendar = Calendar.current
        let now = Date()
        let order = ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "Older"]
        var buckets: [String: [Conversation]] = [:]

        for conv in filteredConversations {
            let days = calendar.dateComponents([.day], from: conv.updatedAt, to: now).day ?? 0
            let key: String
            switch days {
            case 0:      key = "Today"
            case 1:      key = "Yesterday"
            case 2...7:  key = "Previous 7 Days"
            case 8...30: key = "Previous 30 Days"
            default:     key = "Older"
            }
            buckets[key, default: []].append(conv)
        }

        return order.compactMap { label in
            guard let convs = buckets[label], !convs.isEmpty else { return nil }
            return ConversationDateGroup(label: label, conversations: convs)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search conversations", text: $searchText)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.mcBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Content
                if conversationsVM.isLoading && conversationsVM.conversations.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredConversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .background(Color.mcBgPrimary)
            .navigationTitle("Conversation History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename", isPresented: Binding(
                get: { renamingConversation != nil },
                set: { if !$0 { renamingConversation = nil } }
            )) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let conv = renamingConversation {
                        Task { await conversationsVM.rename(conversation: conv, title: renameText) }
                    }
                    renamingConversation = nil
                }
                Button("Cancel", role: .cancel) { renamingConversation = nil }
            }
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            if searchText.isEmpty {
                ForEach(groupedConversations, id: \.label) { group in
                    Section(header:
                        Text(group.label)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    ) {
                        ForEach(group.conversations) { conv in
                            conversationRow(conv)
                        }
                    }
                }
            } else {
                ForEach(filteredConversations) { conv in
                    conversationRow(conv)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await conversationsVM.refresh() }
    }

    @ViewBuilder
    private func conversationRow(_ conv: Conversation) -> some View {
        Button {
            onSelect(conv)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(conv.title ?? "New Chat")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcTextPrimary)
                    .lineLimit(1)
                Text(conv.updatedAt.relativeDisplay)
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextTertiary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await conversationsVM.delete(conversation: conv) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                renamingConversation = conv
                renameText = conv.title ?? ""
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                renamingConversation = conv
                renameText = conv.title ?? ""
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { await conversationsVM.delete(conversation: conv) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.mcTextTertiary)
            if conversationsVM.conversations.isEmpty {
                Text("No conversations yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mcTextSecondary)
                Text("Start chatting to see your history here")
                    .font(.caption)
                    .foregroundStyle(Color.mcTextTertiary)
            } else {
                Text("No results")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mcTextSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Types

struct ConversationDateGroup {
    let label: String
    let conversations: [Conversation]
}
