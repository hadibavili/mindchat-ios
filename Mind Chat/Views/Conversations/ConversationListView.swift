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

            // Memory / Topic Tree (scrollable)
            ScrollView {
                VStack(spacing: 0) {
                    memoryHeaderRow
                    topicSearchBar
                    topicContent
                }
                .padding(.bottom, 8)
            }

            // Bottom section
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 16)
                quickActionsSection
                statsFooter
            }
        }
        .background(Color.mcBgSidebar)
        .onReceive(EventBus.shared.events) { event in
            if case .topicsUpdated = event {
                Task { await topicsVm.refresh() }
            }
        }
    }

    // MARK: - User Profile

    private var userProfileSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {

                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Name + email
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.currentUser?.name ?? "User")
                        .font(.headline)
                        .foregroundStyle(Color.mcTextPrimary)
                        .lineLimit(1)
                    Text(appState.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                planBadge
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)
            .padding(.bottom, 18)

            Divider()
                .padding(.horizontal, 16)
        }
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
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .tracking(0.4)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mcTextTertiary)
                .tracking(0.6)
            Spacer()
            Button("See all") {
                showKnowledge = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }
            .font(.subheadline)
            .foregroundStyle(Color.mcTextLink)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var topicSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Color.mcTextTertiary)
            TextField("Search topics…", text: $topicSearchText)
                .font(.subheadline)
                .foregroundStyle(Color.mcTextPrimary)
            if !topicSearchText.isEmpty {
                Button { topicSearchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mcTextTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.mcBorderDefault, lineWidth: 0.5)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var topicContent: some View {
        if topicsVm.isLoading && topicsVm.rootTopics.isEmpty {
            ProgressView()
                .padding(.vertical, 32)
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
            .padding(.vertical, 32)
            .padding(.horizontal, 18)
        } else {
            ForEach(filteredTopics) { node in
                DrawerTopicNode(node: node, depth: 0) { selected in
                    showTopic = TopicNavTarget(id: selected.id, title: selected.name)
                    withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            actionRow(
                icon: "clock.arrow.circlepath",
                iconColor: Color.mcTextLink,
                label: "History"
            ) {
                showConversationHistory = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }

            Divider().padding(.leading, 54)

            actionRow(
                icon: "gearshape",
                iconColor: Color.mcTextSecondary,
                label: "Settings"
            ) {
                showSettings = true
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
            }

            Divider().padding(.leading, 54)

            actionRow(
                icon: "rectangle.portrait.and.arrow.right",
                iconColor: Color.accentRed,
                label: "Sign Out",
                labelColor: Color.accentRed
            ) {
                withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.signOut()
                }
            }
        }
        .padding(.top, 4)
    }

    private func actionRow(
        icon: String,
        iconColor: Color,
        label: String,
        labelColor: Color = Color.mcTextPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(labelColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
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
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 24)
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
                    .padding(.vertical, 8)
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
