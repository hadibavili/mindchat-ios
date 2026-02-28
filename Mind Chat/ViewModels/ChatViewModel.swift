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
    @Published var uploadProgress: (current: Int, total: Int)? = nil
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

    // MARK: - Image Cache
    // Keyed by attachment ID. Populated once per attachment, survives re-renders.
    @Published var decodedImages: [String: UIImage] = [:]

    func cacheImage(_ image: UIImage, forId id: String) {
        decodedImages[id] = image
    }

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

        // Upload attachments before showing the user message bubble,
        // so the message only appears once we know uploads succeeded.
        var uploadedAttachments: [PendingAttachment] = []
        if !pendingAttachments.isEmpty {
            print("[Send] Starting upload of \(pendingAttachments.count) attachment(s)")
            isUploading = true
            uploadProgress = (current: 0, total: pendingAttachments.count)
            var failedCount = 0
            for (index, var att) in pendingAttachments.enumerated() {
                uploadProgress = (current: index + 1, total: pendingAttachments.count)
                print("[Send] Uploading '\(att.name)' (\(att.mimeType ?? "unknown"), \(att.data?.count ?? 0) bytes)")
                do {
                    let resp = try await upload.upload(attachment: att)
                    att.uploadedURL = resp.url
                    uploadedAttachments.append(att)
                    print("[Send] Upload OK → \(resp.url)")
                } catch {
                    print("[Send] Upload FAILED for '\(att.name)': \(error)")
                    failedCount += 1
                }
            }
            isUploading = false
            uploadProgress = nil
            if failedCount > 0 {
                isStreaming = false
                attachments = pendingAttachments
                inputText   = text
                errorMessage = "\(failedCount) file(s) failed to upload. Remove and retry."
                return
            }
            print("[Send] All uploads done, proceeding to chat")
        }

        thinkingStart = Date()

        // Optimistic user message — carry local image data so the bubble renders
        // immediately without a network round-trip back to the CDN.
        let userMessage = ChatMessage(
            content: text,
            role: .user,
            conversationId: conversationId,
            attachments: uploadedAttachments.isEmpty ? nil : uploadedAttachments.map {
                var att = MessageAttachment(
                    id: $0.id,
                    url: $0.uploadedURL ?? $0.localURL.absoluteString,
                    name: $0.name,
                    type: $0.kind == .image ? .image : .file,
                    mimeType: $0.mimeType
                )
                att.localImageData = $0.kind == .image ? $0.data : nil
                return att
            }
        )
        messages.append(userMessage)

        // Placeholder streaming message
        let assistantMessage = ChatMessage(content: "", role: .assistant, isStreaming: true)
        messages.append(assistantMessage)

        // Snapshot values needed inside the task (avoids captures of self across await)
        let snapshotConvId  = conversationId
        let snapshotProvider = provider
        let snapshotModel   = model
        let assistantId     = assistantMessage.id

        let history: [HistoryMessage] = messages.dropLast(2).compactMap { msg in
            guard msg.role == .user || msg.role == .assistant,
                  !msg.isError, !msg.content.isEmpty else { return nil }
            return HistoryMessage(role: msg.role, content: msg.content)
        }

        streamTask = Task.detached(priority: .userInitiated) {
            do {
                print("[SSE] Opening stream — provider=\(snapshotProvider.rawValue) model=\(snapshotModel) attachments=\(uploadedAttachments.count)")
                let stream = try await self.chat.send(
                    message: text,
                    conversationId: snapshotConvId,
                    provider: snapshotProvider,
                    model: snapshotModel,
                    history: history,
                    attachments: uploadedAttachments,
                    topicId: currentTopicFocus?.id
                )
                print("[SSE] Stream opened, waiting for events…")

                var tokenBatch = ""
                var lastFlush = Date()
                var tokenCount = 0
                var eventCount = 0

                for try await event in stream {
                    guard !Task.isCancelled else {
                        print("[SSE] Task cancelled after \(eventCount) events, \(tokenCount) tokens")
                        break
                    }
                    eventCount += 1

                    if case .token(let t) = event {
                        tokenBatch += t
                        tokenCount += 1
                        if tokenCount == 1 { print("[SSE] First token received") }
                        let now = Date()
                        if now.timeIntervalSince(lastFlush) >= 0.016 {
                            let batch = tokenBatch
                            tokenBatch = ""
                            lastFlush = now
                            await MainActor.run {
                                self.handle(event: .token(batch), assistantId: assistantId)
                            }
                        }
                    } else {
                        if !tokenBatch.isEmpty {
                            let batch = tokenBatch
                            tokenBatch = ""
                            lastFlush = Date()
                            await MainActor.run {
                                self.handle(event: .token(batch), assistantId: assistantId)
                            }
                        }
                        print("[SSE] Non-token event: \(event)")
                        await MainActor.run {
                            self.handle(event: event, assistantId: assistantId)
                        }
                    }
                }

                // Flush any remaining tokens
                if !tokenBatch.isEmpty {
                    let batch = tokenBatch
                    await MainActor.run {
                        self.handle(event: .token(batch), assistantId: assistantId)
                    }
                }
                print("[SSE] Stream exhausted — \(eventCount) events, \(tokenCount) tokens")

            } catch let e as AppError {
                print("[SSE] AppError: \(e.errorDescription ?? String(describing: e))")
                await MainActor.run { self.finishStream(assistantId: assistantId, error: e.errorDescription) }
            } catch {
                print("[SSE] Error: \(error)")
                await MainActor.run { self.finishStream(assistantId: assistantId, error: error.localizedDescription) }
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
