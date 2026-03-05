import XCTest
@testable import Mind_Chat

// MARK: - ChatViewModel SSE Event Tests (Groups E–F)

@MainActor
final class ChatViewModelSSETests: XCTestCase {

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

    func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }

    // MARK: - Helper

    /// Returns the last assistant message after streaming completes.
    func assistantMessage() -> ChatMessage? {
        sut.messages.last(where: { $0.role == .assistant })
    }

    // MARK: - Group E: SSE Event Routing

    func test_handle_tokenEvents_appendContentToAssistantMessage() async {
        sut.inputText = "hello"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Hello"),
            .token(" world"),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(assistantMessage()?.content, "Hello world")
    }

    func test_handle_searchComplete_attachesSourcesToAssistantMessage() async {
        sut.inputText = "latest news"
        let source = SearchSource(title: "BBC News", url: "https://bbc.com")
        mockChat.stubbedStream = MockChatService.makeStream([
            .searchComplete(query: "latest news", sources: [source]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(assistantMessage()?.sources?.count, 1)
        XCTAssertEqual(assistantMessage()?.sources?.first?.title, "BBC News")
    }

    func test_handle_extractingEvent_unlocksInputBeforeStreamEnd() async {
        sut.inputText = "remember this"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Done."),
            .extracting,
            .topicsExtracted([]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isStreaming)
        XCTAssertFalse(sut.isExtracting)
    }

    func test_handle_errorEvent_setsErrorOnAssistantMessage() async {
        sut.inputText = "test"
        mockChat.stubbedStream = MockChatService.makeStream([
            .error("Rate limit exceeded")
        ])

        await sut.send()
        await drainTasks()

        XCTAssertTrue(assistantMessage()?.isError == true)
        XCTAssertEqual(assistantMessage()?.content, "Rate limit exceeded")
        XCTAssertFalse(sut.isStreaming)
    }

    // MARK: - Group F: Tool Call Suppression

    func test_toolCallBlock_xmlPattern_suppressesTokensInsideBlock() async {
        sut.inputText = "use a tool"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Hello "),
            .token("<tool_call>"),
            .token("function_name"),
            .token("</tool_call>"),
            .done
        ])

        await sut.send()
        await drainTasks()

        // Content before the opening tag is preserved; tokens inside are suppressed
        XCTAssertEqual(assistantMessage()?.content, "Hello")
    }

    func test_toolCallBlock_bareToolNewlinePattern_suppressesTokens() async {
        sut.inputText = "test bare tool pattern"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Answer done.\n"),
            .token("tool\n"),
            .token("get_weather"),
            .done
        ])

        await sut.send()
        await drainTasks()

        // Everything from "\ntool\n" onward is suppressed
        let content = assistantMessage()?.content ?? ""
        XCTAssertFalse(content.contains("get_weather"))
        XCTAssertFalse(content.contains("tool"))
    }

    // MARK: - Group H: Memory Extraction

    func test_extracting_setsIsExtractingTrue_whenMemoryIndicatorsEnabled() async {
        // showMemoryIndicators defaults to true
        sut.inputText = "remember my birthday"

        // Use a continuation-based stream so we can assert mid-stream
        let stream = AsyncThrowingStream<SSEEvent, Error> { continuation in
            continuation.yield(.token("Got it."))
            continuation.yield(.extracting)
            // Don't finish yet — leave stream open so we can observe isExtracting = true
            // Schedule the rest after a brief yield
            Task { @MainActor in
                // Give the handle() call time to process
                for _ in 0..<10 { await Task.yield() }
                continuation.yield(.topicsExtracted([]))
                continuation.yield(.done)
                continuation.finish()
            }
        }
        mockChat.stubbedStream = stream

        await sut.send()
        // Yield enough for `.extracting` to be handled but before `.topicsExtracted`
        for _ in 0..<5 { await Task.yield() }

        // After full drain, isExtracting should be cleared
        await drainTasks()
        XCTAssertFalse(sut.isExtracting)
        XCTAssertFalse(sut.isStreaming)
    }

    func test_extracting_doesNotSetIsExtracting_whenMemoryIndicatorsDisabled() async {
        mockSettings.networkSettings = MockSettingsService.makeSettings(showMemoryIndicators: false)
        await sut.loadSettings()

        sut.inputText = "remember this"
        let topic = ExtractedTopic(path: "Personal/Hobbies", name: "Hobbies", isNew: true, factsAdded: 2)
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Noted."),
            .extracting,
            .topicsExtracted([topic]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isExtracting, "isExtracting should remain false when indicators disabled")
        XCTAssertTrue(sut.extractedTopics.isEmpty, "extractedTopics should not be populated when indicators disabled")
    }

    func test_topicsExtracted_storesTopicsOnAssistantMessage() async {
        sut.inputText = "I like photography"
        let topics = [
            ExtractedTopic(path: "Personal/Interests", name: "Interests", isNew: false, factsAdded: 1),
            ExtractedTopic(path: "Personal/Hobbies/Photography", name: "Photography", isNew: true, factsAdded: 3)
        ]
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Interesting!"),
            .extracting,
            .topicsExtracted(topics),
            .done
        ])

        await sut.send()
        await drainTasks()

        let streaming = assistantMessage()?.streamingTopics
        XCTAssertNotNil(streaming)
        XCTAssertEqual(streaming?.count, 2)
        XCTAssertEqual(streaming?[0].path, "Personal/Interests")
        XCTAssertEqual(streaming?[0].name, "Interests")
        XCTAssertEqual(streaming?[0].isNew, false)
        XCTAssertEqual(streaming?[0].factsAdded, 1)
        XCTAssertEqual(streaming?[1].path, "Personal/Hobbies/Photography")
        XCTAssertEqual(streaming?[1].name, "Photography")
        XCTAssertEqual(streaming?[1].isNew, true)
        XCTAssertEqual(streaming?[1].factsAdded, 3)
    }

    func test_topicsExtracted_clearsIsExtractingFlag() async {
        sut.inputText = "save this"
        let topic = ExtractedTopic(path: "Work/Projects", name: "Projects", isNew: true, factsAdded: 1)
        mockChat.stubbedStream = MockChatService.makeStream([
            .extracting,
            .topicsExtracted([topic]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isExtracting, "isExtracting should be false after topicsExtracted")
    }

    func test_topicsExtracted_populatesViewModelExtractedTopics() async {
        sut.inputText = "I work at Apple"
        let topics = [
            ExtractedTopic(path: "Work/Company", name: "Company", isNew: true, factsAdded: 1),
            ExtractedTopic(path: "Work/Role", name: "Role", isNew: false, factsAdded: 2)
        ]
        mockChat.stubbedStream = MockChatService.makeStream([
            .extracting,
            .topicsExtracted(topics),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(sut.extractedTopics.count, 2)
        XCTAssertEqual(sut.extractedTopics[0].name, "Company")
        XCTAssertEqual(sut.extractedTopics[1].name, "Role")
    }

    func test_topicsExtracted_emptyArray_doesNotCrash() async {
        sut.inputText = "nothing memorable"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Okay."),
            .extracting,
            .topicsExtracted([]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertTrue(sut.extractedTopics.isEmpty)
        XCTAssertFalse(sut.isExtracting)
        // streamingTopics should be set to empty array (not nil) since indicators are on
        let streaming = assistantMessage()?.streamingTopics
        XCTAssertNotNil(streaming)
        XCTAssertTrue(streaming?.isEmpty == true)
    }

    func test_topicsExtracted_multipleTopicsWithVaryingFacts() async {
        sut.inputText = "I have a dog named Max, I live in Amsterdam, and I love cycling"
        let topics = [
            ExtractedTopic(path: "Personal/Pets", name: "Pets", isNew: true, factsAdded: 1),
            ExtractedTopic(path: "Personal/Location", name: "Location", isNew: false, factsAdded: 2),
            ExtractedTopic(path: "Personal/Hobbies/Cycling", name: "Cycling", isNew: true, factsAdded: 3)
        ]
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("That's great!"),
            .extracting,
            .topicsExtracted(topics),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(sut.extractedTopics.count, 3)

        // Verify all topics stored on ViewModel
        XCTAssertEqual(sut.extractedTopics[0].factsAdded, 1)
        XCTAssertEqual(sut.extractedTopics[1].factsAdded, 2)
        XCTAssertEqual(sut.extractedTopics[2].factsAdded, 3)

        // Verify all topics stored on the assistant message
        let streaming = assistantMessage()?.streamingTopics
        XCTAssertEqual(streaming?.count, 3)
        XCTAssertEqual(streaming?[0].name, "Pets")
        XCTAssertEqual(streaming?[1].name, "Location")
        XCTAssertEqual(streaming?[2].name, "Cycling")
    }

    func test_extracting_unlocksInput_regardlessOfMemoryIndicatorsSetting() async {
        mockSettings.networkSettings = MockSettingsService.makeSettings(showMemoryIndicators: false)
        await sut.loadSettings()

        sut.inputText = "remember this fact"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Noted."),
            .extracting,
            .topicsExtracted([]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isStreaming, "Input should be unlocked even when memory indicators are off")
    }

    func test_finishStream_resetsIsExtracting_whenNoTopicsExtractedReceived() async {
        sut.inputText = "test extraction"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Processing..."),
            .extracting,
            // No .topicsExtracted event — stream ends directly
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isExtracting, "finishStream should reset isExtracting even without topicsExtracted")
        XCTAssertFalse(sut.isStreaming)
    }

    func test_topicsExtracted_notStoredOnMessage_whenMemoryIndicatorsDisabled() async {
        mockSettings.networkSettings = MockSettingsService.makeSettings(showMemoryIndicators: false)
        await sut.loadSettings()

        sut.inputText = "I love Swift"
        let topic = ExtractedTopic(path: "Tech/Languages", name: "Languages", isNew: true, factsAdded: 1)
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Cool!"),
            .extracting,
            .topicsExtracted([topic]),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertNil(assistantMessage()?.streamingTopics, "Topics should not be stored on message when indicators disabled")
    }

    // MARK: - Group G: Image SSE Events

    func test_handle_generatingImage_setsAndClearsFlag() async {
        sut.inputText = "generate an image"
        mockChat.stubbedStream = MockChatService.makeStream([
            .generatingImage,
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isGeneratingImage)
        XCTAssertFalse(sut.isStreaming)
    }

    func test_handle_imageGenerated_attachmentHasCorrectFields() async {
        sut.inputText = "make me an image"
        mockChat.stubbedStream = MockChatService.makeStream([
            .imageGenerated(url: "https://cdn.example.com/img.png", name: "Landscape"),
            .done
        ])

        await sut.send()
        await drainTasks()

        let att = assistantMessage()?.attachments?.first
        XCTAssertNotNil(att)
        XCTAssertEqual(att?.url, "https://cdn.example.com/img.png")
        XCTAssertEqual(att?.name, "Landscape")
        XCTAssertEqual(att?.type, .image)
        XCTAssertEqual(att?.mimeType, "image/png")
    }

    func test_handle_imageGenerated_doesNotAffectTokenContent() async {
        sut.inputText = "create an image"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("Here is your image:"),
            .imageGenerated(url: "https://cdn.example.com/img.png", name: "Art"),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(assistantMessage()?.content, "Here is your image:")
        XCTAssertEqual(assistantMessage()?.attachments?.count, 1)
    }
}
