import XCTest

final class AuthFlowUITests: MindChatUITestCase {

    override var bypassAuth: Bool { false }

    // MARK: - Sign In mode

    func test_defaultMode_isSignIn() {
        let subtitle = app.staticTexts["Welcome back"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5),
                      "Default mode should show 'Welcome back' subtitle")

        let signInButton = app.buttons["auth.submitButton"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 3))
        XCTAssertTrue(signInButton.label.contains("Sign In") || signInButton.staticTexts["Sign In"].exists,
                      "Submit button should say 'Sign In'")
    }

    func test_switchToSignUp_showsNameField() {
        let picker = app.segmentedControls["auth.modePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Sign Up"].tap()

        let nameField = app.textFields["Full Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3),
                      "Switching to Sign Up should show Full Name field")

        let terms = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Terms of Service'"))
        XCTAssertGreaterThan(terms.count, 0, "Terms text should be visible in sign up mode")
    }

    func test_switchBackToSignIn_hidesNameField() {
        let picker = app.segmentedControls["auth.modePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // Switch to Sign Up then back
        picker.buttons["Sign Up"].tap()
        let nameField = app.textFields["Full Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))

        picker.buttons["Sign In"].tap()

        // Name field should disappear
        XCTAssertTrue(nameField.waitForDisappearance(timeout: 3),
                      "Name field should hide after switching back to Sign In")

        // Forgot password should be visible
        let forgot = app.buttons["Forgot password?"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 3),
                      "Forgot password link should appear in Sign In mode")
    }

    func test_signIn_emptyFields_showsErrors() {
        let submitButton = app.buttons["auth.submitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        submitButton.tap()

        // At least one error label should appear
        let errorTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'required' OR label CONTAINS[c] 'valid' OR label CONTAINS[c] 'enter'"))
        // Wait briefly for validation
        sleep(1)
        XCTAssertGreaterThan(errorTexts.count, 0,
                             "Submitting empty fields should show validation errors")
    }

    func test_signIn_invalidEmail_showsError() {
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("notanemail")

        let submitButton = app.buttons["auth.submitButton"]
        submitButton.tap()

        sleep(1)
        let errorTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'email' OR label CONTAINS[c] 'valid'"))
        XCTAssertGreaterThan(errorTexts.count, 0,
                             "Invalid email should trigger an email validation error")
    }

    func test_signUp_emptyFields_showsErrors() {
        let picker = app.segmentedControls["auth.modePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Sign Up"].tap()

        let submitButton = app.buttons["auth.submitButton"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        submitButton.tap()

        sleep(1)
        let errorTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'required' OR label CONTAINS[c] 'valid' OR label CONTAINS[c] 'enter'"))
        XCTAssertGreaterThan(errorTexts.count, 0,
                             "Submitting empty sign-up form should show validation errors")
    }

    func test_passwordVisibilityToggle() {
        let toggleButton = app.buttons["auth.passwordToggle"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5),
                      "Password visibility toggle should exist")

        // Initially the password field should be secure (SecureField)
        let secureField = app.secureTextFields["Password"]
        XCTAssertTrue(secureField.waitForExistence(timeout: 3),
                      "Password should start as a secure field")

        // Tap toggle to reveal
        toggleButton.tap()
        let textField = app.textFields["Password"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "After toggle, password should be a plain text field")

        // Tap again to hide
        toggleButton.tap()
        XCTAssertTrue(secureField.waitForExistence(timeout: 3),
                      "After second toggle, password should be secure again")
    }

    func test_forgotPassword_navigates() {
        let forgot = app.buttons["Forgot password?"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 5),
                      "Forgot password link should be visible in Sign In mode")
        forgot.tap()

        // Should navigate to forgot password screen
        let resetText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'reset' OR label CONTAINS[c] 'forgot' OR label CONTAINS[c] 'email'"))
        sleep(1)
        XCTAssertGreaterThan(resetText.count, 0,
                             "Tapping Forgot password should navigate to the reset screen")
    }
}
