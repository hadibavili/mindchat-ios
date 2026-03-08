import SwiftUI

@main
struct Mind_ChatApp: App {

    @StateObject private var appState    = AppState()
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupCrashReporting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    Task.detached(priority: .background) {
                        ImageDiskCache.shared.purgeExpired()
                    }
                }
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

    // MARK: - Crash Reporting

    private func setupCrashReporting() {
        NSSetUncaughtExceptionHandler { exception in
            ErrorReporter.shared.reportCrash(
                message: exception.reason ?? "Uncaught exception: \(exception.name.rawValue)",
                stackTrace: exception.callStackSymbols.joined(separator: "\n")
            )
        }
    }
}
