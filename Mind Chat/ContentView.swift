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
                TopicsDashboardView()
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
                Color.black.opacity(0.5)
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
        .onChange(of: appState.selectedConversationId) { _, id in
            guard let id else { return }
            chatVM.newChat()
            Task { await chatVM.loadMessages(conversationId: id) }
            appState.selectedConversationId = nil
        }
    }
}
