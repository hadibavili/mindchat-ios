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
    @State private var showSettings             = false
    @State private var showConversationHistory  = false
    @State private var showTopic: TopicNavTarget? = nil

    var body: some View {
        ZStack(alignment: .leading) {

            // Main chat
            NavigationStack {
                ChatView(
                    vm: chatVM,
                    conversationsVM: conversationsVM,
                    showSidebar: $showSidebar,
                    showConversationHistory: $showConversationHistory
                )
            }
            .sheet(isPresented: $showKnowledge) {
                TopicsDashboardView(vm: topicsVM)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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

            // Scrim
            if showSidebar {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
                    }
                    .zIndex(1)
            }

            // Sliding sidebar
            if showSidebar {
                SidebarView(
                    conversationsVM: conversationsVM,
                    topicsVm: topicsVM,
                    chatVM: chatVM,
                    showSidebar: $showSidebar,
                    showKnowledge: $showKnowledge,
                    showSettings: $showSettings,
                    showConversationHistory: $showConversationHistory,
                    showTopic: $showTopic
                )
                .frame(width: min(UIScreen.main.bounds.width * 0.85, 320))
                .ignoresSafeArea(edges: .vertical)
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.25), value: showSidebar)
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
                showConversationHistory = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    chatVM.newChat()
                    Task { await chatVM.loadMessages(conversationId: convId) }
                }
            }
            if case .startChatWithTopic(let topicId, let topicName, let factCount) = event {
                showTopic = nil
                showKnowledge = false
                showConversationHistory = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    chatVM.newChat()
                    chatVM.topicFocus = TopicFocus(id: topicId, name: topicName, factCount: factCount)
                }
            }
        }
    }
}
