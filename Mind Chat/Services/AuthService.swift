import Foundation

// MARK: - Auth Service

@MainActor
final class AuthService {

    static let shared = AuthService()
    private let api = APIClient.shared
    private let keychain = KeychainManager.shared

    private init() {}

    // MARK: - Login

    func login(email: String, password: String) async throws -> User {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        let response: LoginResponse = try await api.request(
            "/api/auth/mobile/login",
            method: "POST",
            body: Body(email: email, password: password)
        )
        keychain.save(tokens: (access: response.token, refresh: response.refreshToken))
        return response.user
    }

    // MARK: - Register

    func register(email: String, password: String, name: String, acceptedTerms: Bool) async throws -> User {
        struct Body: Encodable {
            let email: String
            let password: String
            let name: String
            let acceptedTerms: Bool
        }
        let response: LoginResponse = try await api.request(
            "/api/auth/mobile/register",
            method: "POST",
            body: Body(email: email, password: password, name: name, acceptedTerms: acceptedTerms)
        )
        keychain.save(tokens: (access: response.token, refresh: response.refreshToken))
        return response.user
    }

    // MARK: - Google Sign-In

    func loginWithGoogle(idToken: String) async throws -> User {
        struct Body: Encodable {
            let googleIdToken: String
        }
        let response: LoginResponse = try await api.request(
            "/api/auth/mobile/login",
            method: "POST",
            body: Body(googleIdToken: idToken)
        )
        keychain.save(tokens: (access: response.token, refresh: response.refreshToken))
        return response.user
    }

    // MARK: - Forgot Password

    func forgotPassword(email: String) async throws {
        struct Body: Encodable { let email: String }
        let _: MessageResponse = try await api.request(
            "/api/auth/forgot-password",
            method: "POST",
            body: Body(email: email)
        )
    }

    // MARK: - Reset Password

    func resetPassword(token: String, password: String) async throws {
        struct Body: Encodable {
            let token: String
            let password: String
        }
        let _: SuccessResponse = try await api.request(
            "/api/auth/reset-password",
            method: "POST",
            body: Body(token: token, password: password)
        )
    }

    // MARK: - Resend Verification

    func resendVerification() async throws {
        let _: SuccessResponse = try await api.request(
            "/api/auth/resend-verification",
            method: "POST"
        )
    }

    // MARK: - Sign Out

    func signOut() {
        keychain.clearAll()
    }

    // MARK: - State

    var isAuthenticated: Bool {
        keychain.isAuthenticated
    }
}
