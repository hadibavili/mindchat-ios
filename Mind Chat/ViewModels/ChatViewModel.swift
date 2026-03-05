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
    @Published var isSearching      = false
    @Published var isExtracting     = false
    @Published var isGeneratingImage = false
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
    @Published var smartSuggestions: [String] = []

    // MARK: - Question Form State

    /// Answers for question-form messages, keyed by message ID → question ID → answer text.
    @Published var formAnswers: [String: [String: String]] = [:]
    /// Set of message IDs whose question forms have been submitted.
    @Published var submittedForms: Set<String> = []

    // MARK: - Settings (loaded from server)

    @Published var provider: AIProvider   = .openai
    @Published var model: String          = "gpt-4.1-mini"
    @Published var chatMemory: ChatMemoryMode = .alwaysPersist
    @Published var persona: PersonaType   = .default
    @Published var plan: PlanType         = .free
    @Published var voiceEnabled: Bool     = false
    @Published var imageUploadsEnabled: Bool = false
    @Published var showMemoryIndicators: Bool = true
    @Published var modelRecommendation: ModelRecommendation?

    // MARK: - Image Cache
    // Keyed by attachment ID. Populated once per attachment, survives re-renders.
    @Published var decodedImages: [String: UIImage] = [:]

    func cacheImage(_ image: UIImage, forId id: String) {
        decodedImages[id] = image
    }

    // MARK: - Private

    private var streamTask: Task<Void, Never>?
    private var suggestionsTask: Task<Void, Never>?
    private var recommendationTask: Task<Void, Never>?
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    /// True while the model is actively streaming a tool call block; suppresses those tokens from the UI.
    private var isInToolCallBlock = false

    private let chat     = ChatService.shared
    private let upload   = UploadService.shared
    private let eventBus = EventBus.shared

    // MARK: - Init

    init() {
        EventBus.shared.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .modelChanged(let p, let m):
                    self?.provider = p
                    self?.model    = m
                    self?.modelRecommendation = nil
                    self?.recommendationTask?.cancel()
                    self?.recommendationTask = nil
                case .appMovedToBackground:
                    if self?.isStreaming == true {
                        BackgroundStreamManager.shared.beginBackgroundProcessing()
                    }
                case .appReturnedToForeground:
                    self?.handleForegroundReturn()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        $inputText
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] text in
                print("[ModelRec] debounce fired, text='\(text.prefix(40))'")
                self?.updateModelRecommendation(for: text)
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Messages

    func loadMessages(conversationId: String? = nil, highlight: String? = nil) async {
        guard let id = conversationId ?? self.conversationId else {
            print("[DEBUG] loadMessages — no conversationId, returning")
            return
        }
        print("[DEBUG] loadMessages — loading conversation: \(id)")
        self.conversationId = id
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await chat.messages(conversationId: id, highlight: highlight)
            print("[DEBUG] loadMessages — got \(messages.count) messages")
            // Auto-detect submitted question forms from history
            for (idx, msg) in messages.enumerated() {
                guard msg.role == .assistant,
                      QuestionForm.parse(from: msg.content) != nil,
                      idx + 1 < messages.count,
                      messages[idx + 1].role == .user else { continue }
                submittedForms.insert(msg.id)
            }
            if let hl = highlight {
                highlightMessageId = hl
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.highlightMessageId = nil
                }
            }
        } catch let e as AppError {
            print("[DEBUG] loadMessages — AppError: \(e.errorDescription ?? String(describing: e))")
            errorMessage = e.errorDescription
        } catch {
            print("[DEBUG] loadMessages — Error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send

    func send() async {
        Task { await NotificationManager.shared.requestPermissionIfNeeded() }

        let sendStart = Date()
        print("[Timing] ▶ send() called — T+0.000s")
        var text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingAttachments = attachments
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        // Server requires a non-empty message; provide a default for attachment-only sends
        if text.isEmpty && !pendingAttachments.isEmpty {
            text = "What's in this?"
        }
        guard !isStreaming else { return }

        // Capture topic focus before clearing state
        let currentTopicFocus = topicFocus

        // Lock the UI immediately so the button can't be tapped again
        inputText           = ""
        attachments         = []
        extractedTopics     = []
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

        let capturedSendStart = sendStart
        streamTask = Task.detached(priority: .userInitiated) {
            func elapsed() -> String { String(format: "%.3f", Date().timeIntervalSince(capturedSendStart)) }
            do {
                print("[Timing] T+\(elapsed())s — calling chat.send() | provider=\(snapshotProvider.rawValue) model=\(snapshotModel)")
                let stream = try await self.chat.send(
                    message: text,
                    conversationId: snapshotConvId,
                    provider: snapshotProvider,
                    model: snapshotModel,
                    history: history,
                    attachments: uploadedAttachments,
                    topicId: currentTopicFocus?.id
                )
                print("[Timing] T+\(elapsed())s — stream returned (SSE connected), waiting for first event…")

                var tokenBatch = ""
                var lastFlush = Date()
                var tokenCount = 0
                var eventCount = 0

                for try await event in stream {
                    guard !Task.isCancelled else {
                        print("[Timing] T+\(elapsed())s — task cancelled after \(eventCount) events, \(tokenCount) tokens")
                        break
                    }
                    eventCount += 1

                    if case .token(let t) = event {
                        tokenBatch += t
                        tokenCount += 1
                        if tokenCount == 1 { print("[Timing] T+\(elapsed())s — ★ FIRST TOKEN received") }
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
                print("[Timing] T+\(elapsed())s — stream exhausted | \(eventCount) events, \(tokenCount) tokens")

            } catch let e as AppError {
                print("[Timing] T+\(elapsed())s — AppError: \(e.errorDescription ?? String(describing: e))")
                await MainActor.run { self.finishStream(assistantId: assistantId, error: e.errorDescription) }
            } catch {
                print("[Timing] T+\(elapsed())s — Error: \(error)")
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
            if token.contains("![") || (token.contains("http") && (token.contains(".png") || token.contains(".jpg") || token.contains(".webp") || token.contains(".gif"))) {
                print("[ChatViewModel] token may contain image URL: \(token)")
            }
            appendToken(token, to: assistantId)
        case .searching:
            isInToolCallBlock = false   // tool call tokens have ended
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
        case .generatingImage:
            print("[ChatViewModel] generating_image event — image is being created")
            isInToolCallBlock = false   // tool call tokens have ended
            isGeneratingImage = true

        case .imageGenerated(let url, let name):
            print("[ChatViewModel] imageGenerated event | url='\(url)' | name='\(name ?? "nil")'")
            isGeneratingImage = false
            let att = MessageAttachment(
                id: UUID().uuidString,
                url: url,
                name: name ?? "Generated Image",
                type: .image,
                mimeType: "image/png"
            )
            guard let idx = messages.firstIndex(where: { $0.id == assistantId }) else { return }
            if messages[idx].attachments == nil {
                messages[idx].attachments = [att]
            } else {
                messages[idx].attachments?.append(att)
            }
            let attId = att.id
            downloadAndCacheImage(url: url, forId: attId)

        case .streamEnd:
            print("[ChatViewModel] stream_end event — text stream finished")
            isStreaming = false
        case .error(let msg):
            finishStream(assistantId: assistantId, error: msg)
        case .done:
            finishStream(assistantId: assistantId, error: nil)
        }
    }

    private func appendToken(_ token: String, to id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }

        // Suppress all tokens while inside a tool call block
        if isInToolCallBlock { return }

        let current  = messages[idx].content
        let candidate = current + token

        // Detect XML-style tool call block opener — enter suppression mode
        for opener in ["<tool_call>", "<|tool_call|>"] {
            if let range = candidate.range(of: opener, options: .caseInsensitive) {
                messages[idx].content = String(candidate[candidate.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                isInToolCallBlock = true
                return
            }
        }

        // Detect bare "tool\n" pattern emitted by some models (no XML tags):
        //   token #1: "tool"   token #2: "\n"   token #3+: function name, json …
        // We recognise the boundary when we see "tool" sitting on its own line.
        let barePattern = #"(?:^|\n)tool\n"#
        if let range = candidate.range(of: barePattern, options: .regularExpression) {
            messages[idx].content = String(candidate[candidate.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            isInToolCallBlock = true
            return
        }

        messages[idx].content = candidate
    }

    private func updateTopics(_ topics: [ExtractedTopic], for id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].streamingTopics = topics
    }

    private func updateSources(_ sources: [SearchSource], for id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].sources = sources
    }
//
//    /// Strip tool call / tool result blocks that some models leak as plain text in token events.
//    private func stripToolCallBlocks(_ text: String) -> String {
//        var result = text
//        // Full blocks (content between open and close tags)
//        let blockPatterns = [
//            #"<tool_call>[\s\S]*?<\/tool_call>"#,
//            #"<tool_result>[\s\S]*?<\/tool_result>"#,
//            #"<\|tool_call\|>[\s\S]*?<\|\/tool_call\|>"#,
//            #"<\|tool_result\|>[\s\S]*?<\|\/tool_result\|>"#,
//        ]
//        for pattern in blockPatterns {
//            result = result.replacingOccurrences(
//                of: pattern, with: "",
//                options: [.regularExpression, .caseInsensitive]
//            )
//        }
//        // Orphaned open/close tags (unclosed blocks or stray delimiters)
//        let tagPattern = #"<\/?tool_(call|result)>|<\|\/?\s*tool_(call|result)\s*\|>"#
//        result = result.replacingOccurrences(
//            of: tagPattern, with: "",
//            options: [.regularExpression, .caseInsensitive]
//        )
//        // Bare "tool\n<functionName>" format — truncate from the pattern to end-of-string
//        // (the live suppression handles this during streaming; this is the safety-net pass)
//        if let range = result.range(of: #"(?:^|\n)tool\n\w"#, options: .regularExpression) {
//            result = String(result[result.startIndex..<range.lowerBound])
//        }
//        return result.trimmingCharacters(in: .whitespacesAndNewlines)
//    }

    /// Rewrite raw private Vercel Blob URLs to go through the /api/blob proxy.
    private func proxyBlobURL(_ url: String) -> String {
        guard let u = URL(string: url),
              let host = u.host,
              host.hasSuffix(".blob.vercel-storage.com") else { return url }
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        return "https://app.mindchat.fenqor.nl/api/blob?url=\(encoded)"
    }

    func downloadAndCacheImage(url: String, forId id: String) {
        let resolvedURL = proxyBlobURL(url)
        Task {
            // L2: disk cache hit — skip network entirely
            if let cached = ImageDiskCache.shared.read(for: url) {
                print("[ChatViewModel] disk cache hit for id=\(id)")
                await MainActor.run { cacheImage(cached, forId: id) }
                return
            }

            guard let imageURL = URL(string: resolvedURL) else {
                print("[ChatViewModel] invalid generated image URL: \(resolvedURL)")
                return
            }
            var request = URLRequest(url: imageURL)
            if let token = KeychainManager.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    print("[ChatViewModel] image download status: \(http.statusCode) (\(data.count) bytes)")
                }
                guard let image = UIImage(data: data) else {
                    print("[ChatViewModel] could not decode image data (\(data.count) bytes)")
                    return
                }
                // Write to disk (L2) then populate memory (L1)
                ImageDiskCache.shared.write(image, for: url)
                print("[ChatViewModel] image cached to disk for id=\(id)")
                await MainActor.run { cacheImage(image, forId: id) }
            } catch {
                print("[ChatViewModel] image download failed: \(error)")
            }
        }
    }

    private func finishStream(assistantId: String, error: String?) {
        isStreaming        = false
        isSearching        = false
        isExtracting       = false
        isGeneratingImage  = false
        isInToolCallBlock  = false
        thinkingStart      = nil
        streamTask    = nil

        guard let idx = messages.firstIndex(where: { $0.id == assistantId }) else { return }
      
        messages[idx].isStreaming = false
        if let error {
            messages[idx].isError = true
            messages[idx].content = error
        }

        let bgManager = BackgroundStreamManager.shared
        if bgManager.isInBackground && error == nil {
            let title = conversationTitle ?? "MindChat"
            let preview = messages[idx].content
            NotificationManager.shared.notifyResponseReady(title: title, preview: preview)
            bgManager.streamDidComplete()
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

    // MARK: - Background Recovery

    private func handleForegroundReturn() {
        let bgManager = BackgroundStreamManager.shared
        guard bgManager.streamInterruptedByExpiry, let convId = conversationId else { return }

        stopStreaming()

        Task {
            do {
                messages = try await chat.messages(conversationId: convId)
                ToastManager.shared.info("Response loaded from server")
            } catch {
                print("[Background] Failed to recover messages: \(error)")
            }
        }
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
        formAnswers       = [:]
        submittedForms    = []
        smartSuggestions   = []
        suggestionsTask?.cancel()
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
            persona              = cached.persona
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
            persona              = s.persona
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
        updateModelRecommendation(for: inputText)
    }

    private func updateModelRecommendation(for text: String) {
        recommendationTask?.cancel()
        recommendationTask = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 12, trimmed.count <= 500 else {
            modelRecommendation = nil
            return
        }

        let snapshotPlan = plan
        let snapshotProvider = provider
        let snapshotModel = model

        recommendationTask = Task {
            let intent = await QueryIntentDetector.suggestModel(prompt: trimmed)
            guard !Task.isCancelled else { return }

            let rec: ModelRecommendation?
            if let intent {
                rec = QueryIntentDetector.recommend(
                    for: intent, plan: snapshotPlan,
                    currentProvider: snapshotProvider, currentModelId: snapshotModel
                )
            } else {
                rec = nil
            }

            guard !Task.isCancelled else { return }
            print("[ModelRec] intent=\(intent?.rawValue ?? "nil") plan=\(snapshotPlan.rawValue) provider=\(snapshotProvider.rawValue) → rec=\(rec?.modelId ?? "nil")")
            if rec != modelRecommendation { modelRecommendation = rec }
        }
    }

    // MARK: - Persona

    func updatePersona(_ p: PersonaType) async {
        persona = p
        try? await SettingsService.shared.updateSettings(
            SettingsUpdateRequest(persona: p)
        )
    }

    // MARK: - Suggestion

    func useSuggestion(_ text: String) {
        inputText = text
    }

    // MARK: - Smart Suggestions

    func loadSmartSuggestions() {
        guard smartSuggestions.isEmpty else { return }
        guard conversationId == nil, messages.isEmpty else { return }

        // Return cached suggestions immediately if still valid (20-min TTL)
        if let cached: [String] = CacheStore.shared.get(.suggestQuestions), !cached.isEmpty {
            print("[SmartSuggestions] cache hit (\(cached.count) suggestions)")
            smartSuggestions = cached
            return
        }

        suggestionsTask?.cancel()
        suggestionsTask = Task {
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let response: SuggestQuestionsResponse = try await APIClient.shared.request(
                    "/api/suggest-questions",
                    timeout: 8
                )
                let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                print("[SmartSuggestions] fetched \(response.suggestions.count) suggestions in \(ms)ms")
                guard !Task.isCancelled else { return }
                if !response.suggestions.isEmpty {
                    CacheStore.shared.set(.suggestQuestions, value: response.suggestions)
                    smartSuggestions = response.suggestions
                }
            } catch {
                let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                print("[SmartSuggestions] failed after \(ms)ms: \(error)")
            }
        }
    }

    // MARK: - Question Form

    func submitChoiceAnswer(messageId: String, answer: String) async {
        submittedForms.insert(messageId)
        inputText = answer
        await send()
    }

    func submitQuestionForm(messageId: String, form: QuestionForm) async {
        let answers = formAnswers[messageId] ?? [:]

        let combined = form.questions.map { question in
            let answer = answers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "\(question.label)\n\(answer.isEmpty ? "(skipped)" : answer)"
        }.joined(separator: "\n\n")

        submittedForms.insert(messageId)

        inputText = combined
        await send()
    }

    // MARK: - Topic Focus

    /// Detects an active `#query` in the input text.
    /// Returns the text after `#` when the hashtag is at the start of text or preceded by whitespace,
    /// and the user hasn't typed a space after the query (meaning they moved on).
    /// Returns nil when there's no active hashtag trigger.
    var activeHashtagQuery: String? {
        // Find the last occurrence of # that's at start or preceded by whitespace
        guard let hashRange = inputText.range(of: "(^|\\s)#", options: .regularExpression, range: inputText.startIndex..<inputText.endIndex) else {
            return nil
        }
        // Get the position right after the #
        let hashIndex = inputText.index(before: hashRange.upperBound)
        guard inputText[hashIndex] == "#" else { return nil }
        let afterHash = inputText[inputText.index(after: hashIndex)...]
        // If the query contains a space, the user moved on — no longer autocompleting
        if afterHash.contains(" ") { return nil }
        return String(afterHash)
    }

    /// Removes the `#query` from input text, sets topic focus, and fires haptic.
    func selectTopicFromAutocomplete(_ node: TopicTreeNode) {
        // Remove #query from inputText
        if let hashRange = inputText.range(of: "(^|\\s)#\\S*$", options: .regularExpression) {
            let prefix = inputText[inputText.startIndex..<hashRange.lowerBound]
            inputText = prefix.trimmingCharacters(in: .whitespaces)
        }
        topicFocus = TopicFocus(id: node.id, name: node.name, factCount: node.totalFactCount)
        Haptics.light()
    }

    /// Clears the topic focus and fires haptic.
    func clearTopicFocus() {
        topicFocus = nil
        Haptics.light()
    }

    func formAnswerBinding(messageId: String, questionId: String) -> Binding<String> {
        Binding(
            get: { self.formAnswers[messageId]?[questionId] ?? "" },
            set: { newValue in
                if self.formAnswers[messageId] == nil {
                    self.formAnswers[messageId] = [:]
                }
                self.formAnswers[messageId]?[questionId] = newValue
            }
        )
    }
}
