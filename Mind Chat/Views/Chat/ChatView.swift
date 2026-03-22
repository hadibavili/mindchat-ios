import SwiftUI
import Combine

struct ChatView: View {

    @ObservedObject var vm: ChatViewModel
    @ObservedObject var conversationsVM: ConversationsViewModel
    @Binding var showSidebar: Bool
    @Binding var showConversationHistory: Bool
    @EnvironmentObject private var appState: AppState
    @State private var showModelSelector  = false
    @State private var showPersonaPicker  = false
    @State private var showRenameAlert    = false
    @State private var renameText         = ""
    @State private var atBottom           = true
    @State private var isInteracting      = false
    @State private var userScrolledUp     = false
    @State private var flatTopics: [TopicTreeNode] = []
    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {

            // Email verification banner
            if let user = appState.currentUser, !user.isEmailVerified {
                EmailVerificationBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    messageListContent
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onScrollPhaseChange { _, newPhase in
                    isInteracting = (newPhase != .idle)
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                    geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 50
                } action: { _, isNearBottom in
                    atBottom = isNearBottom
                    if isInteracting {
                        if isNearBottom {
                            userScrolledUp = false      // User actively scrolled back to bottom
                        } else {
                            userScrolledUp = true       // User actively scrolled away
                        }
                    }
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if !userScrolledUp {
                        scrollToBottom(proxy)
                    }
                }
                .onChange(of: vm.isLoading) { wasLoading, isLoading in
                    if wasLoading && !isLoading && !vm.messages.isEmpty {
                        // Conversation just loaded — scroll after layout settles
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            userScrolledUp = false
                            scrollToBottom(proxy)
                        }
                    }
                }
                .onChange(of: vm.isStreaming) { _, streaming in
                    if streaming {
                        // New send — reset scroll lock and jump to bottom
                        userScrolledUp = false
                        scrollToBottom(proxy)
                    } else if !userScrolledUp {
                        // Streaming finished — reveal the completed response
                        Task {
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            if !userScrolledUp {
                                scrollToBottom(proxy)
                            }
                        }
                    }
                }
                // Keep view pinned to bottom while tokens arrive
                .task(id: vm.isStreaming) {
                    guard vm.isStreaming else { return }
                    while !Task.isCancelled && vm.isStreaming {
                        if !userScrolledUp && !isInteracting {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }
                .animation(.mcSnappy, value: atBottom)
                .onAppear { scrollToBottom(proxy) }
            }

            // Clear chat
            if !vm.messages.isEmpty && vm.chatMemory == .persistClearable {
                Button { Task { await vm.clearChat() } } label: {
                    Text("Clear conversation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            // Topic autocomplete overlay
            if let query = vm.activeHashtagQuery {
                TopicAutocompleteOverlay(
                    allTopics: flatTopics,
                    query: query
                ) { node in
                    vm.selectTopicFromAutocomplete(node)
                }
                .padding(.bottom, 4)
            }

            // Input
            ChatInputView(vm: vm)
                .disabled(vm.isLoading)
                .opacity(vm.isLoading ? 0.5 : 1)
        }
        .animation(.mcSnappy, value: vm.activeHashtagQuery != nil)
        .task {
            if let cached: [TopicTreeNode] = CacheStore.shared.get(.topicsTree) {
                flatTopics = TopicTreeNode.flattenAll(cached)
            }
        }
        .onReceive(EventBus.shared.events) { event in
            if case .topicsUpdated = event {
                if let cached: [TopicTreeNode] = CacheStore.shared.get(.topicsTree) {
                    flatTopics = TopicTreeNode.flattenAll(cached)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Sidebar toggle (left)
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(.easeOut(duration: 0.25)) { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 18))
                }
                .accessibilityIdentifier("chat.sidebarToggle")
            }

            // Center: model name + chevron
            ToolbarItem(placement: .principal) {
                Button { showModelSelector = true } label: {
                    HStack(spacing: 5) {
                        Text(currentModelLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(Color.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .accessibilityIdentifier("chat.modelSelector")
            }

            // Right: new-chat pencil (always) + ellipsis menu (in conversation)
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    if vm.conversationId != nil {
                        Menu {
                            Button {
                                renameText = vm.conversationTitle ?? ""
                                showRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                Task {
                                    if let id = vm.conversationId {
                                        await conversationsVM.delete(conversation: Conversation(id: id, title: vm.conversationTitle, createdAt: nil, updatedAt: Date()))
                                    }
                                    vm.newChat()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                        }
                    }

                    Button { vm.newChat() } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                    }
                    .accessibilityIdentifier("chat.newChatButton")
                }
            }
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorSheet(vm: vm)
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaSelectorSheet(vm: vm)
        }
        .alert("Rename Conversation", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let id = vm.conversationId, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    let conv = Conversation(id: id, title: renameText, createdAt: nil, updatedAt: Date())
                    Task { await conversationsVM.rename(conversation: conv, title: renameText) }
                    vm.conversationTitle = renameText
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Helpers

    private var currentModelLabel: String {
        MODEL_OPTIONS.first { $0.id == vm.model }?.label ?? vm.model
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) }
    }

    // MARK: - Message List Content

    private var messageListContent: some View {
        VStack(spacing: 0) {
            if vm.messages.isEmpty && vm.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.secondary)
                    Text("Loading conversation…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .containerRelativeFrame(.vertical)
            } else if vm.messages.isEmpty {
                EmptyStateView(vm: vm)
                    .containerRelativeFrame(.vertical)
            }

            // Top padding before first message
            if !vm.messages.isEmpty {
                Color.clear.frame(height: 16)
            }

            ForEach(Array(vm.messages.enumerated()), id: \.element.id) { idx, message in
                let prevDate = idx > 0 ? vm.messages[idx - 1].createdAt : nil
                if shouldShowSeparator(current: message.createdAt, previous: prevDate) {
                    DateSeparator(date: message.createdAt)
                }
                MessageBubble(
                    message: message,
                    isHighlighted: vm.highlightMessageId == message.id,
                    vm: vm
                )
                .id(message.id)
                .transition(.messageAppear)
                .animation(.none, value: message.content)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)

            Group {
                if let start = vm.thinkingStart {
                    ThinkingBubble(startTime: start)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .transition(.indicatorAppear)
                }
            }
            .animation(.mcGentle, value: vm.thinkingStart == nil)

            Group {
                if vm.isSearching {
                    SearchingIndicator()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .transition(.indicatorAppear)
                }
            }
            .animation(.mcGentle, value: vm.isSearching)

            Group {
                if vm.isGeneratingImage {
                    GeneratingImageBubble()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .transition(.indicatorAppear)
                }
            }
            .animation(.mcGentle, value: vm.isGeneratingImage)

            if let error = vm.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(Color.accentRed)
                    Text(error).font(.footnote).foregroundStyle(Color.accentRed)
                    Spacer()
                    Button("Retry") { Task { await vm.send() } }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.mcTextLink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Color.clear.frame(height: 8).id(bottomID)
        }
        .animation(.mcGentle, value: vm.messages.count)
    }

    private func shouldShowSeparator(current: Date, previous: Date?) -> Bool {
        guard let prev = previous else { return false }
        return !Calendar.current.isDate(current, inSameDayAs: prev)
    }
}

// MARK: - Thinking Bubble

struct ThinkingBubble: View {

    let startTime: Date
    @State private var elapsed: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.secondary)
            Text("thinking…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear {
            elapsed = max(0, Int(Date().timeIntervalSince(startTime)))
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsed = max(0, Int(Date().timeIntervalSince(startTime)))
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - Searching Indicator

struct SearchingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(animating ? 360 : 0))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: animating)
            Text("Searching the web…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Generating Image Bubble

private struct GeneratingImageBubble: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.badge.plus")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Generating image" + String(repeating: ".", count: dotCount))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}


