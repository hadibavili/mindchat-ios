import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                GeneralSettingsSection(vm: vm, themeManager: themeManager)
                AIModelSection(vm: vm)

                Section("Subscription") {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(vm.plan.label)
                                .foregroundStyle(Color.planColor(vm.plan))
                                .fontWeight(.semibold)
                        }
                    }
                }

                AccountSection(appState: appState)
            }
            .navigationTitle("Settings")
            .onAppear {
                // Sync VM appearance state from ThemeManager immediately (no network needed).
                vm.accentColor  = themeManager.accentColorId
                vm.theme        = themeManager.colorScheme
                vm.fontSize     = themeManager.fontSize
                vm.highContrast = themeManager.highContrast
            }
            .task {
                vm.themeManager = themeManager
                await vm.load()
            }
        }
    }
}
