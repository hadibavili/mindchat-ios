import SwiftUI

@main
struct Mind_ChatApp: App {

    @StateObject private var appState    = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .tint(themeManager.accentColor)
                .appTypography(themeManager.typography)
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
    }
}
