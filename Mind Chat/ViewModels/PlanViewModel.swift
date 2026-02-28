import SwiftUI
import Combine

// MARK: - Plan View Model

@MainActor
final class PlanViewModel: ObservableObject {

    @Published var usage: UsageResponse?
    @Published var isLoading    = false
    @Published var isStartingTrial = false
    @Published var errorMessage: String?
    @Published var trialStarted = false

    private let settings = SettingsService.shared
    private let stripe   = StripeService.shared

    // MARK: - Load

    func load() async {
        // Phase 1: populate from disk cache instantly so plan/limits show correctly
        // before any network round-trip (no spinner, no .free flash)
        if let cached = settings.getCachedUsage() {
            usage = cached
        }

        // Phase 2: fetch fresh from server, update + re-cache
        isLoading = true
        defer { isLoading = false }
        do {
            usage = try await settings.getUsage()
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed

    var plan: PlanType { usage?.plan ?? .free }
    var messagesUsedToday: Int { usage?.usage.messagesUsedToday ?? 0 }
    var totalFacts: Int { usage?.usage.totalFacts ?? 0 }
    var messagesLimit: Int { usage?.limits.messagesPerDay ?? 15 }
    var factsLimit: Int { usage?.limits.maxFacts ?? 50 }
    var trialEndsAt: Date? { usage?.trialEndsAt }
    var trialExpired: Bool { usage?.trialExpired ?? false }
    var hasTrial: Bool { trialEndsAt != nil }

    var messagesPercent: Double {
        guard messagesLimit > 0 else { return 0 }
        return Double(messagesUsedToday) / Double(messagesLimit)
    }

    var factsPercent: Double {
        guard factsLimit > 0 else { return 0 }
        return Double(totalFacts) / Double(factsLimit)
    }

    var trialDaysRemaining: Int {
        trialEndsAt?.daysUntil ?? 0
    }

    // MARK: - Stripe

    func checkoutURL(plan: String) async -> URL? {
        do {
            return try await stripe.checkoutURL(plan: plan)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func portalURL() async -> URL? {
        do {
            return try await stripe.portalURL()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func startTrial() async {
        isStartingTrial = true
        defer { isStartingTrial = false }
        do {
            _ = try await stripe.startTrial()
            trialStarted = true
            await load()
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
