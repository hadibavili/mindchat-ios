import SwiftUI

struct AIModelSection: View {

    @ObservedObject var vm: SettingsViewModel
    @State private var showApiKey = false
    @State private var showSecurityTips = false

    private var modelsForProvider: [ModelOption] {
        MODEL_OPTIONS.filter { $0.provider == vm.provider }
    }

    private var canUseApiKey: Bool {
        PLAN_LIMITS[vm.plan]?.customApiKeys ?? false
    }

    var body: some View {
        Section("AI Model") {
            // Provider
            Picker("Provider", selection: $vm.provider) {
                ForEach(AIProvider.allCases, id: \.self) { p in
                    Text(PROVIDER_LABELS[p] ?? p.rawValue).tag(p)
                }
            }
            .onChange(of: vm.provider) { _, _ in vm.resetModelForCurrentProvider() }

            // Model (filtered by provider)
            Picker("Model", selection: $vm.model) {
                ForEach(modelsForProvider) { option in
                    let accessible = PLAN_MODEL_ACCESS[vm.plan]?.contains(option.id) ?? false
                    HStack {
                        Text(option.label)
                            .foregroundStyle(accessible ? .primary : .secondary)
                        if !accessible {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(option.id)
                }
            }

            if let helperText = PROVIDER_HELPER_TEXT[vm.provider] {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Custom API Key
            if canUseApiKey {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "key").foregroundStyle(.secondary)
                        if showApiKey {
                            TextField(API_KEY_PLACEHOLDERS[vm.provider] ?? "API Key", text: $vm.apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.none)
                        } else {
                            SecureField(API_KEY_PLACEHOLDERS[vm.provider] ?? "API Key", text: $vm.apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.none)
                        }
                        Button {
                            showApiKey.toggle()
                        } label: {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Your key is encrypted at rest. Use your own key or leave blank for the platform default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Security tips collapsible
                    Button {
                        withAnimation { showSecurityTips.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSecurityTips ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Text("Security tips")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.accentColor)
                    }

                    if showSecurityTips {
                        SecurityTipsView(provider: vm.provider)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } else {
                Text("Custom API keys require a Pro or Premium plan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Save
            Button {
                Task { await vm.save() }
            } label: {
                Group {
                    if vm.isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else if vm.saveSuccess {
                        Label("Saved", systemImage: "checkmark").foregroundStyle(Color.accentGreen)
                    } else {
                        Text("Save")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(vm.isSaving)
        }
    }
}

// MARK: - Security Tips

private struct SecurityTipsView: View {
    let provider: AIProvider

    private var portalURL: String {
        switch provider {
        case .openai: return "platform.openai.com"
        case .claude: return "console.anthropic.com"
        case .google: return "aistudio.google.com"
        case .xai:    return "console.x.ai"
        }
    }

    private var tips: [String] {
        switch provider {
        case .openai:
            return [
                "Create a project-scoped key",
                "Set a monthly spending limit",
                "Restrict to \"Model\" access only",
                "Consider a separate project"
            ]
        case .claude:
            return [
                "Create a key with minimum permissions",
                "Set monthly spending limits",
                "Use workspace-scoped keys"
            ]
        case .google:
            return [
                "Restrict to Generative Language API only",
                "Set per-key quota limits",
                "Consider OAuth sign-in"
            ]
        case .xai:
            return [
                "Set spending limits",
                "Use most restrictive permissions"
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Get your key at \(portalURL)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(tips, id: \.self) { tip in
                Label(tip, systemImage: "shield.lefthalf.filled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.mcBgHover)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
