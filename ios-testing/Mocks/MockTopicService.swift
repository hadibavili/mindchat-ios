import Foundation
@testable import Mind_Chat

// MARK: - Mock Topic Service

@MainActor
final class MockTopicService: TopicServiceProtocol {

    // MARK: - Tree Stubs
    var stubbedTree: [TopicTreeNode] = []
    var stubbedTreeError: Error?
    var topicsTreeCallCount = 0

    // MARK: - Stats Stubs
    var stubbedStats: TopicStatsResponse?
    var stubbedStatsError: Error?
    var statsCallCount = 0

    // MARK: - Detail Stubs
    var stubbedDetail: TopicDetailResponse?
    var stubbedDetailError: Error?
    var topicDetailCallCount = 0
    var lastDetailId: String?

    // MARK: - Search Stubs
    var stubbedSearchResults: [SearchResult] = []
    var stubbedSearchError: Error?
    var searchCallCount = 0
    var lastSearchQuery: String?
    var lastSearchType: FactType?
    var lastSearchImportance: FactImportance?

    // MARK: - Merge Stubs
    var stubbedMergeError: Error?
    var mergeCallCount = 0
    var lastMergeSourceId: String?
    var lastMergeTargetId: String?

    // MARK: - Update Fact Stubs
    var stubbedUpdatedFact: Fact?
    var stubbedUpdateError: Error?
    var updateFactCallCount = 0
    var lastUpdateId: String?
    var lastUpdateContent: String?
    var lastUpdatePinned: Bool?
    var lastUpdateConfidence: Double?

    // MARK: - Delete Fact Stubs
    var stubbedDeleteError: Error?
    var deleteFactCallCount = 0
    var lastDeleteId: String?

    // MARK: - TopicServiceProtocol

    func topicsTree() async throws -> [TopicTreeNode] {
        topicsTreeCallCount += 1
        if let error = stubbedTreeError { throw error }
        return stubbedTree
    }

    func stats() async throws -> TopicStatsResponse {
        statsCallCount += 1
        if let error = stubbedStatsError { throw error }
        return stubbedStats ?? MockTopicService.makeStats()
    }

    func topicDetail(id: String) async throws -> TopicDetailResponse {
        topicDetailCallCount += 1
        lastDetailId = id
        if let error = stubbedDetailError { throw error }
        return stubbedDetail ?? MockTopicService.makeDetail(id: id)
    }

    func search(query: String, type: FactType?, importance: FactImportance?) async throws -> [SearchResult] {
        searchCallCount += 1
        lastSearchQuery = query
        lastSearchType = type
        lastSearchImportance = importance
        if let error = stubbedSearchError { throw error }
        return stubbedSearchResults
    }

    func merge(sourceId: String, targetId: String) async throws {
        mergeCallCount += 1
        lastMergeSourceId = sourceId
        lastMergeTargetId = targetId
        if let error = stubbedMergeError { throw error }
    }

    func updateFact(id: String, content: String?, pinned: Bool?, confidence: Double?) async throws -> Fact {
        updateFactCallCount += 1
        lastUpdateId = id
        lastUpdateContent = content
        lastUpdatePinned = pinned
        lastUpdateConfidence = confidence
        if let error = stubbedUpdateError { throw error }
        return stubbedUpdatedFact ?? MockTopicService.makeFact(id: id, content: content ?? "updated", pinned: pinned ?? false)
    }

    func deleteFact(id: String) async throws {
        deleteFactCallCount += 1
        lastDeleteId = id
        if let error = stubbedDeleteError { throw error }
    }

    // MARK: - Factory Helpers

    static func makeNode(
        id: String = "node-1",
        name: String = "Health",
        factCount: Int = 0,
        children: [TopicTreeNode] = [],
        updatedAt: Date? = nil
    ) -> TopicTreeNode {
        TopicTreeNode(
            id: id,
            name: name,
            path: name.lowercased(),
            summary: nil,
            icon: "heart",
            slug: name.lowercased(),
            depth: 1,
            createdAt: nil,
            updatedAt: updatedAt,
            children: children,
            factCount: factCount
        )
    }

    static func makeStats(
        totalTopics: Int = 5,
        totalFacts: Int = 12,
        factsByType: FactTypeCounts = FactTypeCounts(fact: 6, preference: 3, goal: 2, experience: 1),
        recentlyUpdated: [TopicWithStats] = [],
        topByFactCount: [TopicWithStats] = []
    ) -> TopicStatsResponse {
        TopicStatsResponse(
            totalTopics: totalTopics,
            totalFacts: totalFacts,
            factsByType: factsByType,
            recentlyUpdated: recentlyUpdated,
            topByFactCount: topByFactCount
        )
    }

    static func makeFact(
        id: String = "fact-1",
        content: String = "Test fact content",
        type: FactType = .fact,
        topicId: String = "topic-1",
        pinned: Bool = false,
        importance: FactImportance? = .medium,
        confidence: Double? = 85,
        createdAt: Date = Date(),
        sourceMessageId: String? = nil,
        sourceConversationId: String? = nil
    ) -> Fact {
        Fact(
            id: id,
            content: content,
            type: type,
            topicId: topicId,
            pinned: pinned,
            confidence: confidence,
            importance: importance,
            createdAt: createdAt,
            sourceMessageId: sourceMessageId,
            sourceConversationId: sourceConversationId
        )
    }

    static func makeTopicWithStats(
        id: String = "topic-1",
        name: String = "Health",
        factCount: Int = 3,
        summary: String? = nil,
        icon: String? = "heart",
        updatedAt: Date? = nil
    ) -> TopicWithStats {
        TopicWithStats(
            id: id, name: name, path: name.lowercased(),
            summary: summary, icon: icon,
            slug: name.lowercased(), depth: 1,
            createdAt: nil, updatedAt: updatedAt,
            factCount: factCount, subtopicCount: 0
        )
    }

    static func makeDetail(
        id: String = "topic-1",
        name: String = "Health",
        facts: [Fact]? = nil,
        children: [TopicWithStats] = [],
        parentTopic: TopicWithStats? = nil,
        relatedTopics: [RelatedTopic]? = nil
    ) -> TopicDetailResponse {
        let defaultFacts = facts ?? [
            makeFact(id: "f1", content: "Fact 1", type: .fact, topicId: id),
            makeFact(id: "f2", content: "Fact 2", type: .preference, topicId: id),
            makeFact(id: "f3", content: "Fact 3", type: .goal, topicId: id)
        ]
        return TopicDetailResponse(
            id: id, name: name, path: name.lowercased(),
            summary: "Summary for \(name)", icon: "heart",
            slug: name.lowercased(), depth: 1,
            createdAt: Date(), updatedAt: Date(),
            facts: defaultFacts, children: children,
            parentTopic: parentTopic, relatedTopics: relatedTopics
        )
    }

    static func makeSearchResult(
        type: SearchResult.ResultType = .fact,
        topicId: String = "topic-1",
        topicName: String = "Health",
        topicPath: String = "health",
        topicIcon: String? = "heart",
        factId: String? = "fact-1",
        factContent: String? = "Some fact",
        factType: FactType? = .fact,
        importance: FactImportance? = .medium
    ) -> SearchResult {
        SearchResult(
            type: type,
            topicId: topicId,
            topicName: topicName,
            topicPath: topicPath,
            topicIcon: topicIcon,
            createdAt: Date(),
            factId: type == .fact ? factId : nil,
            factContent: type == .fact ? factContent : nil,
            factType: type == .fact ? factType : nil,
            importance: type == .fact ? importance : nil
        )
    }
}
