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
        // Clear cache so tests don't bleed into each other
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
}
