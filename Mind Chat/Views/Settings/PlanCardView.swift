import SwiftUI

struct PlanCardView: View {

    let plan: PlanType
    let currentPlan: PlanType
    let onUpgrade: (String) -> Void

    var isCurrentPlan: Bool {
        plan == currentPlan || (plan == .pro && currentPlan == .trial)
    }
    var canUpgrade: Bool { plan.order > currentPlan.order && plan != .trial }

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

    private var planGradientColors: [Color] {
        switch plan {
        case .free:
            return [Color.mcTextSecondary.opacity(0.7), Color(hex: "#52525b")]
        case .trial, .pro:
            return [Color(hex: "#2383e2"), Color(hex: "#38bdf8")]
        case .premium:
            return [Color(hex: "#9065b0"), Color(hex: "#c084fc")]
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
        ZStack {
            // Gradient border ring
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isCurrentPlan
                    ? LinearGradient(colors: planGradientColors,
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.mcBorderDefault.opacity(0.35),
                                              Color.mcBorderDefault.opacity(0.2)],
                                     startPoint: .top,
                                     endPoint: .bottom))

            // Glass card content (1.5pt inset)
            cardContent
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18.5, style: .continuous))
                .padding(1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.planColor(plan).opacity(isCurrentPlan ? 0.22 : 0.04),
                radius: isCurrentPlan ? 18 : 4, x: 0, y: 4)
        .scaleEffect(isCurrentPlan ? 1.0 : 0.985)
        .animation(.mcSmooth, value: isCurrentPlan)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.label).font(.headline.bold())
                        if plan == .pro && currentPlan == .free {
                            Text("Popular")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.mcTextLink.opacity(0.1))
                                .foregroundStyle(Color.mcTextLink)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.planPro.opacity(0.4), lineWidth: 1))
                                .shadow(color: Color.planPro.opacity(0.3), radius: 6, x: 0, y: 0)
                        }
                        if plan == .premium {
                            Text("Best value")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.accentPurple.opacity(0.1))
                                .foregroundStyle(Color.accentPurple)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.accentPurple.opacity(0.4), lineWidth: 1))
                                .shadow(color: Color.accentPurple.opacity(0.3), radius: 6, x: 0, y: 0)
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
            }

            Divider().opacity(0.4)

            // Feature rows
            ForEach(features) { feature in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(feature.included
                                ? (feature.highlighted
                                    ? Color.accentPurple.opacity(0.15)
                                    : Color.accentGreen.opacity(0.15))
                                : Color.clear)
                            .frame(width: 20, height: 20)
                        Image(systemName: feature.included ? "checkmark" : "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(feature.included
                                ? (feature.highlighted ? Color.accentPurple : Color.accentGreen)
                                : Color.mcTextTertiary)
                    }
                    Text(feature.text)
                        .font(.caption)
                        .fontWeight(feature.highlighted ? .semibold : .regular)
                        .foregroundStyle(feature.highlighted ? .primary : .secondary)
                }
            }

            // CTA
            if canUpgrade && !isCurrentPlan {
                Button {
                    onUpgrade(plan.rawValue)
                } label: {
                    HStack(spacing: 6) {
                        Text("Upgrade to \(plan.label)")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(colors: planGradientColors,
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            } else if isCurrentPlan {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.planColor(plan))
                    Text("Current plan")
                        .font(.caption.bold())
                        .foregroundStyle(Color.planColor(plan))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.planColor(plan).opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(16)
    }
}
