import XCTest

// MARK: - Chat Input Image UI Tests
//
// Requires: File → New → Target → UI Testing Bundle → "Mind ChatUITests", host "Mind Chat"
// Run on simulator: tests 1–3 and 5 pass; tests 4, 6–7 auto-skip on simulator.
// Run on device with an image in chat: all 7 tests pass.

final class ChatInputImageUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test 1: Attach button is present

    func test_attachButton_isPresent() throws {
        let attachButton = app.buttons["chat.input.attachButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 5),
                      "Attach (+) button should be visible in the chat input bar")
    }

    // MARK: - Test 2: Attach button is enabled

    func test_attachButton_isEnabled() throws {
        let attachButton = app.buttons["chat.input.attachButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 5))
        XCTAssertTrue(attachButton.isEnabled,
                      "Attach button should be enabled")
    }

    // MARK: - Test 3: Attach menu shows Photos option

    func test_attachMenu_showsPhotoLibraryOption() throws {
        let attachButton = app.buttons["chat.input.attachButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 5))
        attachButton.tap()

        let photoButton = app.buttons["chat.input.photoLibraryButton"]
        XCTAssertTrue(photoButton.waitForExistence(timeout: 2),
                      "Photos option should appear in the attach menu")
    }

    // MARK: - Test 4: Attach menu shows Camera option (skips on simulator)

    func test_attachMenu_showsCameraOption() throws {
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        try XCTSkipIf(isSimulator, "Camera is not available on simulator")

        let attachButton = app.buttons["chat.input.attachButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 5))
        attachButton.tap()

        let cameraButton = app.buttons["chat.input.cameraButton"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 2),
                      "Take Photo option should appear in the attach menu")
    }

    // MARK: - Test 5: Attach menu dismisses on tap outside

    func test_attachMenu_dismissesOnTapOutside() throws {
        let attachButton = app.buttons["chat.input.attachButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 5))
        attachButton.tap()

        // Wait for menu to appear
        _ = app.buttons["chat.input.photoLibraryButton"].waitForExistence(timeout: 2)

        // Tap outside the menu (top-center of screen)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()

        let photoButton = app.buttons["chat.input.photoLibraryButton"]
        XCTAssertFalse(photoButton.exists,
                       "Photo Library option should disappear after tapping outside menu")
    }

    // MARK: - Test 6: Tapping image thumbnail opens viewer

    func test_imageThumbnail_tappingOpensViewer() throws {
        let thumbnail = app.images["chat.message.imageThumbnail"]
        guard thumbnail.waitForExistence(timeout: 3) else {
            throw XCTSkip("No image thumbnail present in chat — run on device with an image in conversation history")
        }
        thumbnail.tap()

        let closeButton = app.buttons["image.viewer.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5),
                      "Image viewer close button should appear after tapping thumbnail")
    }

    // MARK: - Test 7: Image viewer close button dismisses viewer

    func test_imageViewer_closeButton_dismissesViewer() throws {
        let thumbnail = app.images["chat.message.imageThumbnail"]
        guard thumbnail.waitForExistence(timeout: 3) else {
            throw XCTSkip("No image thumbnail present in chat — run on device with an image in conversation history")
        }
        thumbnail.tap()

        let closeButton = app.buttons["image.viewer.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        XCTAssertFalse(closeButton.waitForExistence(timeout: 2),
                       "Close button should disappear after dismissing the image viewer")
    }
}
