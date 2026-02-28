import Foundation

// MARK: - Chat Service

@MainActor
final class ChatService {

    static let shared = ChatService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Send (SSE)

    func send(
        message: String,
        conversationId: String?,
        provider: AIProvider,
        model: String,
        history: [HistoryMessage] = [],
        attachments: [PendingAttachment] = [],
        topicId: String? = nil
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let attachmentRefs = attachments.compactMap { att -> ChatRequest.AttachmentRef? in
            guard let url = att.uploadedURL else { return nil }
            return ChatRequest.AttachmentRef(
                url: url,
                name: att.name,
                type: att.kind == .image ? "image" : "file",
                mimeType: att.mimeType
            )
        }
        let body = ChatRequest(
            message: message,
            conversationId: conversationId,
            provider: provider,
            model: model,
            history: history.isEmpty ? nil : history,
            attachments: attachmentRefs.isEmpty ? nil : attachmentRefs,
            topicId: topicId
        )
        let bytes = try await api.sseRequest("/api/chat", body: body)
        return SSEParser.parse(bytes)
    }

    // MARK: - Messages

    func messages(conversationId: String, highlight: String? = nil) async throws -> [ChatMessage] {
        var path = "/api/messages?conversationId=\(conversationId)"
        if let hl = highlight { path += "&highlight=\(hl)" }
        let msgs: [CodableChatMessage] = try await api.request(path)
        return msgs.map { $0.toChatMessage() }
    }

    func clearMessages(conversationId: String) async throws {
        let _: SuccessResponse = try await api.request(
            "/api/messages?conversationId=\(conversationId)",
            method: "DELETE"
        )
    }

    // MARK: - Conversations

    func conversations() async throws -> [Conversation] {
        return try await api.request("/api/conversations")
    }

    func createConversation(title: String? = nil) async throws -> String {
        struct Body: Encodable { let title: String? }
        let response: CreateConversationResponse = try await api.request(
            "/api/conversations",
            method: "POST",
            body: Body(title: title)
        )
        return response.id
    }

    func conversation(id: String) async throws -> Conversation {
        return try await api.request("/api/conversations/\(id)")
    }

    func renameConversation(id: String, title: String) async throws {
        struct Body: Encodable { let title: String }
        let _: RenameConversationResponse = try await api.request(
            "/api/conversations/\(id)",
            method: "PATCH",
            body: Body(title: title)
        )
    }

    func deleteConversation(id: String) async throws {
        let _: SuccessResponse = try await api.request(
            "/api/conversations/\(id)",
            method: "DELETE"
        )
    }
}
