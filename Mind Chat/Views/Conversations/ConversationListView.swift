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

    // MARK: - Filtered Topics

    private var filteredTopics: [TopicTreeNode] {
        guard !searchText.isEmpty else { return topicsVm.rootTopics }
        return topicsVm.rootTopics.compactMap { filterNode($0, query: searchText) }
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
            // Top bar
            topBar

            // Search
            searchBar
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Scrollable content
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    newChatRow
                    topicsListSection
                }
                .padding(.bottom, 12)
            }

            // Bottom user row
            Divider()
            userRow
        }
        .background(Color.mcBgSidebar)
        .onReceive(EventBus.shared.events) { event in
            if case .topicsUpdated = event {
                Task { await topicsVm.refresh() }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("Mind Chat")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.mcTextPrimary)
            Spacer()
            Button {
                dismiss { showSettings = true }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.mcTextSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

    // MARK: - New Chat Row

    private var newChatRow: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextSecondary)
                    .frame(width: 22)
                Text("New chat")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
    }

    // MARK: - Topics List

    @ViewBuilder
    private var topicsListSection: some View {
        if topicsVm.isLoading && topicsVm.rootTopics.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if filteredTopics.isEmpty && !searchText.isEmpty {
            Text("No results")
                .font(.system(size: 14))
                .foregroundStyle(Color.mcTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if !filteredTopics.isEmpty {
            // Section label
            HStack {
                Text("Memory")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mcTextTertiary)
                Spacer()
                Button {
                    dismiss { showKnowledge = true }
                } label: {
                    Text("See all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mcTextLink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ForEach(filteredTopics) { node in
                DrawerTopicNode(node: node, depth: 0) { selected in
                    showTopic = TopicNavTarget(id: selected.id, title: selected.name)
                    dismiss()
                }
            }
        } else {
            // Empty state — no topics yet
            HStack {
                Text("Memory")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mcTextTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

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
        }

        // History row
        Button {
            dismiss { showConversationHistory = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextSecondary)
                    .frame(width: 22)
                Text("History")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mcTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
        .padding(.top, 8)
    }

    // MARK: - User Row

    private var userRow: some View {
        Button {
            dismiss { showSettings = true }
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 34, height: 34)
                    Text(initials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.currentUser?.name ?? "User")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.mcTextPrimary)
                        .lineLimit(1)
                    Text(planLabel)
                        .font(.system(size: 12))
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
                    // Indentation
                    Color.clear.frame(width: CGFloat(16 + depth * 16), height: 1)

                    // Expand chevron or spacer
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
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mcTextTertiary)
                            .monospacedDigit()
                            .padding(.trailing, 16)
                    }
                }
                .padding(.vertical, 9)
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
