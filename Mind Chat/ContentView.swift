import SwiftUI

// MARK: - Content View (Auth Gate)

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Topic Navigation Target

struct TopicNavTarget: Identifiable {
    let id: String
    let title: String
}

// MARK: - Main Tab View

struct MainTabView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var chatVM          = ChatViewModel()
    @StateObject private var conversationsVM = ConversationsViewModel()
    @StateObject private var topicsVM        = TopicsViewModel()
    @State private var showSidebar              = false
    @State private var showKnowledge            = false
    @State private var showMyMind               = false
    @State private var showSettings             = false
    @State private var showConversationHistory  = false
    @State private var showTopic: TopicNavTarget? = nil
    @State private var dragOffset: CGFloat      = 0

    private var sidebarWidth: CGFloat { min(UIScreen.main.bounds.width * 0.85, 320) }

    // 0 = fully closed, 1 = fully open — drives offset and scrim together
    private var sidebarProgress: CGFloat {
        let base: CGFloat = showSidebar ? sidebarWidth : 0
        return max(0, min(1, (base + dragOffset) / sidebarWidth))
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Sidebar sits behind — revealed as main content slides right
            SidebarView(
                conversationsVM: conversationsVM,
                topicsVm: topicsVM,
                chatVM: chatVM,
                showSidebar: $showSidebar,
                showKnowledge: $showKnowledge,
                showMyMind: $showMyMind,
                showSettings: $showSettings,
                showConversationHistory: $showConversationHistory,
                showTopic: $showTopic
            )
            .frame(width: sidebarWidth)
            .ignoresSafeArea(edges: .vertical)

            // Main content — pushed right when sidebar opens
            NavigationStack {
                ChatView(
                    vm: chatVM,
                    conversationsVM: conversationsVM,
                    showSidebar: $showSidebar,
                    showConversationHistory: $showConversationHistory
                )
                .navigationDestination(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showKnowledge) {
                TopicsDashboardView(vm: topicsVM)
            }
            .sheet(isPresented: $showMyMind) {
                MyMindView(topicsVM: topicsVM)
            }
            .sheet(isPresented: $showConversationHistory) {
                ConversationHistoryView(
                    conversationsVM: conversationsVM,
                    onSelect: { conv in
                        showConversationHistory = false
                        chatVM.newChat()
                        Task { await chatVM.loadMessages(conversationId: conv.id) }
                    }
                )
            }
            .sheet(item: $showTopic) { target in
                NavigationStack {
                    TopicDetailView(topicId: target.id, title: target.title)
                    .navigationDestination(for: TopicWithStats.self) { topic in
                        TopicDetailView(topicId: topic.id, title: topic.name)
                    }
                }
            }
            // Visual scrim only — no gestures, never causes feedback loop
            .overlay {
                Color.black.opacity(0.25 * sidebarProgress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .offset(x: sidebarProgress * sidebarWidth)

            // Stationary close layer — sits in ZStack so it never moves
            if showSidebar || dragOffset < 0 {
                HStack(spacing: 0) {
                    // Sidebar area: let touches pass through to the sidebar
                    Color.clear
                        .frame(width: sidebarWidth)
                        .allowsHitTesting(false)
                    // Chat area: tap or drag left to close
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                showSidebar = false
                                dragOffset = 0
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    guard value.translation.width < 0 else { return }
                                    dragOffset = max(-sidebarWidth, value.translation.width)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                        showSidebar = (sidebarWidth + dragOffset) > sidebarWidth / 2
                                        dragOffset = 0
                                    }
                                }
                        )
                }
                .ignoresSafeArea()
                .zIndex(3)
            }

            // Thin edge strip — captures open gesture without conflicting with scroll views
            if !showSidebar {
                Color.clear
                    .frame(width: 24)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                guard value.translation.width > 0 else { return }
                                dragOffset = min(sidebarWidth, value.translation.width)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                    showSidebar = dragOffset > sidebarWidth / 2
                                    dragOffset = 0
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zIndex(3)
            }
        }
        .task { await conversationsVM.load() }
        .task { await chatVM.loadSettings() }
        .task { await topicsVM.load() }
        .task { await SettingsService.shared.refreshInBackground() }
        .onChange(of: appState.selectedConversationId) { _, id in
            guard let id else { return }
            chatVM.newChat()
            Task { await chatVM.loadMessages(conversationId: id) }
            appState.selectedConversationId = nil
        }
        .onReceive(EventBus.shared.events) { event in
            if case .navigateToMessage(let convId, _) = event {
                showTopic = nil
                showKnowledge = false
                showMyMind = false
                showConversationHistory = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    chatVM.newChat()
                    Task { await chatVM.loadMessages(conversationId: convId) }
                }
            }
            if case .startChatWithTopic(let topicId, let topicName, let factCount) = event {
                showTopic = nil
                showKnowledge = false
                showMyMind = false
                showConversationHistory = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    chatVM.newChat()
                    chatVM.topicFocus = TopicFocus(id: topicId, name: topicName, factCount: factCount)
                }
            }
        }
    }
}
