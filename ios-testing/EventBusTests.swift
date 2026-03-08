import XCTest
import Combine
@testable import Mind_Chat

// MARK: - EventBus & Navigation Tests

@MainActor
final class EventBusTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    override func tearDown() async throws {
        cancellables.removeAll()
    }

    // MARK: - Publish / Subscribe

    func test_publish_topicsUpdated_receivedBySubscriber() {
        let expectation = expectation(description: "topicsUpdated received")

        EventBus.shared.events
            .sink { event in
                if case .topicsUpdated = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        EventBus.shared.publish(.topicsUpdated)

        wait(for: [expectation], timeout: 1)
    }

    func test_publish_factsUpdated_receivedBySubscriber() {
        let expectation = expectation(description: "factsUpdated received")

        EventBus.shared.events
            .sink { event in
                if case .factsUpdated = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        EventBus.shared.publish(.factsUpdated)

        wait(for: [expectation], timeout: 1)
    }

    func test_publish_navigateToMessage_carriesPayload() {
        let expectation = expectation(description: "navigateToMessage received")

        EventBus.shared.events
            .sink { event in
                if case .navigateToMessage(let convId, let msgId) = event {
                    XCTAssertEqual(convId, "conv-1")
                    XCTAssertEqual(msgId, "msg-1")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        EventBus.shared.publish(.navigateToMessage(conversationId: "conv-1", messageId: "msg-1"))

        wait(for: [expectation], timeout: 1)
    }

    func test_publish_startChatWithTopic_carriesPayload() {
        let expectation = expectation(description: "startChatWithTopic received")

        EventBus.shared.events
            .sink { event in
                if case .startChatWithTopic(let topicId, let name, let count) = event {
                    XCTAssertEqual(topicId, "t1")
                    XCTAssertEqual(name, "Health")
                    XCTAssertEqual(count, 5)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        EventBus.shared.publish(.startChatWithTopic(topicId: "t1", topicName: "Health", factCount: 5))

        wait(for: [expectation], timeout: 1)
    }

    func test_multipleSubscribers_allReceiveEvent() {
        let exp1 = expectation(description: "subscriber1")
        let exp2 = expectation(description: "subscriber2")

        EventBus.shared.events
            .sink { event in
                if case .topicsUpdated = event { exp1.fulfill() }
            }
            .store(in: &cancellables)

        EventBus.shared.events
            .sink { event in
                if case .topicsUpdated = event { exp2.fulfill() }
            }
            .store(in: &cancellables)

        EventBus.shared.publish(.topicsUpdated)

        wait(for: [exp1, exp2], timeout: 1)
    }
}
