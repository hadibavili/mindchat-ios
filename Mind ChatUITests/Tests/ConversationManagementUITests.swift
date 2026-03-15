import XCTest

final class ConversationManagementUITests: MindChatUITestCase {

    // MARK: - Sidebar content

    func test_sidebar_showsTitle() {
        openSidebar()

        let title = app.staticTexts["Mind Chat"]
        XCTAssertTrue(title.exists,
                      "Sidebar should display 'Mind Chat' title")
    }

    func test_sidebar_showsUserRow() {
        openSidebar()

        let userRow = app.buttons["sidebar.userRow"]
        XCTAssertTrue(userRow.waitForExistence(timeout: 3),
                      "User row should be visible in sidebar")

        // The test user name should be visible
        let userName = app.staticTexts["Test User"]
        XCTAssertTrue(userName.exists,
                      "User row should display 'Test User' name")
    }

    func test_sidebar_searchField_acceptsInput() {
        openSidebar()

        let searchField = app.textFields["Search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Search field should exist in sidebar")
        searchField.tap()
        searchField.typeText("test query")

        let value = searchField.value as? String ?? ""
        XCTAssertTrue(value.contains("test query"),
                      "Search field should accept typed text")
    }

    func test_sidebar_userRow_navigatesToSettings() {
        navigateToSettings()
        // navigateToSettings() already asserts Settings nav bar appears
    }

    func test_conversationHistory_opensIfAvailable() throws {
        openSidebar()

        let seeAll = app.buttons["sidebar.seeAllConversations"]
        guard seeAll.waitForExistence(timeout: 3) else {
            throw XCTSkip("'See all' button not present — not enough conversations to trigger it")
        }
        seeAll.tap()

        // Should open conversation history view
        sleep(1)
        // Verify we navigated away from the sidebar
        let sidebar = app.otherElements["sidebar.container"]
        XCTAssertFalse(sidebar.exists,
                       "Sidebar should dismiss after tapping See all")
    }
}
