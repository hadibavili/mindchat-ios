import Foundation

// MARK: - Topic Service

@MainActor
final class TopicService {

    static let shared = TopicService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Tree

    func topicsTree() async throws -> [TopicTreeNode] {
        return try await api.request("/api/topics")
    }

    // MARK: - Topic Detail

    func topicDetail(id: String) async throws -> TopicDetailResponse {
        return try await api.request("/api/topics/\(id)")
    }

    func lookupTopic(path: String) async throws -> String {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        let response: TopicLookupResponse = try await api.request("/api/topics/lookup?path=\(encoded)")
        return response.id
    }

    // MARK: - Search

    func search(query: String, type: FactType? = nil, importance: FactImportance? = nil) async throws -> [SearchResult] {
        var path = "/api/topics/search?q=\(query.urlEncoded)"
        if let type { path += "&type=\(type.rawValue)" }
        if let importance { path += "&importance=\(importance.rawValue)" }
        return try await api.request(path)
    }

    // MARK: - Stats

    func stats() async throws -> TopicStatsResponse {
        return try await api.request("/api/topics/stats")
    }

    // MARK: - Merge

    func merge(sourceId: String, targetId: String) async throws {
        struct Body: Encodable {
            let sourceTopicId: String
            let targetTopicId: String
        }
        let _: SuccessResponse = try await api.request(
            "/api/topics/merge",
            method: "POST",
            body: Body(sourceTopicId: sourceId, targetTopicId: targetId)
        )
    }

    // MARK: - Facts

    func updateFact(id: String, content: String? = nil, pinned: Bool? = nil, confidence: Double? = nil) async throws -> Fact {
        let body = FactUpdateRequest(content: content, pinned: pinned, confidence: confidence)
        return try await api.request("/api/facts/\(id)", method: "PATCH", body: body)
    }

    func deleteFact(id: String) async throws {
        let _: SuccessResponse = try await api.request("/api/facts/\(id)", method: "DELETE")
    }
}

// MARK: - String URL Encoding Helper

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
