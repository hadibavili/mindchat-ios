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
                                let isLocked = !(PLAN_MODEL_ACCESS[plan]?.contains(option.id) ?? false)
                                Button {
                                    guard !isLocked else { return }
                                    vm.model    = option.id
                                    vm.provider = option.provider
                                    EventBus.shared.publish(.modelChanged(provider: option.provider, model: option.id))
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.label)
                                                .foregroundStyle(isLocked ? .secondary : .primary)
                                            Text(PROVIDER_LABELS[option.provider] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        TierBadge(tier: option.tier)
                                        if isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else if vm.model == option.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }
                                .disabled(isLocked)
                            }
                        }
                    }
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
