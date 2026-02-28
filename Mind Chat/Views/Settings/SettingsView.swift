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

                // Save Button
                Section {
                    Button {
                        Task { await vm.save() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                    Text("Saving…")
                                        .fontWeight(.semibold)
                                }
                            } else if vm.saveSuccess {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentGreen)
                                    .fontWeight(.semibold)
                            } else {
                                Text("Save changes")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isSaving)
                }
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
