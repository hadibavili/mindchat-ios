import XCTest
@testable import Mind_Chat

// MARK: - TopicTreeNode Tests

@MainActor
final class TopicTreeNodeTests: XCTestCase {

    func test_totalFactCount_leafNode() {
        let node = MockTopicService.makeNode(factCount: 5)

        XCTAssertEqual(node.totalFactCount, 5)
    }

    func test_totalFactCount_withChildren() {
        let child1 = MockTopicService.makeNode(id: "c1", factCount: 3)
        let child2 = MockTopicService.makeNode(id: "c2", factCount: 2)
        let parent = MockTopicService.makeNode(id: "p", factCount: 1, children: [child1, child2])

        XCTAssertEqual(parent.totalFactCount, 6) // 1 + 3 + 2
    }

    func test_totalFactCount_deeplyNested() {
        let grandchild = MockTopicService.makeNode(id: "gc", factCount: 4)
        let child = MockTopicService.makeNode(id: "c", factCount: 2, children: [grandchild])
        let root = MockTopicService.makeNode(id: "r", factCount: 1, children: [child])

        XCTAssertEqual(root.totalFactCount, 7) // 1 + 2 + 4
    }

    func test_flattened_leafNode_returnsSelf() {
        let node = MockTopicService.makeNode(id: "leaf")

        let flat = node.flattened()

        XCTAssertEqual(flat.count, 1)
        XCTAssertEqual(flat[0].id, "leaf")
    }

    func test_flattened_withChildren_depthFirst() {
        let grandchild = MockTopicService.makeNode(id: "gc")
        let child1 = MockTopicService.makeNode(id: "c1", children: [grandchild])
        let child2 = MockTopicService.makeNode(id: "c2")
        let root = MockTopicService.makeNode(id: "root", children: [child1, child2])

        let flat = root.flattened()

        XCTAssertEqual(flat.map(\.id), ["root", "c1", "gc", "c2"])
    }

    func test_flattenAll_multipleRoots() {
        let root1 = MockTopicService.makeNode(id: "r1")
        let child = MockTopicService.makeNode(id: "c1")
        let root2 = MockTopicService.makeNode(id: "r2", children: [child])

        let flat = TopicTreeNode.flattenAll([root1, root2])

        XCTAssertEqual(flat.map(\.id), ["r1", "r2", "c1"])
    }

    func test_flattenAll_emptyArray_returnsEmpty() {
        let flat = TopicTreeNode.flattenAll([])

        XCTAssertTrue(flat.isEmpty)
    }

    func test_nonEmptyChildren_returnsNil_whenEmpty() {
        let node = MockTopicService.makeNode()

        XCTAssertNil(node.nonEmptyChildren)
    }

    func test_nonEmptyChildren_returnsChildren_whenPresent() {
        let child = MockTopicService.makeNode(id: "c")
        let node = MockTopicService.makeNode(children: [child])

        XCTAssertNotNil(node.nonEmptyChildren)
        XCTAssertEqual(node.nonEmptyChildren?.count, 1)
    }
}

// MARK: - TopicWithStats Decoder Tests

@MainActor
final class TopicWithStatsDecoderTests: XCTestCase {

    func test_decode_factCountDefaultsToZero_whenMissing() throws {
        let json = """
        { "id": "t1", "name": "Test", "path": "test" }
        """.data(using: .utf8)!

        let result = try JSONDecoder.mindChat.decode(TopicWithStats.self, from: json)

        XCTAssertEqual(result.factCount, 0)
    }

    func test_decode_factCountUsesValue_whenPresent() throws {
        let json = """
        { "id": "t1", "name": "Test", "path": "test", "factCount": 5 }
        """.data(using: .utf8)!

        let result = try JSONDecoder.mindChat.decode(TopicWithStats.self, from: json)

        XCTAssertEqual(result.factCount, 5)
    }

