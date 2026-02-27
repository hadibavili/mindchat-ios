import SwiftUI

// MARK: - Sidebar / Drawer View

struct SidebarView: View {

    @ObservedObject var conversationsVM: ConversationsViewModel
    @ObservedObject var chatVM: ChatViewModel
    @Binding var showSidebar: Bool
    @Binding var showKnowledge: Bool
    @Binding var showSettings: Bool
    @Binding var showConversationHistory: Bool
    @Binding var showTopic: TopicNavTarget?
    @EnvironmentObject private var appState: AppState

    @StateObject private var topicsVm = TopicsViewModel()
    @State private var topicSearchText = ""

    // MARK: - Filtered Topics

    private var filteredTopics: [TopicTreeNode] {
        guard !topicSearchText.isEmpty else { return topicsVm.rootTopics }
        return topicsVm.rootTopics.compactMap { filterNode($0, query: topicSearchText) }
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // User Profile
            userProfileSection

            Divider()

            // Memory / Topic Tree (scrollable primary content)
            ScrollView {
                VStack(spacing: 0) {
                    memoryHeaderRow
                    topicSearchBar
                    topicContent
                }
            }

            Divider()

            // Quick Actions
            quickActionsSection

            Divider()

            // Stats Footer
            statsFooter
        }
        .background(Color.mcBgSidebar)
        .task { await topicsVm.load() }
        .onReceive(EventBus.shared.events) { event in
            if case .topicsUpdated = event {
                Task { await topicsVm.refresh() }
            }
        }
    }

    // MARK: - User Profile

    private var userProfileSection: some View {
        HStack(spacing: 12) {
            // Avatar (initials circle)
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Name + email
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentUser?.name ?? "User")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mcTextPrimary)
                    .lineLimit(1)
                Text(appState.currentUser?.email ?? "")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Plan badge
            planBadge
        }
        .padding(.horizontal, 18)
        .padding(.top, 60)
        .padding(.bottom, 14)
    }

    private var initials: String {
        let name = appState.currentUser?.name ?? appState.currentUser?.email ?? "U"
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    @ViewBuilder
    private var planBadge: some View {
        let (label, color) = planBadgeInfo
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var planBadgeInfo: (String, Color) {
        switch chatVM.plan {
        case .free:    return ("FREE",    Color.mcTextTertiary)
        case .trial:   return ("TRIAL",   Color.mcTextLink)
        case .pro:     return ("PRO",     Color.mcTextLink)
        case .premium: return ("PREMIUM", Color.accentPurple)
        }
    }

    // MARK: - Memory Section

    private var memoryHeaderRow: some View {
        HStack {
            Text("MEMORY")
                .font(.caption.bold())
                .foregroundStyle(Color.mcTextTertiary)
            Spacer()
            Button("See all") {
                showKnowledge = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }
            .font(.caption)
            .foregroundStyle(Color.mcTextLink)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var topicSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(Color.mcTextTertiary)
            TextField("Search topics…", text: $topicSearchText)
                .font(.subheadline)
            if !topicSearchText.isEmpty {
                Button { topicSearchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var topicContent: some View {
        if topicsVm.isLoading && topicsVm.rootTopics.isEmpty {
            ProgressView()
                .padding(.vertical, 24)
        } else if filteredTopics.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.title3)
                    .foregroundStyle(Color.mcTextTertiary)
                Text(topicsVm.rootTopics.isEmpty
                     ? "Topics appear here as you chat"
                     : "No matching topics")
                    .font(.subheadline)
                    .foregroundStyle(Color.mcTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 18)
        } else {
            ForEach(filteredTopics) { node in
                DrawerTopicNode(node: node, depth: 0) { selected in
                    showTopic = TopicNavTarget(id: selected.id, title: selected.name)
                    withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            drawerNavButton(icon: "clock", label: "Conversation History") {
                showConversationHistory = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }
            drawerNavButton(icon: "gearshape", label: "Settings") {
                showSettings = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }
            drawerNavButton(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out") {
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.signOut()
                }
            }
        }
    }

    private func drawerNavButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 22)
                    .foregroundStyle(Color.mcTextSecondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.mcTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mcTextTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Stats Footer

    @ViewBuilder
    private var statsFooter: some View {
        let topics = topicsVm.totalTopics
        let facts  = topicsVm.totalFacts
        if topics > 0 || facts > 0 {
            Text("\(topics) topic\(topics == 1 ? "" : "s") · \(facts) \(facts == 1 ? "memory" : "memories")")
                .font(.caption2)
                .foregroundStyle(Color.mcTextTertiary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        }
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
            HStack(spacing: 0) {
                // Depth indentation
                Color.clear.frame(width: CGFloat(16 + depth * 18), height: 1)

                // Expand / collapse button (only if children exist)
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.mcTextTertiary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 18, height: 1)
                }

                // Topic row button
                Button { onSelect(node) } label: {
                    HStack(spacing: 8) {
                        TopicIconView(iconName: node.icon ?? node.name, size: 20)
                        Text(node.name)
                            .font(.subheadline)
                            .foregroundStyle(Color.mcTextSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if node.totalFactCount > 0 {
                            Text("\(node.totalFactCount)")
                                .font(.caption2)
                                .foregroundStyle(Color.mcTextTertiary)
                                .padding(.trailing, 14)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }

            // Children (when expanded)
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
