import SwiftUI

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
                    VStack(spacing: 0) {
                        if vm.messages.isEmpty && !vm.isLoading {
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
                        }
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)

                        if let start = vm.thinkingStart {
                            ThinkingBubble(startTime: start)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .transition(.indicatorAppear)
                        }

                        if vm.isSearching {
                            SearchingIndicator()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .transition(.indicatorAppear)
                        }


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
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.count) { _, _ in
                    if atBottom { scrollToBottom(proxy) }
                }
                .onChange(of: vm.isStreaming) { _, streaming in
                    if streaming && atBottom { scrollToBottom(proxy) }
                }
                // Keep view pinned to bottom while tokens arrive, without per-token onChange
                .task(id: vm.isStreaming) {
                    guard vm.isStreaming else { return }
                    while !Task.isCancelled && vm.isStreaming {
                        if atBottom { scrollToBottom(proxy) }
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !atBottom {
                        ScrollToBottomButton { scrollToBottom(proxy) }
                            .padding(16)
                            .transition(.scale.combined(with: .opacity))
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


