import SwiftUI
import SafariServices

struct SubscriptionView: View {

    @StateObject private var vm = PlanViewModel()
    @State private var safariURL: URL?
    @State private var isLoadingPortal = false
    @State private var selectedPlanIndex: Int? = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PlanHeroHeader(
                    plan: vm.plan,
                    isLoadingPortal: isLoadingPortal,
                    onManageBilling: {
                        Task {
                            isLoadingPortal = true
                            defer { isLoadingPortal = false }
                            if let url = await vm.portalURL() { safariURL = url }
                        }
                    }
                )

                // Usage meters
                HStack(spacing: 12) {
                    UsageMeterView(label: "Messages", icon: "message.fill",
                                   used: vm.messagesUsedToday, limit: vm.messagesLimit)
                    UsageMeterView(label: "Memories", icon: "brain.head.profile",
                                   used: vm.totalFacts, limit: vm.factsLimit)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // Trial section
                trialSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Plan carousel
                Text("Choose your plan")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                planPickerTabs
                    .padding(.top, 6)

                planCarousel

                // Comparison
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan comparison")
                        .font(.title3.bold())
                    ComparisonTableView()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(Color.accentRed).padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .sheet(item: $safariURL) { url in SafariView(url: url) }
    }

    // MARK: - Plan Carousel

