import XCTest
@testable import Mind_Chat

// MARK: - CacheStore Tests

@MainActor
final class CacheStoreTests: XCTestCase {

    override func setUp() async throws {
        CacheStore.shared.invalidateAll()
    }

    override func tearDown() async throws {
        CacheStore.shared.invalidateAll()
    }

    // MARK: - Set/Get

    func test_setAndGet_topicsTree() {
        let nodes = [
            MockTopicService.makeNode(id: "t1", name: "Health"),
            MockTopicService.makeNode(id: "t2", name: "Work")
        ]
        CacheStore.shared.set(.topicsTree, value: nodes)

        let result: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?.first?.name, "Health")
    }

    func test_setAndGet_topicsStats() {
        let stats = MockTopicService.makeStats(totalTopics: 10, totalFacts: 50)
        CacheStore.shared.set(.topicsStats, value: stats)

        let result: TopicStatsResponse? = CacheStore.shared.get(.topicsStats)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalTopics, 10)
        XCTAssertEqual(result?.totalFacts, 50)
    }

    func test_setAndGet_topicDetail() {
        let detail = MockTopicService.makeDetail(id: "t1", name: "Health")
        CacheStore.shared.set(.topicDetail(id: "t1"), value: detail)

        let result: TopicDetailResponse? = CacheStore.shared.get(.topicDetail(id: "t1"))

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Health")
    }

    func test_get_returnsNil_whenNotSet() {
        let result: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)

        XCTAssertNil(result)
    }

    // MARK: - Invalidation

    func test_invalidate_removesEntry() {
        CacheStore.shared.set(.topicsTree, value: [MockTopicService.makeNode()])

        CacheStore.shared.invalidate(.topicsTree)

        let result: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)
        XCTAssertNil(result)
    }

    func test_invalidateAllTopicDetails_removesAllDetailEntries() {
        CacheStore.shared.set(.topicDetail(id: "t1"), value: MockTopicService.makeDetail(id: "t1"))
        CacheStore.shared.set(.topicDetail(id: "t2"), value: MockTopicService.makeDetail(id: "t2"))
        CacheStore.shared.set(.topicsTree, value: [MockTopicService.makeNode()])

        CacheStore.shared.invalidateAllTopicDetails()

        let d1: TopicDetailResponse? = CacheStore.shared.get(.topicDetail(id: "t1"))
        let d2: TopicDetailResponse? = CacheStore.shared.get(.topicDetail(id: "t2"))
        let tree: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)

        XCTAssertNil(d1)
        XCTAssertNil(d2)
        XCTAssertNotNil(tree) // Tree should survive
    }

    func test_invalidateAll_removesEverything() {
        CacheStore.shared.set(.topicsTree, value: [MockTopicService.makeNode()])
        CacheStore.shared.set(.topicsStats, value: MockTopicService.makeStats())
        CacheStore.shared.set(.topicDetail(id: "t1"), value: MockTopicService.makeDetail())

        CacheStore.shared.invalidateAll()

        let tree: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)
        let stats: TopicStatsResponse? = CacheStore.shared.get(.topicsStats)
        let detail: TopicDetailResponse? = CacheStore.shared.get(.topicDetail(id: "t1"))

        XCTAssertNil(tree)
        XCTAssertNil(stats)
        XCTAssertNil(detail)
    }

    // MARK: - Cache Key Properties

    func test_cacheKey_ttl_valuesAreReasonable() {
        XCTAssertEqual(CacheKey.topicsTree.ttl, 86400, accuracy: 1)
        XCTAssertEqual(CacheKey.topicsStats.ttl, 86400, accuracy: 1)
        XCTAssertEqual(CacheKey.topicDetail(id: "x").ttl, 86400, accuracy: 1)
    }

    func test_cacheKey_rawKey_uniqueness() {
        let keys: [CacheKey] = [
            .conversations, .topicsTree, .topicsStats,
            .topicDetail(id: "a"), .topicDetail(id: "b"),
            .settings, .usage, .suggestQuestions
        ]
        let rawKeys = keys.map(\.rawKey)
        let uniqueKeys = Set(rawKeys)

        XCTAssertEqual(rawKeys.count, uniqueKeys.count, "All cache keys must have unique rawKey values")
    }

    func test_topicDetail_differentIds_differentKeys() {
        let key1 = CacheKey.topicDetail(id: "a")
        let key2 = CacheKey.topicDetail(id: "b")

        XCTAssertNotEqual(key1.rawKey, key2.rawKey)
    }
}
