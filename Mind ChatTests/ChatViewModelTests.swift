import XCTest
@testable import Mind_Chat

// MARK: - ChatViewModel Tests (Groups A–D)

@MainActor
final class ChatViewModelTests: XCTestCase {

    var sut: ChatViewModel!
    var mockChat: MockChatService!
    var mockSettings: MockSettingsService!

    override func setUp() async throws {
        mockChat = MockChatService()
        mockSettings = MockSettingsService()
        sut = ChatViewModel(chat: mockChat, settings: mockSettings)
    }

    override func tearDown() async throws {
        sut.stopStreaming()
        sut = nil
        mockChat = nil
        mockSettings = nil
    }

    /// Yields the main run loop multiple times so detached stream tasks can complete.
    func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }

    // MARK: - Group A: newChat()

    func test_newChat_clearsMessagesAndConversationId() {
        sut.messages = [ChatMessage(content: "hello", role: .user)]
        sut.conversationId = "conv-1"
        sut.conversationTitle = "Old title"
        sut.inputText = "draft"

        sut.newChat()

        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNil(sut.conversationId)
        XCTAssertNil(sut.conversationTitle)
        XCTAssertEqual(sut.inputText, "")
    }

    func test_newChat_clearsFormStateAndTopicFocus() {
        sut.formAnswers = ["msg1": ["q1": "some answer"]]
        sut.submittedForms = ["msg1"]
        sut.topicFocus = TopicFocus(id: "t1", name: "Health", factCount: 3)

        sut.newChat()

        XCTAssertTrue(sut.formAnswers.isEmpty)
        XCTAssertTrue(sut.submittedForms.isEmpty)
        XCTAssertNil(sut.topicFocus)
    }

    // MARK: - Group B: loadSettings()

    func test_loadSettings_usesDefaultsWhenCacheIsNil() async {
        mockSettings.cachedSettings = nil
        mockSettings.cachedUsage = nil
        mockSettings.networkSettings = MockSettingsService.makeSettings(
            provider: .claude,
            model: "claude-haiku-4-5-20251001",
            plan: .pro
        )
        mockSettings.networkUsage = MockSettingsService.makeUsage(plan: .pro)

        await sut.loadSettings()

        XCTAssertEqual(sut.provider, .claude)
        XCTAssertEqual(sut.model, "claude-haiku-4-5-20251001")
        XCTAssertEqual(sut.plan, .pro)
        XCTAssertEqual(mockSettings.getSettingsCallCount, 1)
    }

    func test_loadSettings_networkOverridesCachedValues() async {
        mockSettings.cachedSettings = MockSettingsService.makeSettings(plan: .pro, model: "gpt-4.1")
        mockSettings.networkSettings = MockSettingsService.makeSettings(plan: .free, model: "gpt-4.1-mini")
        mockSettings.networkUsage = MockSettingsService.makeUsage()

        await sut.loadSettings()

        // Network response should win
        XCTAssertEqual(sut.plan, .free)
        XCTAssertEqual(sut.model, "gpt-4.1-mini")
    }

    func test_loadSettings_setsVoiceAndImageUploadsFromUsage() async {
        mockSettings.networkSettings = MockSettingsService.makeSettings()
        mockSettings.networkUsage = MockSettingsService.makeUsage(voice: true, imageUploads: true)

        await sut.loadSettings()

        XCTAssertTrue(sut.voiceEnabled)
        XCTAssertTrue(sut.imageUploadsEnabled)
    }

    func test_loadSettings_networkFailurePreservesCache() async {
        mockSettings.cachedSettings = MockSettingsService.makeSettings(plan: .premium)
        mockSettings.networkSettingsError = AppError.networkError("timeout")
        mockSettings.networkUsageError = AppError.networkError("timeout")

        await sut.loadSettings()

        // Cache value must survive the network failure
        XCTAssertEqual(sut.plan, .premium)
        // Settings errors are swallowed silently (per existing behavior)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Group C: loadMessages()

    func test_loadMessages_populatesMessagesAndSetsConversationId() async {
        mockChat.stubbedMessages = [
            ChatMessage(content: "Hello", role: .user),
            ChatMessage(content: "Hi there!", role: .assistant)
        ]

        await sut.loadMessages(conversationId: "conv-abc")

        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.conversationId, "conv-abc")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadMessages_withHighlight_setsHighlightMessageId() async {
        let msg = ChatMessage(id: "msg-42", content: "Important!", role: .assistant)
        mockChat.stubbedMessages = [msg]

        await sut.loadMessages(conversationId: "conv-1", highlight: "msg-42")

        XCTAssertEqual(sut.highlightMessageId, "msg-42")
    }

    func test_loadMessages_setsErrorMessageOnFailure() async {
        mockChat.stubbedMessagesError = AppError.serverError("Internal error")

        await sut.loadMessages(conversationId: "conv-bad")

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Group D: send() State Transitions

    func test_send_emptyInputDoesNotCallChatService() async {
        sut.inputText = "   "

        await sut.send()
        await drainTasks()

        XCTAssertEqual(mockChat.sendCallCount, 0)
        XCTAssertFalse(sut.isStreaming)
    }

    func test_send_appendsOptimisticUserMessage() async {
        sut.inputText = "Hello world"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()

        // User message is appended synchronously before the detached task starts
        XCTAssertTrue(sut.messages.contains(where: {
            $0.role == .user && $0.content == "Hello world"
        }))
    }

    func test_send_clearsInputTextImmediately() async {
        sut.inputText = "test message"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()

        // inputText is cleared synchronously within send() before any await
        XCTAssertEqual(sut.inputText, "")
    }

    func test_send_setsIsStreamingFalseAfterDone() async {
        sut.inputText = "ping"
        mockChat.stubbedStream = MockChatService.makeStream([
            .conversationId("new-conv-id"),
            .token("Hello"),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isStreaming)
        XCTAssertEqual(sut.conversationId, "new-conv-id")
    }

    // MARK: - Group F: Utility Logic

    func test_activeHashtagQuery_returnsQueryAfterHash() {
        sut.inputText = "Tell me about #health"
        XCTAssertEqual(sut.activeHashtagQuery, "health")
    }

    func test_activeHashtagQuery_returnsNilWithNoHash() {
        sut.inputText = "no hashtag here"
        XCTAssertNil(sut.activeHashtagQuery)
    }

    func test_activeHashtagQuery_returnsNilWhenSpaceAfterHash() {
        sut.inputText = "#done typing more"
        XCTAssertNil(sut.activeHashtagQuery)
    }

    func test_selectTopicFromAutocomplete_setsTopicFocusAndClearsHashtag() {
        sut.inputText = "Focus on #work"
        let node = TopicTreeNode(
            id: "topic-1", name: "Work", path: "work",
            summary: nil, icon: nil, slug: nil, depth: 0,
            createdAt: nil, updatedAt: nil,
            children: [], factCount: 5
        )

        sut.selectTopicFromAutocomplete(node)

        XCTAssertEqual(sut.topicFocus?.id, "topic-1")
        XCTAssertEqual(sut.topicFocus?.name, "Work")
        XCTAssertFalse(sut.inputText.contains("#"))
    }

    func test_clearTopicFocus_removesTopicFocus() {
        sut.topicFocus = TopicFocus(id: "t1", name: "Health", factCount: 3)

        sut.clearTopicFocus()

        XCTAssertNil(sut.topicFocus)
    }
}
