import SwiftUI

struct ModelSelectorSheet: View {

    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var plan: PlanType = .free

    var modelsByProvider: [AIProvider: [ModelOption]] {
        Dictionary(grouping: MODEL_OPTIONS) { $0.provider }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    if let models = modelsByProvider[provider] {
                        Section(PROVIDER_LABELS[provider] ?? provider.rawValue) {
                            ForEach(models) { option in
                                let isLocked = option.comingSoon || !(PLAN_MODEL_ACCESS[plan]?.contains(option.id) ?? false)
                                Button {
                                    guard !isLocked else { return }
                                    vm.model    = option.id
                                    vm.provider = option.provider
                                    EventBus.shared.publish(.modelChanged(provider: option.provider, model: option.id))
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        // Provider color dot
                                        Circle()
                                            .fill(providerColor(option.provider))
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.label)
                                                .foregroundStyle(isLocked ? .secondary : .primary)
                                            Text(PROVIDER_LABELS[option.provider] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if option.comingSoon {
                                            SoonBadge()
                                        } else {
                                            TierBadge(tier: option.tier)
                                        }
                                        if isLocked && !option.comingSoon {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else if vm.model == option.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.mcTextLink)
                                        }
                                    }
                                }
                                .disabled(isLocked)
                            }
                        }
                    }
                }

                // Footer
                Section {
                    Text("Your memory carries over — switch models anytime without losing context.")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextTertiary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let s = try? await SettingsService.shared.getSettings() {
                    plan = s.plan
                }
            }
        }
    }

    private func providerColor(_ provider: AIProvider) -> Color {
        switch provider {
        case .openai: return Color.providerOpenAI
        case .claude: return Color.providerClaude
        case .google: return Color.providerGoogle
        case .xai:    return Color.providerXAI
        }
    }
}

struct TierBadge: View {
    let tier: ModelTier
    var body: some View {
        if tier != .free {
            Text(tier.rawValue.capitalized)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tierColor.opacity(0.15))
                .foregroundStyle(tierColor)
                .clipShape(Capsule())
        }
    }

    private var tierColor: Color {
        switch tier {
        case .free:    return .gray
        case .pro:     return .blue
        case .premium: return .purple
        }
    }
}

struct SoonBadge: View {
    var body: some View {
        Text("Soon")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.mcTextTertiary.opacity(0.15))
            .foregroundStyle(Color.mcTextTertiary)
            .clipShape(Capsule())
    }
}
