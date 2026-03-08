import XCTest
@testable import Mind_Chat

// MARK: - SearchViewModel Tests

@MainActor
final class SearchViewModelTests: XCTestCase {

    var sut: SearchViewModel!
    var mockService: MockTopicService!

    override func setUp() async throws {
        mockService = MockTopicService()
        sut = SearchViewModel(service: mockService)
    }

    override func tearDown() async throws {
        sut = nil
        mockService = nil
    }

    // MARK: - onQueryChanged

    func test_onQueryChanged_emptyQuery_clearsResults() {
        sut.results = [MockTopicService.makeSearchResult()]

        sut.onQueryChanged("")

        XCTAssertTrue(sut.results.isEmpty)
    }

    func test_onQueryChanged_whitespaceOnly_clearsResults() {
        sut.results = [MockTopicService.makeSearchResult()]

        sut.onQueryChanged("   ")

        XCTAssertTrue(sut.results.isEmpty)
    }

    // MARK: - performSearch

    func test_performSearch_emptyQuery_clearsResults() async {
        sut.results = [MockTopicService.makeSearchResult()]
        sut.query = ""

        await sut.performSearch()

        XCTAssertTrue(sut.results.isEmpty)
    }

    func test_performSearch_populatesResults() async {
        mockService.stubbedSearchResults = [
            MockTopicService.makeSearchResult(type: .topic, topicId: "t1"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t1", factId: "f1")
        ]
        sut.query = "health"

        await sut.performSearch()

        XCTAssertEqual(sut.results.count, 2)
        XCTAssertEqual(mockService.searchCallCount, 1)
        XCTAssertEqual(mockService.lastSearchQuery, "health")
    }

    func test_performSearch_setsIsLoadingFalseAfterCompletion() async {
        sut.query = "test"

        await sut.performSearch()

        XCTAssertFalse(sut.isLoading)
    }

    func test_performSearch_appError_setsErrorMessage() async {
        mockService.stubbedSearchError = AppError.serverError("search failed")
        sut.query = "test"

        await sut.performSearch()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("search failed"))
    }

    func test_performSearch_genericError_setsErrorMessage() async {
        mockService.stubbedSearchError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        sut.query = "test"

        await sut.performSearch()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Generic error"))
    }

    func test_performSearch_passesTypeFilter() async {
        sut.query = "test"
        sut.selectedType = .goal

        await sut.performSearch()

        XCTAssertEqual(mockService.lastSearchType, .goal)
    }

    func test_performSearch_nilType_passesNil() async {
        sut.query = "test"
        sut.selectedType = nil

        await sut.performSearch()

        XCTAssertNil(mockService.lastSearchType)
    }

    // MARK: - Grouped Results

    func test_groupedResults_emptyResults_returnsEmpty() {
        sut.results = []

        XCTAssertTrue(sut.groupedResults.isEmpty)
    }

    func test_groupedResults_onlyTopicResults_returnsEmpty() {
        sut.results = [
            MockTopicService.makeSearchResult(type: .topic, topicId: "t1")
        ]

        XCTAssertTrue(sut.groupedResults.isEmpty)
    }

    func test_groupedResults_groupsByTopicId() {
        sut.results = [
            MockTopicService.makeSearchResult(type: .fact, topicId: "t1", topicName: "Health", factId: "f1"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t1", topicName: "Health", factId: "f2"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t2", topicName: "Work", factId: "f3")
        ]

        let groups = sut.groupedResults

        XCTAssertEqual(groups.count, 2)

        let healthGroup = groups.first(where: { $0.id == "t1" })
        XCTAssertEqual(healthGroup?.facts.count, 2)

        let workGroup = groups.first(where: { $0.id == "t2" })
        XCTAssertEqual(workGroup?.facts.count, 1)
    }

    func test_groupedResults_sortedByFactCountDescending() {
        sut.results = [
            MockTopicService.makeSearchResult(type: .fact, topicId: "t1", factId: "f1"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t2", factId: "f2"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t2", factId: "f3"),
            MockTopicService.makeSearchResult(type: .fact, topicId: "t2", factId: "f4")
        ]

        let groups = sut.groupedResults

        XCTAssertEqual(groups.first?.id, "t2")
        XCTAssertEqual(groups.first?.facts.count, 3)
        XCTAssertEqual(groups.last?.id, "t1")
    }

    func test_groupedResults_carriesTopicMetadata() {
        sut.results = [
            MockTopicService.makeSearchResult(
                type: .fact,
                topicId: "t1",
                topicName: "Fitness",
                topicPath: "health/fitness",
                topicIcon: "figure.run",
                factId: "f1"
            )
        ]

        let group = sut.groupedResults.first
        XCTAssertEqual(group?.topicName, "Fitness")
        XCTAssertEqual(group?.topicPath, "health/fitness")
        XCTAssertEqual(group?.topicIcon, "figure.run")
    }
}
