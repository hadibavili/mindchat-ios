import XCTest
@testable import Mind_Chat

// MARK: - TopicsViewModel Tests

@MainActor
final class TopicsViewModelTests: XCTestCase {

    var sut: TopicsViewModel!
    var mockService: MockTopicService!

    override func setUp() async throws {
        mockService = MockTopicService()
        sut = TopicsViewModel(topicService: mockService)
        CacheStore.shared.invalidate(.topicsTree)
        CacheStore.shared.invalidate(.topicsStats)
    }

    override func tearDown() async throws {
        sut = nil
        mockService = nil
    }

    // MARK: - load()

    func test_load_populatesRootTopicsFromService() async {
        mockService.stubbedTree = [
            MockTopicService.makeNode(id: "1", name: "Health"),
            MockTopicService.makeNode(id: "2", name: "Work")
        ]

        await sut.load()

        XCTAssertEqual(sut.rootTopics.count, 2)
        XCTAssertEqual(sut.rootTopics[0].name, "Health")
        XCTAssertEqual(sut.rootTopics[1].name, "Work")
    }

    func test_load_callsServiceOnce() async {
        await sut.load()

        XCTAssertEqual(mockService.topicsTreeCallCount, 1)
    }

    func test_load_setsErrorMessageOnFailure() async {
        mockService.stubbedTreeError = AppError.serverError("Boom")

        await sut.load()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.rootTopics.isEmpty)
    }

    func test_load_clearsErrorOnSuccess() async {
        mockService.stubbedTreeError = AppError.serverError("First load failed")
        await sut.load()
        XCTAssertNotNil(sut.errorMessage)

        mockService.stubbedTreeError = nil
        mockService.stubbedTree = [MockTopicService.makeNode()]
        await sut.refresh()

        XCTAssertNil(sut.errorMessage)
    }

    func test_load_usesCache_doesNotCallService() async {
        let cached = [MockTopicService.makeNode(id: "cached", name: "Cached")]
        CacheStore.shared.set(.topicsTree, value: cached)

        await sut.load()

        XCTAssertEqual(mockService.topicsTreeCallCount, 0)
        XCTAssertEqual(sut.rootTopics.first?.name, "Cached")
    }

    func test_load_setsIsLoadingFalseAfterCompletion() async {
        await sut.load()

        XCTAssertFalse(sut.isLoading)
    }

    func test_load_populatesStatsFromService() async {
        mockService.stubbedStats = MockTopicService.makeStats(totalTopics: 10, totalFacts: 50)

        await sut.load()

        XCTAssertNotNil(sut.stats)
        XCTAssertEqual(sut.stats?.totalTopics, 10)
        XCTAssertEqual(sut.stats?.totalFacts, 50)
    }

    func test_load_usesBothCaches_doesNotCallEitherService() async {
        let cachedTree = [MockTopicService.makeNode(id: "c1")]
        let cachedStats = MockTopicService.makeStats(totalTopics: 3, totalFacts: 9)
        CacheStore.shared.set(.topicsTree, value: cachedTree)
        CacheStore.shared.set(.topicsStats, value: cachedStats)

        await sut.load()

        XCTAssertEqual(mockService.topicsTreeCallCount, 0)
        XCTAssertEqual(mockService.statsCallCount, 0)
        XCTAssertEqual(sut.rootTopics.count, 1)
    }

    func test_load_statsFailure_stillPopulatesTree() async {
        mockService.stubbedTree = [MockTopicService.makeNode(id: "1")]
        mockService.stubbedStatsError = AppError.serverError("stats down")

        await sut.load()

        XCTAssertEqual(sut.rootTopics.count, 1)
        XCTAssertNil(sut.stats)
    }

    // MARK: - refresh()

    func test_refresh_alwaysCallsService() async {
        let cached = [MockTopicService.makeNode(id: "cached")]
        CacheStore.shared.set(.topicsTree, value: cached)

        await sut.refresh()

        XCTAssertEqual(mockService.topicsTreeCallCount, 1)
    }

    func test_refresh_updatesRootTopics() async {
        mockService.stubbedTree = [MockTopicService.makeNode(id: "fresh", name: "Fresh")]

        await sut.refresh()

        XCTAssertEqual(sut.rootTopics.first?.id, "fresh")
    }

    func test_refresh_alsoRefreshesStats() async {
        mockService.stubbedStats = MockTopicService.makeStats(totalTopics: 20, totalFacts: 100)

        await sut.refresh()

        XCTAssertEqual(mockService.statsCallCount, 1)
        XCTAssertEqual(sut.stats?.totalTopics, 20)
    }

    func test_refresh_errorOnTree_setsErrorMessage() async {
        mockService.stubbedTreeError = AppError.serverError("refresh failed")

        await sut.refresh()

        XCTAssertNotNil(sut.errorMessage)
    }

    func test_refresh_errorOnTree_doesNotClearExistingTopics() async {
        // First, load successfully
        mockService.stubbedTree = [MockTopicService.makeNode(id: "1", name: "Original")]
        await sut.refresh()
        XCTAssertEqual(sut.rootTopics.count, 1)

        // Now refresh fails
        mockService.stubbedTreeError = AppError.serverError("boom")
        await sut.refresh()

        // Original topics should survive
        XCTAssertEqual(sut.rootTopics.count, 1)
        XCTAssertEqual(sut.rootTopics.first?.name, "Original")
    }

    // MARK: - Computed properties

    func test_totalFacts_usesStatsWhenAvailable() async {
        mockService.stubbedStats = MockTopicService.makeStats(totalTopics: 10, totalFacts: 42)
        mockService.stubbedTree = [MockTopicService.makeNode(factCount: 5)]

        await sut.refresh()

        XCTAssertEqual(sut.totalFacts, 42)
    }

    func test_totalFacts_fallsBackToTreeSum_whenNoStats() async {
        mockService.stubbedStatsError = AppError.serverError("stats unavailable")
        mockService.stubbedTree = [
            MockTopicService.makeNode(id: "1", factCount: 3),
            MockTopicService.makeNode(id: "2", factCount: 7)
        ]

        await sut.refresh()

        XCTAssertEqual(sut.totalFacts, 10)
    }

    func test_totalTopics_usesStatsWhenAvailable() async {
        mockService.stubbedStats = MockTopicService.makeStats(totalTopics: 99)
        mockService.stubbedTree = [MockTopicService.makeNode()]

        await sut.refresh()

        XCTAssertEqual(sut.totalTopics, 99)
    }

    func test_totalTopics_fallsBackToRootCount_whenNoStats() async {
        mockService.stubbedStatsError = AppError.serverError("stats unavailable")
        mockService.stubbedTree = [
            MockTopicService.makeNode(id: "1"),
            MockTopicService.makeNode(id: "2"),
            MockTopicService.makeNode(id: "3")
        ]

        await sut.refresh()

        XCTAssertEqual(sut.totalTopics, 3)
    }

    func test_totalFacts_zeroWhenEmpty() async {
        mockService.stubbedStatsError = AppError.serverError("nope")
        mockService.stubbedTree = []

        await sut.refresh()

        XCTAssertEqual(sut.totalFacts, 0)
    }

    func test_totalTopics_zeroWhenEmpty() async {
        mockService.stubbedStatsError = AppError.serverError("nope")
        mockService.stubbedTree = []

        await sut.refresh()

        XCTAssertEqual(sut.totalTopics, 0)
    }

    func test_totalFacts_sumsRecursiveChildFactCounts() async {
        mockService.stubbedStatsError = AppError.serverError("nope")
        let grandchild = MockTopicService.makeNode(id: "gc", factCount: 4)
        let child = MockTopicService.makeNode(id: "c", factCount: 2, children: [grandchild])
        let root = MockTopicService.makeNode(id: "r", factCount: 1, children: [child])
        mockService.stubbedTree = [root]

        await sut.refresh()

        // 1 + 2 + 4 = 7
        XCTAssertEqual(sut.totalFacts, 7)
    }
}
