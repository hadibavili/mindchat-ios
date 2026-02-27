import SwiftUI
import SafariServices

struct SubscriptionView: View {

    @StateObject private var vm = PlanViewModel()
    @State private var safariURL: URL?
    @State private var isLoadingPortal = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current plan badge + manage billing
                HStack {
                    Text(vm.plan.label)
                        .font(.headline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.planColor(vm.plan).opacity(0.15))
                        .foregroundStyle(Color.planColor(vm.plan))
                        .clipShape(Capsule())
                    Spacer()
                    if vm.plan == .pro || vm.plan == .premium {
                        Button {
                            Task {
                                isLoadingPortal = true
                                defer { isLoadingPortal = false }
                                if let url = await vm.portalURL() { safariURL = url }
                            }
                        } label: {
                            if isLoadingPortal {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Manage billing")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .disabled(isLoadingPortal)
                    }
                }
                .padding(.horizontal)

                // Usage meters
                VStack(spacing: 12) {
                    Text("Usage").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    UsageMeterView(label: "Messages today",  used: vm.messagesUsedToday, limit: vm.messagesLimit)
                    UsageMeterView(label: "Memories stored", used: vm.totalFacts,         limit: vm.factsLimit)
                }
                .padding(.horizontal)

                // Trial status
                trialSection

                // Plan cards
                VStack(spacing: 12) {
                    ForEach([PlanType.free, .pro, .premium], id: \.self) { plan in
                        PlanCardView(plan: plan, currentPlan: vm.plan) { planId in
                            Task {
                                if let url = await vm.checkoutURL(plan: planId) {
                                    safariURL = url
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Comparison table
                ComparisonTableView()
                    .padding(.horizontal)

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(Color.accentRed).padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
        }
    }

    @ViewBuilder
    private var trialSection: some View {
        if let trialEnd = vm.trialEndsAt {
            if vm.trialExpired {
                // Expired trial banner
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.accentOrange)
                        Text("Your 14-day trial has ended.")
                            .fontWeight(.semibold)
                    }
                    Text("Upgrade to restore full access.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            } else {
                // Active trial — progress bar + CTA
                TrialBanner(endsAt: trialEnd)
                    .padding(.horizontal)
            }
        } else if vm.plan == .free {
            // Never trialed — start trial card
            VStack(alignment: .leading, spacing: 12) {
                Text("Try Pro free for 14 days")
                    .font(.headline.bold())
                Text("300 msgs/day, 1,000 memories, pro models, voice & file uploads. No card required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await vm.startTrial() }
                } label: {
                    Group {
                        if vm.isStartingTrial {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start free trial").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.isStartingTrial)
            }
            .padding()
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Trial Banner (active trial)

struct TrialBanner: View {
    let endsAt: Date

    private var daysRemaining: Int { max(0, endsAt.daysUntil) }
    private var progress: Double { min(1.0, Double(14 - daysRemaining) / 14.0) }
    private var isLow: Bool { daysRemaining <= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(isLow ? .orange : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(daysRemaining) days left in trial")
                        .fontWeight(.semibold)
                    Text("Expires \(endsAt.shortFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(value: progress)
                .tint(isLow ? .orange : Color.accentColor)

            Text("Enjoying Pro features? Upgrade to keep access after your trial ends.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Comparison Table

struct ComparisonTableView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plan Comparison")
                .font(.headline)
                .padding(.bottom, 12)

            // Header
            HStack {
                Text("Feature").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                Text("Free").font(.caption.bold()).frame(width: 56, alignment: .center)
                Text("Pro").font(.caption.bold()).frame(width: 56, alignment: .center)
                Text("Premium").font(.caption.bold()).frame(width: 64, alignment: .center)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.mcBgHover)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            ForEach(Array(PLAN_FEATURES.enumerated()), id: \.offset) { index, feature in
                HStack {
                    Text(feature.label)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(feature.free)
                        .font(.caption)
                        .foregroundStyle(feature.free == "✗" ? .secondary : .primary)
                        .frame(width: 56, alignment: .center)
                    Text(feature.pro)
                        .font(.caption)
                        .foregroundStyle(feature.pro == "✗" ? .secondary : .primary)
                        .frame(width: 56, alignment: .center)
                    Text(feature.premium)
                        .font(.caption)
                        .foregroundStyle(feature.premium == "✗" ? .secondary : .primary)
                        .frame(width: 64, alignment: .center)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.mcBgHover.opacity(0.5))

                if index < PLAN_FEATURES.count - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
