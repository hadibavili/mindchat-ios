import Foundation

// MARK: - Settings Service

@MainActor
final class SettingsService {

    static let shared = SettingsService()
    private let api = APIClient.shared

    private init() {}

    func getSettings() async throws -> SettingsResponse {
        return try await api.request("/api/settings")
    }

    func updateSettings(_ update: SettingsUpdateRequest) async throws {
        let _: SuccessResponse = try await api.request(
            "/api/settings",
            method: "PUT",
            body: update
        )
    }

    func getUsage() async throws -> UsageResponse {
        return try await api.request("/api/usage")
    }
}
