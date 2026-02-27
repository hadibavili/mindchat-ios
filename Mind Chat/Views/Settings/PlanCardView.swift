import SwiftUI

struct PlanCardView: View {

    let plan: PlanType
    let currentPlan: PlanType
    let onUpgrade: (String) -> Void

    var isCurrentPlan: Bool { plan == currentPlan }
    var canUpgrade: Bool    { plan.order > currentPlan.order && plan != .trial }

    private var tagline: String {
        switch plan {
        case .free:    return "Get started with the basics"
        case .trial:   return "Try Pro features for 14 days"
        case .pro:     return "Smarter models, more capacity"
        case .premium: return "Maximum capacity — most powerful models"
        }
    }

    private var price: String {
        switch plan {
        case .free:    return "EUR 0 / forever"
        case .trial:   return "Free for 14 days"
        case .pro:     return "EUR 10 / month"
        case .premium: return "EUR 25 / month"
        }
    }

    private struct FeatureRow: Identifiable {
        let id = UUID()
        let text: String
        let highlighted: Bool
        let included: Bool
    }

    private var features: [FeatureRow] {
        switch plan {
        case .free:
            return [
                FeatureRow(text: "25 messages / day",    highlighted: false, included: true),
                FeatureRow(text: "50 memories",           highlighted: false, included: true),
                FeatureRow(text: "Basic models",          highlighted: false, included: true),
                FeatureRow(text: "20 msg AI context",     highlighted: false, included: true),
                FeatureRow(text: "Voice & file uploads",  highlighted: false, included: false),
                FeatureRow(text: "Custom API keys",       highlighted: false, included: false),
            ]
        case .trial:
            return [
                FeatureRow(text: "300 messages / day",   highlighted: false, included: true),
                FeatureRow(text: "1,000 memories",        highlighted: false, included: true),
                FeatureRow(text: "Pro models",            highlighted: false, included: true),
                FeatureRow(text: "50 msg AI context",     highlighted: false, included: true),
                FeatureRow(text: "Voice & file uploads",  highlighted: false, included: true),
                FeatureRow(text: "No card required",      highlighted: false, included: true),
            ]
        case .pro:
            return [
                FeatureRow(text: "300 messages / day",          highlighted: false, included: true),
                FeatureRow(text: "1,000 memories",               highlighted: false, included: true),
                FeatureRow(text: "Pro models (Sonnet, GPT-4.1)", highlighted: false, included: true),
                FeatureRow(text: "50 msg AI context",            highlighted: false, included: true),
                FeatureRow(text: "Voice & file uploads",         highlighted: false, included: true),
                FeatureRow(text: "Custom API keys",              highlighted: false, included: true),
                FeatureRow(text: "Flagship models",              highlighted: false, included: false),
            ]
        case .premium:
            return [
                FeatureRow(text: "1,000 messages / day",           highlighted: true, included: true),
                FeatureRow(text: "5,000 memories",                  highlighted: true, included: true),
                FeatureRow(text: "All models — Opus, GPT-5.1, O3", highlighted: true, included: true),
                FeatureRow(text: "200 msg AI context",              highlighted: true, included: true),
                FeatureRow(text: "Voice & file uploads",            highlighted: false, included: true),
                FeatureRow(text: "Custom API keys",                 highlighted: false, included: true),
                FeatureRow(text: "Custom AI personas",              highlighted: false, included: true),
                FeatureRow(text: "Early access",                    highlighted: false, included: true),
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.label).font(.headline.bold())
                        // "Popular" badge only when user is on free plan
                        if plan == .pro && currentPlan == .free {
                            Text("Popular")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.mcTextLink.opacity(0.1))
                                .foregroundStyle(Color.mcTextLink)
                                .clipShape(Capsule())
                        }
                        // "Best value" always shown for premium
                        if plan == .premium {
                            Text("Best value")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.accentPurple.opacity(0.1))
                                .foregroundStyle(Color.accentPurple)
                                .clipShape(Capsule())
                        }
                    }
                    Text(tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(price)
                        .font(.subheadline.bold())
                        .foregroundStyle(isCurrentPlan ? Color.planColor(plan) : .primary)
                }
                Spacer()
                if isCurrentPlan {
                    Text("Current plan")
                        .font(.caption.bold())
                        .foregroundStyle(Color.planColor(plan))
                }
            }

            ForEach(features) { feature in
                HStack(spacing: 6) {
                    Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(feature.included ? Color.accentGreen : Color.mcTextTertiary)
                    Text(feature.text)
                        .font(.caption)
                        .fontWeight(feature.highlighted ? .semibold : .regular)
                        .foregroundStyle(feature.highlighted ? .primary : .secondary)
                }
            }

            if canUpgrade {
                Button {
                    onUpgrade(plan.rawValue)
                } label: {
                    Text("Upgrade to \(plan.label)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.planColor(plan))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if plan == .trial && currentPlan == .trial {
                Text("Trial active")
                    .font(.caption.bold())
                    .foregroundStyle(Color.mcTextLink)
            }
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isCurrentPlan {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.planColor(plan), lineWidth: 2)
            }
        }
    }
}
