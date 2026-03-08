import Foundation
@testable import Mind_Chat

// MARK: - Mock Topic Service

@MainActor
final class MockTopicService: TopicServiceProtocol {

    // MARK: - Stubs
    var stubbedTree: [TopicTreeNode] = []
    var stubbedTreeError: Error?
    var stubbedStats: TopicStatsResponse?
    var stubbedStatsError: Error?

    // MARK: - Call Tracking
    var topicsTreeCallCount = 0
    var statsCallCount = 0

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

    // MARK: - Helpers

    static func makeNode(
        id: String = "node-1",
        name: String = "Health",
        factCount: Int = 0,
        children: [TopicTreeNode] = []
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
            updatedAt: nil,
            children: children,
            factCount: factCount
        )
    }

    static func makeStats(totalTopics: Int = 5, totalFacts: Int = 12) -> TopicStatsResponse {
        TopicStatsResponse(
            totalTopics: totalTopics,
            totalFacts: totalFacts,
            factsByType: FactTypeCounts(fact: 0, preference: 0, goal: 0, experience: 0),
            recentlyUpdated: [],
            topByFactCount: []
        )
    }
}
