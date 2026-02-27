import SwiftUI
import Combine

// MARK: - Auth View Model

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: Mode

    enum Mode { case signIn, signUp }

    @Published var mode: Mode = .signIn

    // MARK: Fields

    @Published var email    = ""
    @Published var password = ""
    @Published var name     = ""
    @Published var confirmPassword = ""
    @Published var acceptedTerms = false

    // MARK: State

    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var fieldErrors: [String: String] = [:]
    @Published var successMessage: String?

    // MARK: Password Strength

    var passwordStrength: PasswordStrength? {
        guard !password.isEmpty else { return nil }
        return Validators.passwordStrength(password)
    }

    // MARK: Services

    private let auth = AuthService.shared

    // MARK: - Actions

    func submit() async {
        errorMessage = nil
        fieldErrors  = [:]

        if mode == .signIn {
            await signIn()
        } else {
            await signUp()
        }
    }

    private func signIn() async {
        guard validateSignIn() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await auth.login(email: email.lowercased(), password: password)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signUp() async {
        guard validateSignUp() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await auth.register(
                email: email.lowercased(),
                password: password,
                name: name.trimmingCharacters(in: .whitespaces),
                acceptedTerms: acceptedTerms
            )
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func googleSignIn(idToken: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await auth.loginWithGoogle(idToken: idToken)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Forgot Password VM

    @Published var forgotEmail      = ""
    @Published var forgotSent       = false
    @Published var forgotLoading    = false
    @Published var forgotError: String?

    func sendForgotPassword() async {
        forgotError = nil
        guard Validators.isValidEmail(forgotEmail) else {
            forgotError = "Enter a valid email address"
            return
        }
        forgotLoading = true
        defer { forgotLoading = false }
        do {
            try await auth.forgotPassword(email: forgotEmail.lowercased())
            forgotSent = true
        } catch let error as AppError {
            forgotError = error.errorDescription
        } catch {
            forgotError = error.localizedDescription
        }
    }

    // MARK: - Reset Password VM

    @Published var resetPassword        = ""
    @Published var resetConfirm         = ""
    @Published var resetToken           = ""
    @Published var resetLoading         = false
    @Published var resetError: String?
    @Published var resetSuccess         = false

    func submitReset() async {
        resetError = nil
        guard Validators.isValidPassword(resetPassword) else {
            resetError = "Password must be at least 8 characters"
            return
        }
        guard resetPassword == resetConfirm else {
            resetError = "Passwords do not match"
            return
        }
        resetLoading = true
        defer { resetLoading = false }
        do {
            try await auth.resetPassword(token: resetToken, password: resetPassword)
            resetSuccess = true
        } catch let error as AppError {
            resetError = error.errorDescription
        } catch {
            resetError = error.localizedDescription
        }
    }

    // MARK: - Validation

    private func validateSignIn() -> Bool {
        var valid = true
        if !Validators.isValidEmail(email) {
            fieldErrors["email"] = "Enter a valid email address"
            valid = false
        }
        if password.isEmpty {
            fieldErrors["password"] = "Enter your password"
            valid = false
        }
        return valid
    }

    private func validateSignUp() -> Bool {
        var valid = true
        if !Validators.isValidName(name) {
            fieldErrors["name"] = "Enter your full name"
            valid = false
        }
        if !Validators.isValidEmail(email) {
            fieldErrors["email"] = "Enter a valid email address"
            valid = false
        }
        if !Validators.isValidPassword(password) {
            fieldErrors["password"] = "Password must be at least 8 characters"
            valid = false
        }
        if !acceptedTerms {
            fieldErrors["terms"] = "You must accept the terms"
            valid = false
        }
        return valid
    }
}