    func test_decode_allFieldsPresent() throws {
        let json = """
        {
            "id": "t1", "name": "Health", "path": "health",
            "summary": "About health", "icon": "heart",
            "slug": "health", "depth": 1,
            "createdAt": "2026-01-15T08:00:00.000Z",
            "updatedAt": "2026-03-06T14:20:00.000Z",
            "factCount": 10, "subtopicCount": 3
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder.mindChat.decode(TopicWithStats.self, from: json)

        XCTAssertEqual(result.id, "t1")
        XCTAssertEqual(result.name, "Health")
        XCTAssertEqual(result.summary, "About health")
        XCTAssertEqual(result.icon, "heart")
        XCTAssertEqual(result.slug, "health")
        XCTAssertEqual(result.depth, 1)
        XCTAssertEqual(result.factCount, 10)
        XCTAssertEqual(result.subtopicCount, 3)
        XCTAssertNotNil(result.createdAt)
        XCTAssertNotNil(result.updatedAt)
    }

    func test_decode_optionalFieldsMissing() throws {
        let json = """
        { "id": "t1", "name": "Test", "path": "test" }
        """.data(using: .utf8)!

        let result = try JSONDecoder.mindChat.decode(TopicWithStats.self, from: json)

        XCTAssertNil(result.summary)
        XCTAssertNil(result.icon)
        XCTAssertNil(result.slug)
        XCTAssertNil(result.depth)
        XCTAssertNil(result.createdAt)
        XCTAssertNil(result.updatedAt)
        XCTAssertNil(result.subtopicCount)
    }
}

// MARK: - TopicDetailResponse Tests

@MainActor
final class TopicDetailResponseTests: XCTestCase {

    func test_topicComputed_createsTopicWithStats() {
        let detail = MockTopicService.makeDetail(id: "t1", name: "Health")

        let topic = detail.topic

        XCTAssertEqual(topic.id, "t1")
        XCTAssertEqual(topic.name, "Health")
    }

    func test_topicComputed_factCountFromFactsArray() {
        let detail = MockTopicService.makeDetail(id: "t1", facts: [
            MockTopicService.makeFact(id: "f1"),
            MockTopicService.makeFact(id: "f2")
        ])

        XCTAssertEqual(detail.topic.factCount, 2)
    }

    func test_topicComputed_subtopicCountFromChildren() {
        let detail = MockTopicService.makeDetail(
            id: "t1",
            children: [
                MockTopicService.makeTopicWithStats(id: "c1"),
                MockTopicService.makeTopicWithStats(id: "c2"),
                MockTopicService.makeTopicWithStats(id: "c3")
            ]
        )

        XCTAssertEqual(detail.topic.subtopicCount, 3)
    }
}

// MARK: - SearchResult Tests

@MainActor
final class SearchResultTests: XCTestCase {

    func test_id_returnsFactIdWhenPresent() {
        let result = MockTopicService.makeSearchResult(type: .fact, topicId: "t1", factId: "f1")

        XCTAssertEqual(result.id, "f1")
    }

    func test_id_returnsTopicIdWhenNoFactId() {
        let result = MockTopicService.makeSearchResult(type: .topic, topicId: "t1")

        XCTAssertEqual(result.id, "t1")
    }

    func test_isFact_trueForFactType() {
        let result = MockTopicService.makeSearchResult(type: .fact)

        XCTAssertTrue(result.isFact)
    }

    func test_isFact_falseForTopicType() {
        let result = MockTopicService.makeSearchResult(type: .topic)

        XCTAssertFalse(result.isFact)
    }
}

// MARK: - FactType Tests

@MainActor
final class FactTypeTests: XCTestCase {

    func test_allCases_hasFourTypes() {
        XCTAssertEqual(FactType.allCases.count, 4)
    }

    func test_label_mappings() {
        XCTAssertEqual(FactType.fact.label, "Fact")
        XCTAssertEqual(FactType.preference.label, "Preference")
        XCTAssertEqual(FactType.goal.label, "Goal")
        XCTAssertEqual(FactType.experience.label, "Experience")
    }

    func test_color_mappings() {
        XCTAssertEqual(FactType.fact.color, "blue")
        XCTAssertEqual(FactType.preference.color, "purple")
        XCTAssertEqual(FactType.goal.color, "green")
        XCTAssertEqual(FactType.experience.color, "orange")
    }

    func test_rawValue_roundTrips() {
        for type in FactType.allCases {
            let encoded = type.rawValue
            let decoded = FactType(rawValue: encoded)
            XCTAssertEqual(decoded, type)
        }
    }
}

// MARK: - FactImportance Tests

@MainActor
final class FactImportanceTests: XCTestCase {

    func test_allCases_hasFourLevels() {
        XCTAssertEqual(FactImportance.allCases.count, 4)
    }

    func test_label_mappings() {
        XCTAssertEqual(FactImportance.high.label, "Important")
        XCTAssertEqual(FactImportance.medium.label, "Medium")
        XCTAssertEqual(FactImportance.low.label, "Low")
        XCTAssertEqual(FactImportance.none.label, "None")
    }

    func test_rawValue_roundTrips() {
        for imp in FactImportance.allCases {
            let encoded = imp.rawValue
            let decoded = FactImportance(rawValue: encoded)
            XCTAssertEqual(decoded, imp)
        }
    }
}

// MARK: - FactSortOrder Tests

@MainActor
final class FactSortOrderTests: XCTestCase {

    func test_allCases_hasThreeOrders() {
        XCTAssertEqual(FactSortOrder.allCases.count, 3)
    }

    func test_label_mappings() {
        XCTAssertEqual(FactSortOrder.newest.label, "Newest")
        XCTAssertEqual(FactSortOrder.oldest.label, "Oldest")
        XCTAssertEqual(FactSortOrder.importance.label, "Importance")
    }

    func test_id_equalsRawValue() {
        for order in FactSortOrder.allCases {
            XCTAssertEqual(order.id, order.rawValue)
        }
    }
}
