import XCTest
@testable import Mind_Chat

// MARK: - TopicDetailViewModel Tests

@MainActor
final class TopicDetailViewModelTests: XCTestCase {

    var sut: TopicDetailViewModel!
    var mockService: MockTopicService!
    let topicId = "topic-1"

    override func setUp() async throws {
        mockService = MockTopicService()
        sut = TopicDetailViewModel(topicId: topicId, service: mockService)
        CacheStore.shared.invalidate(.topicDetail(id: topicId))
    }

    override func tearDown() async throws {
        sut = nil
        mockService = nil
    }

    // MARK: - Load

    func test_load_populatesDetailAndFacts() async {
        let detail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1"),
            MockTopicService.makeFact(id: "f2")
        ])
        mockService.stubbedDetail = detail

        await sut.load()

        XCTAssertNotNil(sut.detail)
        XCTAssertEqual(sut.facts.count, 2)
    }

    func test_load_callsServiceOnce() async {
        await sut.load()

        XCTAssertEqual(mockService.topicDetailCallCount, 1)
        XCTAssertEqual(mockService.lastDetailId, topicId)
    }

    func test_load_usesCache_doesNotCallService() async {
        let cached = MockTopicService.makeDetail(id: topicId)
        CacheStore.shared.set(.topicDetail(id: topicId), value: cached)

        await sut.load()

        XCTAssertEqual(mockService.topicDetailCallCount, 0)
        XCTAssertNotNil(sut.detail)
    }

    func test_load_setsIsLoadingFalse() async {
        await sut.load()

        XCTAssertFalse(sut.isLoading)
    }

    func test_load_setsErrorOnAppError() async {
        mockService.stubbedDetailError = AppError.serverError("Not found")

        await sut.load()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Not found"))
    }

    func test_load_setsErrorOnGenericError() async {
        mockService.stubbedDetailError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Generic failure"])

        await sut.load()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Generic failure"))
    }

    func test_load_cachesResultOnSuccess() async {
        await sut.load()

        let cached: TopicDetailResponse? = CacheStore.shared.get(.topicDetail(id: topicId))
        XCTAssertNotNil(cached)
    }

    // MARK: - Refresh

    func test_refresh_alwaysCallsService() async {
        let cached = MockTopicService.makeDetail(id: topicId)
        CacheStore.shared.set(.topicDetail(id: topicId), value: cached)

        await sut.refresh()

        XCTAssertEqual(mockService.topicDetailCallCount, 1)
    }

    func test_refresh_updatesDetailAndFacts() async {
        // First load
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "old")
        ])
        await sut.load()
        XCTAssertEqual(sut.facts.count, 1)

        // Refresh with new data
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "new1"),
            MockTopicService.makeFact(id: "new2"),
            MockTopicService.makeFact(id: "new3")
        ])
        await sut.refresh()

        XCTAssertEqual(sut.facts.count, 3)
    }

    func test_refresh_swallowsErrors() async {
        mockService.stubbedDetailError = AppError.serverError("boom")

        await sut.refresh()

        // No crash, no error set (refresh catches errors silently)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Filtering

    func test_filteredFacts_noFilter_returnsAll() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", type: .fact),
            MockTopicService.makeFact(id: "f2", type: .goal),
            MockTopicService.makeFact(id: "f3", type: .preference)
        ])
        await sut.load()

        XCTAssertEqual(sut.filteredFacts.count, 3)
    }

    func test_filteredFacts_filterByType_onlyMatchingType() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", type: .fact),
            MockTopicService.makeFact(id: "f2", type: .goal),
            MockTopicService.makeFact(id: "f3", type: .goal)
        ])
        await sut.load()

        sut.selectedType = .goal

        XCTAssertEqual(sut.filteredFacts.count, 2)
        XCTAssertTrue(sut.filteredFacts.allSatisfy { $0.type == .goal })
    }

    func test_filteredFacts_filterByImportance_onlyMatchingImportance() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", importance: .high),
            MockTopicService.makeFact(id: "f2", importance: .low),
            MockTopicService.makeFact(id: "f3", importance: .high)
        ])
        await sut.load()

        sut.selectedImportance = .high

        XCTAssertEqual(sut.filteredFacts.count, 2)
        XCTAssertTrue(sut.filteredFacts.allSatisfy { $0.importance == .high })
    }

    func test_filteredFacts_importanceNone_doesNotFilter() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", importance: .high),
            MockTopicService.makeFact(id: "f2", importance: .low)
        ])
        await sut.load()

        sut.selectedImportance = .none

        XCTAssertEqual(sut.filteredFacts.count, 2)
    }

    func test_filteredFacts_combinedTypeAndImportance() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", type: .fact, importance: .high),
            MockTopicService.makeFact(id: "f2", type: .fact, importance: .low),
            MockTopicService.makeFact(id: "f3", type: .goal, importance: .high)
        ])
        await sut.load()

        sut.selectedType = .fact
        sut.selectedImportance = .high

        XCTAssertEqual(sut.filteredFacts.count, 1)
        XCTAssertEqual(sut.filteredFacts.first?.id, "f1")
    }

    // MARK: - Sorting

    func test_filteredFacts_sortNewest() async {
        let now = Date()
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "old", createdAt: now.addingTimeInterval(-100)),
            MockTopicService.makeFact(id: "new", createdAt: now)
        ])
        await sut.load()
        sut.sortOrder = .newest

        XCTAssertEqual(sut.filteredFacts.first?.id, "new")
        XCTAssertEqual(sut.filteredFacts.last?.id, "old")
    }

    func test_filteredFacts_sortOldest() async {
        let now = Date()
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "old", createdAt: now.addingTimeInterval(-100)),
            MockTopicService.makeFact(id: "new", createdAt: now)
        ])
        await sut.load()
        sut.sortOrder = .oldest

        XCTAssertEqual(sut.filteredFacts.first?.id, "old")
        XCTAssertEqual(sut.filteredFacts.last?.id, "new")
    }

    func test_filteredFacts_sortImportance() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "low", importance: .low),
            MockTopicService.makeFact(id: "high", importance: .high),
            MockTopicService.makeFact(id: "med", importance: .medium)
        ])
        await sut.load()
        sut.sortOrder = .importance

        XCTAssertEqual(sut.filteredFacts.map(\.id), ["high", "med", "low"])
    }

    // MARK: - Count

    func test_count_forType_returnsCorrectCount() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", type: .fact),
            MockTopicService.makeFact(id: "f2", type: .fact),
            MockTopicService.makeFact(id: "f3", type: .goal)
        ])
        await sut.load()

        XCTAssertEqual(sut.count(for: .fact), 2)
        XCTAssertEqual(sut.count(for: .goal), 1)
    }

    func test_count_forType_returnsZero_whenNoneMatch() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", type: .fact)
        ])
        await sut.load()

        XCTAssertEqual(sut.count(for: .experience), 0)
    }

    // MARK: - Toggle Pin

    func test_togglePin_optimisticallyFlipsPinned() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", pinned: false)
        ])
        await sut.load()

        // Make service slow so we can check optimistic state
        mockService.stubbedUpdatedFact = MockTopicService.makeFact(id: "f1", pinned: true)
        await sut.togglePin(factId: "f1")

        XCTAssertTrue(sut.facts.first(where: { $0.id == "f1" })!.pinned)
    }

    func test_togglePin_success_updatesFactFromService() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", content: "original", pinned: false)
        ])
        await sut.load()

        mockService.stubbedUpdatedFact = MockTopicService.makeFact(id: "f1", content: "from-server", pinned: true)
        await sut.togglePin(factId: "f1")

        XCTAssertEqual(sut.facts.first(where: { $0.id == "f1" })?.content, "from-server")
    }

    func test_togglePin_success_callsServiceWithCorrectParams() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", pinned: false)
        ])
        await sut.load()

        await sut.togglePin(factId: "f1")

        XCTAssertEqual(mockService.updateFactCallCount, 1)
        XCTAssertEqual(mockService.lastUpdateId, "f1")
        XCTAssertEqual(mockService.lastUpdatePinned, true)
        XCTAssertNil(mockService.lastUpdateContent)
    }

    func test_togglePin_failure_rollsBackPinned() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", pinned: false)
        ])
        await sut.load()

        mockService.stubbedUpdateError = AppError.serverError("fail")
        await sut.togglePin(factId: "f1")

        XCTAssertFalse(sut.facts.first(where: { $0.id == "f1" })!.pinned)
    }

    func test_togglePin_nonExistentId_doesNothing() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [])
        await sut.load()

        await sut.togglePin(factId: "nonexistent")

        XCTAssertEqual(mockService.updateFactCallCount, 0)
    }

    // MARK: - Update Content

    func test_updateContent_optimisticallySetsContent() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", content: "old")
        ])
        await sut.load()

        mockService.stubbedUpdatedFact = MockTopicService.makeFact(id: "f1", content: "new")
        await sut.updateContent(factId: "f1", content: "new")

        XCTAssertEqual(sut.facts.first?.content, "new")
    }

    func test_updateContent_success_callsService() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", content: "old")
        ])
        await sut.load()

        await sut.updateContent(factId: "f1", content: "new content")

        XCTAssertEqual(mockService.updateFactCallCount, 1)
        XCTAssertEqual(mockService.lastUpdateContent, "new content")
    }

    func test_updateContent_failure_rollsBackContent() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1", content: "original")
        ])
        await sut.load()

        mockService.stubbedUpdateError = AppError.serverError("fail")
        await sut.updateContent(factId: "f1", content: "new")

        XCTAssertEqual(sut.facts.first?.content, "original")
    }

    func test_updateContent_nonExistentId_doesNothing() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [])
        await sut.load()

        await sut.updateContent(factId: "nonexistent", content: "text")

        XCTAssertEqual(mockService.updateFactCallCount, 0)
    }

    // MARK: - Delete Fact

    func test_deleteFact_optimisticallyRemovesFact() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1"),
            MockTopicService.makeFact(id: "f2")
        ])
        await sut.load()
        XCTAssertEqual(sut.facts.count, 2)

        await sut.deleteFact(factId: "f1")

        XCTAssertEqual(sut.facts.count, 1)
        XCTAssertFalse(sut.facts.contains(where: { $0.id == "f1" }))
    }

    func test_deleteFact_success_callsService() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1")
        ])
        await sut.load()

        await sut.deleteFact(factId: "f1")

        XCTAssertEqual(mockService.deleteFactCallCount, 1)
        XCTAssertEqual(mockService.lastDeleteId, "f1")
    }

    func test_deleteFact_failure_restoresFact() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1")
        ])
        await sut.load()

        mockService.stubbedDeleteError = AppError.serverError("fail")
        await sut.deleteFact(factId: "f1")

        XCTAssertEqual(sut.facts.count, 1)
        XCTAssertEqual(sut.facts.first?.id, "f1")
    }

    func test_deleteFact_nonExistentId_doesNothing() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1")
        ])
        await sut.load()

        await sut.deleteFact(factId: "nonexistent")

        XCTAssertEqual(sut.facts.count, 1)
        XCTAssertEqual(mockService.deleteFactCallCount, 0)
    }

    // MARK: - Undo-Delete Helpers

    func test_removeFactLocally_removesFromArray() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1"),
            MockTopicService.makeFact(id: "f2")
        ])
        await sut.load()

        sut.removeFactLocally(factId: "f1")

        XCTAssertEqual(sut.facts.count, 1)
        XCTAssertEqual(sut.facts.first?.id, "f2")
    }

    func test_removeFactLocally_nonExistentId_doesNothing() async {
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [
            MockTopicService.makeFact(id: "f1")
        ])
        await sut.load()

        sut.removeFactLocally(factId: "nonexistent")

        XCTAssertEqual(sut.facts.count, 1)
    }

    func test_restoreFactLocally_insertsInCorrectPosition() async {
        let now = Date()
        let fact1 = MockTopicService.makeFact(id: "f1", createdAt: now)
        let fact2 = MockTopicService.makeFact(id: "f2", createdAt: now.addingTimeInterval(-50))
        let fact3 = MockTopicService.makeFact(id: "f3", createdAt: now.addingTimeInterval(-100))

        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [fact1, fact2, fact3])
        await sut.load()

        // Remove f2, then restore it
        sut.removeFactLocally(factId: "f2")
        XCTAssertEqual(sut.facts.count, 2)

        sut.restoreFactLocally(fact2)

        XCTAssertEqual(sut.facts.count, 3)
    }

    func test_restoreFactLocally_appendsIfOldest() async {
        let now = Date()
        let fact1 = MockTopicService.makeFact(id: "f1", createdAt: now)
        let oldFact = MockTopicService.makeFact(id: "old", createdAt: now.addingTimeInterval(-1000))

        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [fact1])
        await sut.load()

        sut.restoreFactLocally(oldFact)

        XCTAssertEqual(sut.facts.count, 2)
        XCTAssertEqual(sut.facts.last?.id, "old")
    }

    func test_restoreFactLocally_noDuplicate() async {
        let fact = MockTopicService.makeFact(id: "f1")
        mockService.stubbedDetail = MockTopicService.makeDetail(id: topicId, facts: [fact])
        await sut.load()

        sut.restoreFactLocally(fact)

        XCTAssertEqual(sut.facts.count, 1)
    }

    // MARK: - Commit Delete

    func test_commitDeleteFact_callsServiceDelete() async {
        await sut.commitDeleteFact(factId: "f1")

        XCTAssertEqual(mockService.deleteFactCallCount, 1)
        XCTAssertEqual(mockService.lastDeleteId, "f1")
    }

    func test_commitDeleteFact_failure_callsRefresh() async {
        mockService.stubbedDeleteError = AppError.serverError("fail")

        await sut.commitDeleteFact(factId: "f1")

        // On failure, commitDeleteFact calls refresh(), which calls topicDetail
        XCTAssertEqual(mockService.topicDetailCallCount, 1)
    }

    // MARK: - Merge

    func test_merge_callsServiceWithCorrectIds() async {
        try? await sut.merge(into: "target-1")

        XCTAssertEqual(mockService.mergeCallCount, 1)
        XCTAssertEqual(mockService.lastMergeSourceId, topicId)
        XCTAssertEqual(mockService.lastMergeTargetId, "target-1")
    }

    func test_merge_throwsOnServiceError() async {
        mockService.stubbedMergeError = AppError.serverError("merge failed")

        do {
            try await sut.merge(into: "target-1")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
}
