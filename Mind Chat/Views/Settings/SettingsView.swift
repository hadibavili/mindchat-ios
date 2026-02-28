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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SaveButton(vm: vm)
                }
            }
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
                await appState.refreshUser()
            }
            // Dirty tracking — any published change triggers a check
            .onChange(of: vm.provider)             { _, _ in vm.checkDirty() }
            .onChange(of: vm.model)                { _, _ in vm.checkDirty() }
            .onChange(of: vm.apiKey)               { _, _ in vm.checkDirty() }
            .onChange(of: vm.chatMemory)           { _, _ in vm.checkDirty() }
            .onChange(of: vm.theme)                { _, _ in vm.checkDirty() }
            .onChange(of: vm.fontSize)             { _, _ in vm.checkDirty() }
            .onChange(of: vm.persona)              { _, _ in vm.checkDirty() }
            .onChange(of: vm.highContrast)         { _, _ in vm.checkDirty() }
            .onChange(of: vm.accentColor)          { _, _ in vm.checkDirty() }
            .onChange(of: vm.language)             { _, _ in vm.checkDirty() }
            .onChange(of: vm.autoExtract)          { _, _ in vm.checkDirty() }
            .onChange(of: vm.showMemoryIndicators) { _, _ in vm.checkDirty() }
        }
    }
}

// MARK: - Save Button

private struct SaveButton: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        Button {
            Task { await vm.save() }
        } label: {
            Group {
                if vm.isSaving {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(vm.isDirty ? .white : .secondary)
                        Text("Saving")
                            .fontWeight(.semibold)
                            .font(.subheadline)
                    }
                } else if vm.saveSuccess {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                        Text("Saved")
                            .fontWeight(.semibold)
                            .font(.subheadline)
                    }
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: vm.isDirty)
            .animation(.easeInOut(duration: 0.2), value: vm.saveSuccess)
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving || (!vm.isDirty && !vm.saveSuccess))
    }

    private var buttonBackground: Color {
        if vm.saveSuccess { return Color.accentGreen.opacity(0.15) }
        if vm.isDirty { return Color.accentColor }
        return Color(.systemFill)
    }

    private var buttonForeground: Color {
        if vm.saveSuccess { return Color.accentGreen }
        if vm.isDirty { return .white }
        return Color(.tertiaryLabel)
    }
}
