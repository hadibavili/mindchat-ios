import XCTest

final class ChatNavigationUITests: MindChatUITestCase {

    // MARK: - Input field

    func test_initialLaunch_showsInputField() {
        let inputField = app.textFields["chat.input.textField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5),
                      "Chat input field should be visible on launch")
    }

    func test_inputField_acceptsText() {
        let inputField = app.textFields["chat.input.textField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.tap()
        inputField.typeText("Hello MindChat")

        let value = inputField.value as? String ?? ""
        XCTAssertTrue(value.contains("Hello MindChat"),
                      "Typed text should appear in the input field")
    }

    // MARK: - New chat button

    func test_newChatButton_exists() {
        let newChatButton = app.buttons["chat.newChatButton"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5),
                      "New chat button should exist")
        XCTAssertTrue(newChatButton.isEnabled,
                      "New chat button should be enabled")
    }

    func test_newChatButton_clearsChatState() {
        let inputField = app.textFields["chat.input.textField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.tap()
        inputField.typeText("Some text")

        let newChatButton = app.buttons["chat.newChatButton"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 3))
        newChatButton.tap()

        // Input should be cleared after new chat
        let value = inputField.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == "Ask anything",
                      "Input field should be cleared after tapping new chat")
    }

    // MARK: - Sidebar

    func test_sidebarToggle_opensSidebar() {
        openSidebar()

        let mindChatTitle = app.staticTexts["Mind Chat"]
        XCTAssertTrue(mindChatTitle.exists,
                      "Sidebar should display 'Mind Chat' title")
    }

    func test_sidebarToggle_closesOnScrimTap() {
        openSidebar()
        dismissSidebar()

        let sidebar = app.otherElements["sidebar.container"]
        XCTAssertFalse(sidebar.exists,
                       "Sidebar should be dismissed after tapping scrim")
    }

    // MARK: - Model selector

    func test_modelSelector_opensSheet() {
        let modelButton = app.buttons["chat.modelSelector"]
        XCTAssertTrue(modelButton.waitForExistence(timeout: 5))
        modelButton.tap()

        // The model selector sheet should appear — look for a "Done" button or known model names
        let doneButton = app.buttons["Done"]
        let sheetAppeared = doneButton.waitForExistence(timeout: 5)
        XCTAssertTrue(sheetAppeared,
                      "Model selector sheet should appear with a Done button")
    }

    func test_modelSelector_dismissesWithDone() {
        let modelButton = app.buttons["chat.modelSelector"]
        XCTAssertTrue(modelButton.waitForExistence(timeout: 5))
        modelButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // After dismissal, the model button should still be visible
        XCTAssertTrue(modelButton.waitForExistence(timeout: 3),
                      "Model selector button should remain after dismissing sheet")
    }
}
