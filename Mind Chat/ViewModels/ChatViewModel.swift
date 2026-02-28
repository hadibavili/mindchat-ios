import SwiftUI
import Combine

// MARK: - Topic Focus

struct TopicFocus: Sendable {
    let id: String
    let name: String
    let factCount: Int
}

// MARK: - Chat View Model

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputText   = ""
    @Published var isStreaming = false
    @Published var isLoading   = false
    @Published var isSearching  = false
    @Published var isExtracting = false
    @Published var errorMessage: String?
    @Published var conversationId: String?
    @Published var conversationTitle: String?
    @Published var thinkingStart: Date?
    @Published var attachments: [PendingAttachment] = []
    @Published var isUploading = false
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var showScrollToBottom = false
    @Published var highlightMessageId: String?
    @Published var extractedTopics: [ExtractedTopic] = []
    @Published var topicFocus: TopicFocus?

    // MARK: - Settings (loaded from server)

    @Published var provider: AIProvider   = .openai
    @Published var model: String          = "gpt-4.1-mini"
    @Published var chatMemory: ChatMemoryMode = .alwaysPersist
    @Published var plan: PlanType         = .free
    @Published var voiceEnabled: Bool     = false
    @Published var imageUploadsEnabled: Bool = false
    @Published var showMemoryIndicators: Bool = true

    // MARK: - Private

    private var streamTask: Task<Void, Never>?
    private var recordingTimer: Timer?

    private let chat     = ChatService.shared
    private let upload   = UploadService.shared
    private let eventBus = EventBus.shared

    // MARK: - Load Messages

    func loadMessages(conversationId: String? = nil, highlight: String? = nil) async {
        guard let id = conversationId ?? self.conversationId else { return }
        self.conversationId = id
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await chat.messages(conversationId: id, highlight: highlight)
            if let hl = highlight {
                highlightMessageId = hl
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.highlightMessageId = nil
                }
            }
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingAttachments = attachments
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        guard !isStreaming else { return }

        // Capture topic focus before clearing state
        let currentTopicFocus = topicFocus

        // Lock the UI immediately so the button can't be tapped again
        inputText       = ""
        attachments     = []
        extractedTopics = []
        errorMessage    = nil
        topicFocus      = nil
        isStreaming     = true
        thinkingStart   = Date()

        // Optimistic user message — use local file URLs so images display instantly
        let userMessage = ChatMessage(
            content: text,
            role: .user,
            conversationId: conversationId,
            attachments: pendingAttachments.isEmpty ? nil : pendingAttachments.map {
                MessageAttachment(
                    id: $0.id,
                    url: $0.localURL.absoluteString,
                    name: $0.name,
                    type: $0.kind == .image ? .image : .file,
                    mimeType: $0.mimeType
                )
            }
        )
        messages.append(userMessage)

        // Placeholder streaming message
        var assistantMessage = ChatMessage(content: "", role: .assistant, isStreaming: true)
        messages.append(assistantMessage)

        // Upload attachments (awaited so the AI receives the actual files)
        var uploadedAttachments: [PendingAttachment] = []
        if !pendingAttachments.isEmpty {
            isUploading = true
            var failedCount = 0
            for var att in pendingAttachments {
                do {
                    let resp = try await upload.upload(attachment: att)
                    att.uploadedURL = resp.url
                    uploadedAttachments.append(att)
                } catch {
                    failedCount += 1
                }
            }
            isUploading = false
            if failedCount > 0 {
                // Block send if any uploads failed
                isStreaming = false
                thinkingStart = nil
                errorMessage = "\(failedCount) file(s) failed to upload. Remove and retry."
                return
            }
        }

        streamTask = Task {
            do {
                // Build history: exclude the current user msg and the assistant placeholder
                // (both just appended), so we only send prior conversation context.
                let history: [HistoryMessage] = messages.dropLast(2).compactMap { msg in
                    guard msg.role == .user || msg.role == .assistant,
                          !msg.isError, !msg.content.isEmpty else { return nil }
                    return HistoryMessage(role: msg.role, content: msg.content)
                }

                let stream = try await chat.send(
                    message: text,
                    conversationId: conversationId,
                    provider: provider,
                    model: model,
                    history: history,
                    attachments: uploadedAttachments,
                    topicId: currentTopicFocus?.id
                )

                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    handle(event: event, assistantId: assistantMessage.id)
                    // Update local ref
                    if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) {
                        assistantMessage = messages[idx]
                    }
                }
            } catch let e as AppError {
                finishStream(assistantId: assistantMessage.id, error: e.errorDescription)
            } catch {
                finishStream(assistantId: assistantMessage.id, error: error.localizedDescription)
            }
        }
    }

    private func handle(event: SSEEvent, assistantId: String) {
        switch event {
        case .conversationId(let id):
            if conversationId == nil {
                conversationId = id
                eventBus.publish(.conversationCreated(id: id, title: nil))
            }
        case .conversationTitle(let title):
            conversationTitle = title
            // Trigger second sidebar refresh now that the title is available
            if let id = conversationId {
                eventBus.publish(.conversationCreated(id: id, title: title))
            }
        case .token(let token):
            thinkingStart = nil
            isSearching = false
            appendToken(token, to: assistantId)
        case .searching:
            isSearching = true
        case .searchComplete(_, let sources):
            isSearching = false
            if !sources.isEmpty {
                updateSources(sources, for: assistantId)
            }
        case .extracting:
            isStreaming = false   // unlock input immediately; SSE task keeps running
            if showMemoryIndicators { isExtracting = true }
        case .topicsExtracted(let topics):
            isExtracting = false
            if showMemoryIndicators {
                extractedTopics = topics
                updateTopics(topics, for: assistantId)
            }
            eventBus.publish(.topicsUpdated)
        case .error(let msg):
            finishStream(assistantId: assistantId, error: msg)
        case .done:
            finishStream(assistantId: assistantId, error: nil)
        }
    }

    private func appendToken(_ token: String, to id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content += token
    }

    private func updateTopics(_ topics: [ExtractedTopic], for id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].streamingTopics = topics
    }

    private func updateSources(_ sources: [SearchSource], for id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].sources = sources
    }

    private func finishStream(assistantId: String, error: String?) {
        isStreaming   = false
        isSearching   = false
        isExtracting  = false
        thinkingStart = nil
        streamTask    = nil

        guard let idx = messages.firstIndex(where: { $0.id == assistantId }) else { return }
        messages[idx].isStreaming = false
        if let error {
            messages[idx].isError = true
            messages[idx].content = error
        }
    }

    // MARK: - Stop Streaming

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        if let idx = messages.indices.last {
            messages[idx].isStreaming = false
        }
        isStreaming = false
    }

    // MARK: - Message Actions

    func copyMessage(_ message: ChatMessage) {
        UIPasteboard.general.string = message.content
        Haptics.light()
    }

    func editLastUserMessage() {
        guard let idx = messages.lastIndex(where: { $0.role == .user }) else { return }
        inputText = messages[idx].content
        messages.removeSubrange((idx)...)
    }

    func regenerateLast() async {
        guard let idx = messages.lastIndex(where: { $0.role == .assistant }),
              idx > 0
        else { return }
        messages.removeSubrange(idx...)
        if let userIdx = messages.lastIndex(where: { $0.role == .user }) {
            inputText = messages[userIdx].content
            messages.removeSubrange(userIdx...)
        }
        await send()
    }

    func retryError(messageId: String) async {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: idx)
        }
        if let userIdx = messages.lastIndex(where: { $0.role == .user }) {
            inputText = messages[userIdx].content
            messages.removeSubrange(userIdx...)
        }
        await send()
    }

    // MARK: - Clear Chat

    func clearChat() async {
        guard let id = conversationId else { return }
        do {
            try await chat.clearMessages(conversationId: id)
            messages = []
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - New Chat

    func newChat() {
        stopStreaming()
        messages          = []
        conversationId    = nil
        conversationTitle = nil
        inputText         = ""
        attachments       = []
        extractedTopics   = []
        errorMessage      = nil
        topicFocus        = nil
    }

    // MARK: - Settings

    func loadSettings() async {
        let service = SettingsService.shared

        // Phase 1: populate from disk cache synchronously (before first await)
        // This runs instantly on cold launch, showing the correct plan/model/limits
        // with zero network latency.
        if let cached = service.getCachedSettings() {
            provider             = cached.provider
            model                = cached.model
            chatMemory           = cached.chatMemory
            plan                 = cached.plan
            showMemoryIndicators = cached.showMemoryIndicators
        }
        if let cachedUsage = service.getCachedUsage() {
            voiceEnabled        = cachedUsage.limits.voice
            imageUploadsEnabled = cachedUsage.limits.imageUploads
        }

        // Phase 2: fetch fresh from server and update cache + UI in background
        do {
            let s = try await service.getSettings()
            provider             = s.provider
            model                = s.model
            chatMemory           = s.chatMemory
            plan                 = s.plan
            showMemoryIndicators = s.showMemoryIndicators
        } catch {
            print("[ChatViewModel] loadSettings failed: \(error)")
        }
        do {
            let usage = try await service.getUsage()
            voiceEnabled         = usage.limits.voice
            imageUploadsEnabled  = usage.limits.imageUploads
        } catch {
            print("[ChatViewModel] getUsage failed: \(error)")
        }
    }

    // MARK: - Suggestion

    func useSuggestion(_ text: String) {
        inputText = text
    }
}
