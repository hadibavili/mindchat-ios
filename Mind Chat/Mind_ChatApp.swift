import SwiftUI

@main
struct Mind_ChatApp: App {

    @StateObject private var appState    = AppState()
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .tint(Color.mcTextPrimary)
                .appTypography(themeManager.typography)
                .dynamicTypeSize(themeManager.dynamicTypeSize)
                .environment(\.legibilityWeight, themeManager.highContrast ? .bold : nil)
                .toastOverlay()
                .onOpenURL { url in
                    if let link = DeepLink.from(url: url) {
                        appState.handle(deepLink: link)
                    }
                }
                .sheet(isPresented: $appState.showOnboarding) {
                    OnboardingView()
                        .environmentObject(appState)
                }
        }
        .task {
            Task.detached(priority: .background) {
                ImageDiskCache.shared.purgeExpired()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                EventBus.shared.publish(.appMovedToBackground)
            case .active:
                BackgroundStreamManager.shared.didReturnToForeground()
                NotificationManager.shared.clearDelivered()
                EventBus.shared.publish(.appReturnedToForeground)
            default:
                break
            }
        }
    }
}