    private var planCarousel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array([PlanType.free, .pro, .premium].enumerated()), id: \.element) { idx, plan in
                        PlanCardView(plan: plan, currentPlan: vm.plan) { planId in
                            Task {
                                if let url = await vm.checkoutURL(plan: planId) {
                                    safariURL = url
                                }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width - 80)
                        .id(idx)
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1.0 : 0.72)
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.93)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedPlanIndex)
            .onAppear { selectedPlanIndex = planIndex(for: vm.plan) }
            .onChange(of: vm.plan) { _, p in
                withAnimation(.mcSmooth) { selectedPlanIndex = planIndex(for: p) }
            }

            pageDots
        }
    }

    private func planIndex(for plan: PlanType) -> Int {
        switch plan {
        case .free:           return 0
        case .trial, .pro:   return 1
        case .premium:        return 2
        }
    }

    // MARK: - Plan Gradient (local helper, mirrors PlanCardView)

    private func planGradientColors(for plan: PlanType) -> [Color] {
        switch plan {
        case .free:          return [Color.mcTextSecondary.opacity(0.7), Color(hex: "#52525b")]
        case .trial, .pro:  return [Color(hex: "#2383e2"), Color(hex: "#38bdf8")]
        case .premium:       return [Color(hex: "#9065b0"), Color(hex: "#c084fc")]
        }
    }

    // MARK: - Plan Picker Tabs

    private var planPickerTabs: some View {
        HStack(spacing: 4) {
            ForEach(Array([PlanType.free, PlanType.pro, PlanType.premium].enumerated()), id: \.element) { idx, plan in
                Button {
                    withAnimation(.mcSnappy) { selectedPlanIndex = idx }
                } label: {
                    Text(plan.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(selectedPlanIndex == idx ? .white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if selectedPlanIndex == idx {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: planGradientColors(for: plan),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle(scale: 0.96))
            }
        }
        .padding(4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(.horizontal, 24)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { idx in
                let plan = [PlanType.free, PlanType.pro, PlanType.premium][idx]
                let isSelected = selectedPlanIndex == idx
                Capsule()
                    .fill(isSelected
                        ? LinearGradient(colors: planGradientColors(for: plan),
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.secondary.opacity(0.25),
                                                  Color.secondary.opacity(0.25)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: isSelected ? 20 : 6, height: 6)
                    .animation(.mcSnappy, value: selectedPlanIndex)
            }
        }
    }

    // MARK: - Trial Section

    @ViewBuilder
    private var trialSection: some View {
        if let trialEnd = vm.trialEndsAt {
            if vm.trialExpired {
                expiredTrialBanner
            } else {
                TrialBanner(endsAt: trialEnd)
            }
        } else if vm.plan == .free {
            startTrialCard
        }
    }

    private var expiredTrialBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentOrange)
                .symbolEffect(.bounce, options: .repeating)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your 14-day trial has ended.")
                    .font(.subheadline.bold())
                Text("Upgrade to restore full access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.mcSmooth) { selectedPlanIndex = 1 }
            } label: {
                Text("Upgrade")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(colors: [Color(hex: "#2383e2"), Color(hex: "#38bdf8")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentOrange.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.accentOrange.opacity(0.08), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var startTrialCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Color.planPro)
                    .symbolEffect(.variableColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try Pro free for 14 days")
                        .font(.subheadline.bold())
                    Text("300 msgs/day · 1,000 memories · Pro models · Voice & files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await vm.startTrial() }
            } label: {
                Group {
                    if vm.isStartingTrial {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start free trial — no card required")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [Color(hex: "#2383e2"), Color(hex: "#38bdf8")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(vm.isStartingTrial)
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color(hex: "#2383e2").opacity(0.5),
                                            Color(hex: "#38bdf8").opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Plan Hero Header

private struct PlanHeroHeader: View {

    let plan: PlanType
    let isLoadingPortal: Bool
    let onManageBilling: () -> Void

    private var meshColors: [Color] {
        switch plan {
        case .free:
            return [
                Color(hex: "#3a3a40"), Color(hex: "#52525b"), Color(hex: "#3a3a40"),
                Color(hex: "#27272a"), Color(hex: "#3a3a40"), Color(hex: "#27272a"),
                Color(hex: "#18181b"), Color(hex: "#27272a"), Color(hex: "#18181b"),
            ]
        case .trial, .pro:
            return [
                Color(hex: "#1e3a8a"), Color(hex: "#2563eb"), Color(hex: "#60a5fa"),
                Color(hex: "#1e40af"), Color(hex: "#3b82f6"), Color(hex: "#60a5fa"),
                Color(hex: "#0f172a"), Color(hex: "#1e3a8a"), Color(hex: "#0f172a"),
            ]
        case .premium:
            return [
                Color(hex: "#4c1d95"), Color(hex: "#7c3aed"), Color(hex: "#c084fc"),
                Color(hex: "#5b21b6"), Color(hex: "#8b5cf6"), Color(hex: "#c084fc"),
                Color(hex: "#1e1b4b"), Color(hex: "#4c1d95"), Color(hex: "#1e1b4b"),
            ]
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                    .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                    .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0),
                ],
                colors: meshColors
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR CURRENT PLAN")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.7))

                Text(plan.label)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 7, height: 7)
                        Text(plan.label)
                            .font(.caption.bold())
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())

                    if plan == .pro || plan == .premium {
                        Button { onManageBilling() } label: {
                            HStack(spacing: 4) {
                                if isLoadingPortal {
                                    ProgressView().scaleEffect(0.65).tint(.white)
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.caption2)
                                    Text("Manage billing")
                                        .font(.caption.bold())
                                }
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: Capsule())
                        }
                        .disabled(isLoadingPortal)
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 28,
            bottomTrailingRadius: 28, topTrailingRadius: 0
        ))
        .animation(.mcSmooth, value: plan)
    }
}

// MARK: - Trial Banner (active trial)

struct TrialBanner: View {
    let endsAt: Date

    private var daysRemaining: Int { max(0, endsAt.daysUntil) }
    private var elapsedProgress: Double { min(1.0, Double(14 - daysRemaining) / 14.0) }
    private var isLow: Bool { daysRemaining <= 3 }

    @State private var animatedFraction = 0.0

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ArcRingView(
                    fraction: animatedFraction,
                    lineWidth: 7,
                    trackColor: Color.secondary.opacity(0.15),
                    fillColors: isLow
                        ? [Color.accentOrange, Color.accentRed]
                        : [Color.planPro, Color.mcTextLink]
                )
                .frame(width: 70, height: 70)

                VStack(spacing: 1) {
                    Text("\(daysRemaining)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(daysRemaining) days left in trial")
                    .font(.subheadline.bold())
                Text("Expires \(endsAt.shortFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Enjoying Pro? Upgrade to keep access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            LinearGradient(
                colors: [(isLow ? Color.accentOrange : Color.planPro).opacity(0.08), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(Animation.mcSmooth.delay(0.25)) {
                animatedFraction = elapsedProgress
            }
        }
    }
}

// MARK: - Comparison Table

struct ComparisonTableView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text("Feature").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                Text("Free").font(.caption.bold()).foregroundStyle(Color.planFree).frame(width: 56, alignment: .center)
                Text("Pro").font(.caption.bold()).foregroundStyle(Color.planPro).frame(width: 56, alignment: .center)
                Text("Premium").font(.caption.bold()).foregroundStyle(Color.planPremium).frame(width: 64, alignment: .center)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.mcBgHover.opacity(0.5))

            ForEach(Array(PLAN_FEATURES.enumerated()), id: \.offset) { index, feature in
                HStack {
                    Text(feature.label)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    comparisonCell(value: feature.free,    plan: .free)
                        .frame(width: 56, alignment: .center)
                    comparisonCell(value: feature.pro,     plan: .pro)
                        .frame(width: 56, alignment: .center)
                    comparisonCell(value: feature.premium, plan: .premium)
                        .frame(width: 64, alignment: .center)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.mcBgHover.opacity(0.3))

                if index < PLAN_FEATURES.count - 1 {
                    Divider().padding(.horizontal, 12).opacity(0.4)
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func comparisonCell(value: String, plan: PlanType) -> some View {
        switch value {
        case "✓":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.planColor(plan))
                .font(.caption)
        case "✗":
            Image(systemName: "xmark.circle")
                .foregroundStyle(Color.mcTextTertiary)
                .font(.caption)
        default:
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
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
