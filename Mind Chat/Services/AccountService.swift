import Foundation

// MARK: - Account Service

@MainActor
final class AccountService {

    static let shared = AccountService()
    private let api = APIClient.shared

    private init() {}

    /// Returns raw JSON data for the export (caller handles UIActivityViewController)
    func exportData() async throws -> Data {
        return try await api.requestRawData("/api/export")
    }

    func deleteAllData() async throws {
        let _: SuccessResponse = try await api.request("/api/account/delete-data", method: "DELETE")
    }
}
