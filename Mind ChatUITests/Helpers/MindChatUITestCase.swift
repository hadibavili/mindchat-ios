import XCTest

/// Base class for MindChat UI tests.
///
/// Subclasses that need the LoginView (auth tests) should override `bypassAuth`
/// and return `false`. All other tests launch with `--uitesting` to skip login.
class MindChatUITestCase: XCTestCase {

    var app: XCUIApplication!

    /// Override in auth tests to launch without `--uitesting`.
    var bypassAuth: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        if bypassAuth {
            app.launchArguments = ["--uitesting"]
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Opens the sidebar by tapping the toggle and waiting for the container.
    func openSidebar() {
        let toggle = app.buttons["chat.sidebarToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Sidebar toggle should exist")
        toggle.tap()
        let sidebar = app.otherElements["sidebar.container"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 3), "Sidebar should appear")
    }

    /// Dismisses the sidebar by tapping the scrim area.
    func dismissSidebar() {
        // Tap on the right side of the screen (scrim area outside sidebar)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let sidebar = app.otherElements["sidebar.container"]
        sidebar.waitForDisappearance(timeout: 3)
    }

    /// Opens sidebar → taps user row → waits for Settings nav bar.
    func navigateToSettings() {
        openSidebar()
        let userRow = app.buttons["sidebar.userRow"]
        XCTAssertTrue(userRow.waitForExistence(timeout: 3), "User row should exist")
        userRow.tap()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings screen should appear")
    }
}
