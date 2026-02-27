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
    @AppStorage("mc_user_name")  var persistedUserName: String  = ""
    @AppStorage("mc_user_email") var persistedUserEmail: String = ""
    @AppStorage("mc_user_id")    var persistedUserId: String    = ""

    private let auth = AuthService.shared

    init() {
        isAuthenticated = KeychainManager.shared.isAuthenticated
        // Restore persisted user on cold start (token exists but currentUser is nil)
        if isAuthenticated && !persistedUserId.isEmpty {
            currentUser = User(
                id: persistedUserId,
                email: persistedUserEmail,
                name: persistedUserName.isEmpty ? nil : persistedUserName,
                image: nil,
                emailVerified: nil
            )
        }
        if !onboardingSeen && !isAuthenticated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showOnboarding = true
            }
        }
    }

    func signIn(user: User) {
        currentUser        = user
        isAuthenticated    = true
        persistedUserId    = user.id
        persistedUserEmail = user.email
        persistedUserName  = user.name ?? ""
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
}
