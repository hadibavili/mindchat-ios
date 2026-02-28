import SwiftUI
import Combine

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    @Published var isAuthenticated    = false
    @Published var currentUser: User?
    @Published var pendingDeepLink: DeepLink?
    @Published var selectedTab: Int   = 0
    @Published var selectedConversationId: String?
    @Published var showOnboarding     = false

    @AppStorage("mc_onboarding_seen") private var onboardingSeen = false
    @AppStorage("mc_user_name")       var persistedUserName: String  = ""
    @AppStorage("mc_user_email")      var persistedUserEmail: String = ""
    @AppStorage("mc_user_id")         var persistedUserId: String    = ""
    @AppStorage("mc_email_verified")  var persistedEmailVerified: Bool = false

    private let auth = AuthService.shared

    init() {
        isAuthenticated = KeychainManager.shared.isAuthenticated
        // Restore persisted user on cold start (token exists but currentUser is nil).
        // Prefer @AppStorage values; fall back to JWT claims if storage is empty.
        if isAuthenticated {
            if !persistedUserId.isEmpty {
                currentUser = User(
                    id: persistedUserId,
                    email: persistedUserEmail,
                    name: persistedUserName.isEmpty ? nil : persistedUserName,
                    image: nil,
                    emailVerified: persistedEmailVerified ? "verified" : nil
                )
            } else if let claims = KeychainManager.shared.jwtUserClaims {
                // First launch after update — persist the JWT claims for next time
                persistedUserId       = claims.id
                persistedUserEmail    = claims.email
                persistedUserName     = claims.name ?? ""
                persistedEmailVerified = claims.emailVerified != nil
                currentUser = User(id: claims.id, email: claims.email, name: claims.name, image: nil, emailVerified: claims.emailVerified)
            }
        }
        if !onboardingSeen && !isAuthenticated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showOnboarding = true
            }
        }
    }

    func signIn(user: User) {
        currentUser            = user
        isAuthenticated        = true
        persistedUserId        = user.id
        persistedUserEmail     = user.email
        persistedUserName      = user.name ?? ""
        persistedEmailVerified = user.isEmailVerified
        if !onboardingSeen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showOnboarding = true
            }
        }
    }

    func signOut() {
        auth.signOut()
        currentUser              = nil
        isAuthenticated          = false
        selectedConversationId   = nil
        persistedUserId          = ""
        persistedUserEmail       = ""
        persistedUserName        = ""
        persistedEmailVerified   = false
        EventBus.shared.publish(.userSignedOut)
    }

    func handle(deepLink: DeepLink) {
        pendingDeepLink = deepLink
        switch deepLink {
        case .chat(let id):
            selectedTab              = 0
            selectedConversationId   = id
        case .topic:
            selectedTab = 1
        default:
            break
        }
    }

    func completeOnboarding() {
        onboardingSeen  = true
        showOnboarding  = false
    }

    /// Ensures currentUser is populated. Falls back to JWT claims if AppStorage is empty.
    func refreshUser() async {
        guard isAuthenticated else { return }
        guard currentUser == nil || persistedUserEmail.isEmpty else { return }

        if !persistedUserId.isEmpty && !persistedUserEmail.isEmpty {
            currentUser = User(
                id: persistedUserId,
                email: persistedUserEmail,
                name: persistedUserName.isEmpty ? nil : persistedUserName,
                image: nil,
                emailVerified: persistedEmailVerified ? "verified" : nil
            )
        } else if let claims = KeychainManager.shared.jwtUserClaims {
            persistedUserId        = claims.id
            persistedUserEmail     = claims.email
            persistedUserName      = claims.name ?? ""
            persistedEmailVerified = claims.emailVerified != nil
            currentUser = User(id: claims.id, email: claims.email, name: claims.name, image: nil, emailVerified: claims.emailVerified)
        }
    }
}
