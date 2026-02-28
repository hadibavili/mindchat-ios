import Foundation

// MARK: - Settings Service

@MainActor
final class SettingsService {

    static let shared = SettingsService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Cache Accessors

    /// Returns the last-cached settings without hitting the network (nil if cold or expired).
    func getCachedSettings() -> SettingsResponse? {
        CacheStore.shared.get(.settings)
    }

    /// Returns the last-cached usage response without hitting the network (nil if cold or expired).
    func getCachedUsage() -> UsageResponse? {
        CacheStore.shared.get(.usage)
    }

    // MARK: - Cache Management

    func invalidateCache() {
        CacheStore.shared.invalidate(.settings)
    }

    // MARK: - Fetch (always hits network, then updates cache)

    func getSettings() async throws -> SettingsResponse {
        let response: SettingsResponse = try await api.request("/api/settings")
        CacheStore.shared.set(.settings, value: response)
        return response
    }

    func updateSettings(_ update: SettingsUpdateRequest) async throws {
        let _: SuccessResponse = try await api.request(
            "/api/settings",
            method: "PUT",
            body: update
        )
        // Invalidate so the next load fetches fresh data from the server
        CacheStore.shared.invalidate(.settings)
    }

    func getUsage() async throws -> UsageResponse {
        let response: UsageResponse = try await api.request("/api/usage")
        CacheStore.shared.set(.usage, value: response)
        return response
    }
}
