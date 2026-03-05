import Foundation
@testable import Mind_Chat

// MARK: - Mock Chat Service

@MainActor
final class MockChatService: ChatServiceProtocol {

    // MARK: - Call Tracking
    var sendCallCount = 0
    var lastSentMessage: String?
    var lastSentConversationId: String?

    var messagesCallCount = 0
    var lastMessagesConversationId: String?

    var clearMessagesCallCount = 0

    // MARK: - Stubs
    var stubbedMessages: [ChatMessage] = []
    var stubbedMessagesError: Error?
    var stubbedStream: AsyncThrowingStream<SSEEvent, Error>?
    var stubbedSendError: Error?

    // MARK: - ChatServiceProtocol

    func send(
        message: String,
        conversationId: String?,
        provider: AIProvider,
        model: String,
        history: [HistoryMessage],
        attachments: [PendingAttachment],
        topicId: String?
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        sendCallCount += 1
        lastSentMessage = message
        lastSentConversationId = conversationId
        if let error = stubbedSendError { throw error }
        return stubbedStream ?? AsyncThrowingStream { $0.finish() }
    }

    func messages(conversationId: String, highlight: String?) async throws -> [ChatMessage] {
        messagesCallCount += 1
        lastMessagesConversationId = conversationId
        if let error = stubbedMessagesError { throw error }
        return stubbedMessages
    }

    func clearMessages(conversationId: String) async throws {
        clearMessagesCallCount += 1
    }

    // MARK: - Helpers

    static func makeStream(_ events: [SSEEvent]) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}
