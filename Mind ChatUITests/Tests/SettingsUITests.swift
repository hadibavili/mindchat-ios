import XCTest

final class SettingsUITests: MindChatUITestCase {

    // MARK: - Navigation

    func test_navigateToSettings() {
        navigateToSettings()
        // navigateToSettings() already asserts the nav bar exists
    }

    // MARK: - Sections

    func test_settings_showsAppearanceSection() {
        navigateToSettings()

        let appearance = app.staticTexts["Appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 3),
                      "Appearance section should be visible in settings")
    }

    func test_settings_showsBehaviourSection() {
        navigateToSettings()

        let behaviour = app.staticTexts["Behaviour"]
        XCTAssertTrue(behaviour.waitForExistence(timeout: 3),
                      "Behaviour section should be visible in settings")
    }

    func test_settings_showsSubscriptionSection() {
        navigateToSettings()

        let settings = app.scrollViews.firstMatch
        settings.swipeUp()

        let subscription = app.staticTexts["Subscription"]
        XCTAssertTrue(subscription.waitForExistence(timeout: 3),
                      "Subscription section should be visible after scrolling")
    }

    func test_settings_showsAccountSection() {
        navigateToSettings()

        let settings = app.scrollViews.firstMatch
        settings.swipeUp()

        let account = app.staticTexts["Account"]
        XCTAssertTrue(account.waitForExistence(timeout: 3),
                      "Account section should be visible after scrolling")
    }

    // MARK: - Interactions

    func test_settings_themePicker_isInteractable() {
        navigateToSettings()

        // Theme picker should have Light/Dark/System segments
        let lightSegment = app.buttons["Light"]
        let darkSegment = app.buttons["Dark"]
        let systemSegment = app.buttons["System"]

        XCTAssertTrue(lightSegment.waitForExistence(timeout: 3), "Light theme option should exist")
        XCTAssertTrue(darkSegment.exists, "Dark theme option should exist")
        XCTAssertTrue(systemSegment.exists, "System theme option should exist")
    }

    func test_settings_autoExtractToggle() {
        navigateToSettings()

        let toggle = app.switches["settings.autoExtractToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Auto-extract toggle should exist")

        let initialValue = toggle.value as? String
        toggle.tap()

        let newValue = toggle.value as? String
        XCTAssertNotEqual(initialValue, newValue,
                          "Toggle value should change after tap")
    }

    func test_settings_backButton_returnsToChatView() {
        navigateToSettings()

        // Tap back button
        let backButton = app.navigationBars["Settings"].buttons.firstMatch
        XCTAssertTrue(backButton.exists)
        backButton.tap()

        // Should return to chat view
        let inputField = app.textFields["chat.input.textField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5),
                      "Chat input should be visible after returning from settings")
    }
}
