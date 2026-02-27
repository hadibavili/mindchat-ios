import Foundation

// MARK: - Stripe Service

@MainActor
final class StripeService {

    static let shared = StripeService()
    private let api = APIClient.shared

    private init() {}

    func checkoutURL(plan: String) async throws -> URL {
        struct Body: Encodable { let plan: String }
        let response: CheckoutResponse = try await api.request(
            "/api/stripe/checkout",
            method: "POST",
            body: Body(plan: plan)
        )
        guard let url = URL(string: response.url) else {
            throw AppError.networkError("Invalid checkout URL")
        }
        return url
    }

    func portalURL() async throws -> URL {
        let response: PortalResponse = try await api.request(
            "/api/stripe/portal",
            method: "POST"
        )
        guard let url = URL(string: response.url) else {
            throw AppError.networkError("Invalid portal URL")
        }
        return url
    }

    func startTrial() async throws -> TrialResponse {
        return try await api.request("/api/trial", method: "POST")
    }
}
