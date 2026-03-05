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
            .token("Answer: "),
            .token("tool\n"),
            .token("get_weather"),
            .done
        ])

        await sut.send()
        await drainTasks()

        // Everything from "tool\n" onward is suppressed
        let content = assistantMessage()?.content ?? ""
        XCTAssertFalse(content.contains("get_weather"))
        XCTAssertFalse(content.contains("tool"))
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
