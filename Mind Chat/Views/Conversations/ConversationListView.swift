import SwiftUI

// MARK: - Sidebar / Drawer View

struct SidebarView: View {

    @ObservedObject var conversationsVM: ConversationsViewModel
    @ObservedObject var topicsVm: TopicsViewModel
    @ObservedObject var chatVM: ChatViewModel
    @Binding var showSidebar: Bool
    @Binding var showKnowledge: Bool
    @Binding var showSettings: Bool
    @Binding var showConversationHistory: Bool
    @Binding var showTopic: TopicNavTarget?
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var memoryExpanded = true
    @State private var renamingConversation: Conversation?
    @State private var renameText = ""

    private let maxRecentConversations = 10
    private let maxRecentTopics = 20

    // MARK: - Filtering

    private var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else { return conversationsVM.conversations }
        return conversationsVM.conversations.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var recentConversations: [Conversation] {
        let unpinned = filteredConversations.filter { !conversationsVM.isPinned($0) }
        return Array(unpinned.prefix(maxRecentConversations))
    }

    private var groupedConversations: [ConversationDateGroup] {
        let calendar = Calendar.current
        let now = Date()
        let order = ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "Older"]
        var buckets: [String: [Conversation]] = [:]

        for conv in recentConversations {
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

    private var filteredTopics: [TopicTreeNode] {
        guard !searchText.isEmpty else { return topicsVm.rootTopics }
        return topicsVm.rootTopics.compactMap { filterNode($0, query: searchText) }
    }

    private var recentTopics: [TopicTreeNode] {
        Array(filteredTopics.prefix(maxRecentTopics))
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

    private func dismiss(then action: (() -> Void)? = nil) {
        withAnimation(.mcSmooth) { showSidebar = false }
        if let action {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { action() }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar

            searchBar
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    memorySection
                    conversationsSection
                }
                .padding(.bottom, 12)
            }

            Divider()

            // Upgrade row for free users
            if chatVM.plan == .free {
                upgradeRow
                Divider()
            }

            userRow
        }
        .background(Color.mcBgSidebar)
        .onReceive(EventBus.shared.events) { event in
            if case .topicsUpdated = event {
                Task { await topicsVm.refresh() }
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

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("Mind Chat")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.mcTextPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.mcTextTertiary)
            TextField("Search", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(Color.mcTextPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mcTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Recent Conversations Section

    @ViewBuilder
    private var conversationsSection: some View {
        let _ = print("[SidebarView] conversationsSection render — total: \(conversationsVM.conversations.count), filtered: \(filteredConversations.count), pinned: \(conversationsVM.pinnedConversations.count), isLoading: \(conversationsVM.isLoading), grouped: \(groupedConversations.map { "\($0.label):\($0.conversations.count)" })")
        if conversationsVM.isLoading && conversationsVM.conversations.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if !filteredConversations.isEmpty || !conversationsVM.pinnedConversations.isEmpty {
            let pinnedToShow = searchText.isEmpty
                ? conversationsVM.pinnedConversations
                : conversationsVM.pinnedConversations.filter {
                    ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
                }

            if !pinnedToShow.isEmpty {
                HStack {
                    Text("Pinned")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.mcTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

                ForEach(pinnedToShow) { conv in
                    sidebarConversationRow(conv, isPinned: true)
                        .id(conv.id + "-pinned")
                }
            }

            ForEach(groupedConversations, id: \.label) { group in
                // Section header
                HStack {
                    Text(group.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.mcTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

                ForEach(group.conversations) { conv in
                    sidebarConversationRow(conv, isPinned: false)
                        .id(conv.id + "-unpinned")
                }
            }

            // "See all" when more conversations exist
            if filteredConversations.count > maxRecentConversations {
                Button {
                    dismiss { showConversationHistory = true }
                } label: {
                    HStack {
                        Spacer()
                        Text("See all")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.mcTextLink)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if !searchText.isEmpty && filteredConversations.isEmpty && filteredTopics.isEmpty {
            Text("No results")
                .font(.system(size: 14))
                .foregroundStyle(Color.mcTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    private func sidebarConversationRow(_ conv: Conversation, isPinned: Bool) -> some View {
        Button {
            dismiss()
            chatVM.newChat()
            Task { await chatVM.loadMessages(conversationId: conv.id) }
        } label: {
            HStack(spacing: 6) {
                Text(conv.title ?? "New Chat")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextPrimary)
                    .lineLimit(1)
                Spacer()
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
        .contextMenu {
            Button {
                conversationsVM.togglePin(conv)
            } label: {
                Label(isPinned ? "Unpin" : "Pin",
                      systemImage: isPinned ? "pin.slash" : "pin")
            }
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

    // MARK: - Memory Section (Collapsible)

    @ViewBuilder
    private var memorySection: some View {
        // Collapsible header
        Button {
            withAnimation(.mcSnappy) { memoryExpanded.toggle() }
        } label: {
            HStack {
                Text("Memory")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mcTextTertiary)
                Image(systemName: memoryExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mcTextTertiary)
                Spacer()
                if memoryExpanded && filteredTopics.count > maxRecentTopics {
                    Button {
                        dismiss { showKnowledge = true }
                    } label: {
                        Text("See all")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.mcTextLink)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if memoryExpanded {
            if topicsVm.isLoading && topicsVm.rootTopics.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if filteredTopics.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "brain")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mcTextTertiary)
                        .frame(width: 22)
                    Text("Topics appear as you chat")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mcTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                ForEach(recentTopics) { node in
                    DrawerTopicNode(node: node, depth: 0) { selected in
                        showTopic = TopicNavTarget(id: selected.id, title: selected.name)
                        dismiss()
                    }
                }

                if filteredTopics.count > maxRecentTopics {
                    Button {
                        dismiss { showKnowledge = true }
                    } label: {
                        HStack {
                            Spacer()
                            Text("See all")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.mcTextLink)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Upgrade Row

    private var upgradeRow: some View {
        Button {
            dismiss()
            // TODO: navigate to subscription
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextLink)
                    .frame(width: 22)
                Text("Upgrade plan")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mcTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
    }

    // MARK: - User Row

    private var userRow: some View {
        Button {
            dismiss { showSettings = true }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.mcTextPrimary.gradient)
                        .frame(width: 34, height: 34)
                    Text(initials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.currentUser?.name ?? "User")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.mcTextPrimary)
                        .lineLimit(1)
                    Text(planLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mcTextTertiary)
                }
                Spacer()
                Menu {
                    Button {
                        dismiss { showSettings = true }
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Divider()
                    Button(role: .destructive) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appState.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.mcTextSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
    }

    private var initials: String {
        let name = appState.currentUser?.name ?? appState.currentUser?.email ?? "U"
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    private var planLabel: String {
        switch chatVM.plan {
        case .free:    return "Free plan"
        case .trial:   return "Trial"
        case .pro:     return "Pro"
        case .premium: return "Premium"
        }
    }
}

// MARK: - Sidebar Row Button Style

private struct SidebarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.mcBgHover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Drawer Topic Node (recursive)

struct DrawerTopicNode: View {

    let node: TopicTreeNode
    let depth: Int
    let onSelect: (TopicTreeNode) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button { onSelect(node) } label: {
                HStack(spacing: 0) {
                    Color.clear.frame(width: CGFloat(16 + depth * 16), height: 1)

                    if !node.children.isEmpty {
                        Button {
                            withAnimation(.mcSnappy) { isExpanded.toggle() }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.mcTextTertiary)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        TopicIconView(iconName: node.icon ?? node.name, size: 16)
                            .frame(width: 20)
                            .foregroundStyle(Color.mcTextTertiary)
                    }

                    Text(node.name)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mcTextPrimary)
                        .lineLimit(1)
                        .padding(.leading, 8)

                    Spacer(minLength: 4)

                    if node.totalFactCount > 0 {
                        Text("\(node.totalFactCount)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.mcTextTertiary)
                            .monospacedDigit()
                            .padding(.trailing, 16)
                    }
                }
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(SidebarRowButtonStyle())
            .padding(.horizontal, 8)

            if isExpanded {
                ForEach(node.children) { child in
                    DrawerTopicNode(node: child, depth: depth + 1, onSelect: onSelect)
                }
            }
        }
    }
}

// MARK: - Sidebar Nav Button (kept for backward compat)

struct SidebarNavButton: View {

    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 22)
                Text(label)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
