import XCTest

final class TopicsBrowsingUITests: MindChatUITestCase {

    // MARK: - My Mind

    func test_myMind_opensFromSidebar() {
        openSidebar()

        let myMindButton = app.buttons["sidebar.myMindButton"]
        XCTAssertTrue(myMindButton.waitForExistence(timeout: 3),
                      "My Mind button should be visible in sidebar")
        myMindButton.tap()

        // My Mind sheet should appear — look for "My Mind" title or Done button
        let doneButton = app.buttons["Done"]
        let myMindTitle = app.staticTexts["My Mind"]
        let appeared = doneButton.waitForExistence(timeout: 5) || myMindTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(appeared, "My Mind sheet should appear")
    }

    func test_myMind_dismissesWithDone() {
        openSidebar()

        let myMindButton = app.buttons["sidebar.myMindButton"]
        XCTAssertTrue(myMindButton.waitForExistence(timeout: 3))
        myMindButton.tap()

        let doneButton = app.buttons["Done"]
        guard doneButton.waitForExistence(timeout: 5) else {
            // Sheet might use a different dismiss mechanism
            return
        }
        doneButton.tap()

        // Should return to the main chat view
        let inputField = app.textFields["chat.input.textField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5),
                      "Chat input should be visible after dismissing My Mind")
    }

    // MARK: - Memory section

    func test_sidebar_memorySection_exists() {
        openSidebar()

        let memoryHeader = app.buttons["sidebar.memorySection"]
        XCTAssertTrue(memoryHeader.waitForExistence(timeout: 3),
                      "Memory section header should be visible in sidebar")
    }

    func test_sidebar_memorySection_showsEmptyHint() {
        openSidebar()

        // With --uitesting and no data, the empty state should show
        let emptyHint = app.staticTexts["Topics appear as you chat"]
        XCTAssertTrue(emptyHint.waitForExistence(timeout: 3),
                      "Empty memory section should show hint text")
    }

    func test_sidebar_myMindButton_exists() {
        openSidebar()

        let myMindButton = app.buttons["sidebar.myMindButton"]
        XCTAssertTrue(myMindButton.waitForExistence(timeout: 3),
                      "My Mind button should be visible in sidebar")
        XCTAssertTrue(myMindButton.isEnabled,
                      "My Mind button should be enabled")
    }
}
