import Foundation
@testable import Mind_Chat

// MARK: - Mock Settings Service

@MainActor
final class MockSettingsService: SettingsServiceProtocol {

    // MARK: - Stubs
    var cachedSettings: SettingsResponse?
    var cachedUsage: UsageResponse?
    var networkSettings: SettingsResponse?
    var networkUsage: UsageResponse?
    var networkSettingsError: Error?
    var networkUsageError: Error?

    // MARK: - Call Tracking
    var getSettingsCallCount = 0
    var getUsageCallCount = 0
    var updateSettingsCallCount = 0
    var lastUpdateRequest: SettingsUpdateRequest?

    // MARK: - SettingsServiceProtocol

    func getCachedSettings() -> SettingsResponse? { cachedSettings }
    func getCachedUsage() -> UsageResponse? { cachedUsage }

    func getSettings() async throws -> SettingsResponse {
        getSettingsCallCount += 1
        if let e = networkSettingsError { throw e }
        return networkSettings ?? MockSettingsService.makeSettings()
    }

    func getUsage() async throws -> UsageResponse {
        getUsageCallCount += 1
        if let e = networkUsageError { throw e }
        return networkUsage ?? MockSettingsService.makeUsage()
    }

    func updateSettings(_ update: SettingsUpdateRequest) async throws {
        updateSettingsCallCount += 1
        lastUpdateRequest = update
    }

    // MARK: - Fixture Builders

    static func makeSettings(
        provider: AIProvider = .openai,
        model: String = "gpt-4.1-mini",
        plan: PlanType = .free,
        persona: PersonaType = .default,
        chatMemory: ChatMemoryMode = .alwaysPersist,
        showMemoryIndicators: Bool = true
    ) -> SettingsResponse {
        let json = """
        {
          "provider": "\(provider.rawValue)",
          "model": "\(model)",
          "chatMemory": "\(chatMemory.rawValue)",
          "chatMode": "\(persona.rawValue)",
          "theme": "system",
          "fontSize": "medium",
          "highContrast": false,
          "accentColor": "black",
          "language": "auto",
          "autoExtract": true,
          "showMemoryIndicators": \(showMemoryIndicators),
          "plan": "\(plan.rawValue)"
        }
        """.data(using: .utf8)!
        return try! JSONDecoder.mindChat.decode(SettingsResponse.self, from: json)
    }

    static func makeUsage(
        plan: PlanType = .free,
        voice: Bool = false,
        imageUploads: Bool = false
    ) -> UsageResponse {
        let json = """
        {
          "plan": "\(plan.rawValue)",
          "limits": {
            "messagesPerDay": 15,
            "maxFacts": 50,
            "voice": \(voice),
            "imageUploads": \(imageUploads),
            "customApiKeys": false,
            "priorityModels": false,
            "customPersonas": false,
            "earlyAccess": false,
            "webSearch": false
          },
          "trialExpired": false,
          "usage": { "messagesUsedToday": 0, "totalFacts": 0 }
        }
        """.data(using: .utf8)!
        return try! JSONDecoder.mindChat.decode(UsageResponse.self, from: json)
    }
}
