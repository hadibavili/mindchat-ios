import Foundation
import SwiftUI

// MARK: - Enums

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

enum FactType: String, Codable, CaseIterable, Identifiable, Sendable {
    var id: String { rawValue }
    case fact
    case preference
    case goal
    case experience

    var label: String {
        switch self {
        case .fact: return "Fact"
        case .preference: return "Preference"
        case .goal: return "Goal"
        case .experience: return "Experience"
        }
    }

    var color: String {
        switch self {
        case .fact: return "blue"
        case .preference: return "purple"
        case .goal: return "green"
        case .experience: return "orange"
        }
    }
}

enum FactImportance: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low
    case none

    var label: String {
        switch self {
        case .high: return "Important"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }
}

enum FactSortOrder: String, CaseIterable, Sendable, Identifiable {
    case newest
    case oldest
    case importance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .importance: return "Importance"
        }
    }
}

enum AIProvider: String, Codable, CaseIterable, Sendable {
    case openai = "openai"
    case claude = "claude"
    case google = "google"
    case xai = "xai"
}

enum PlanType: String, Codable, Sendable {
    case free
    case trial
    case pro
    case premium

    var label: String {
        switch self {
        case .free: return "Free"
        case .trial: return "Trial"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }

    var order: Int {
        switch self {
        case .free: return 0
        case .trial: return 1
        case .pro: return 2
        case .premium: return 3
        }
    }
}

enum PersonaType: String, Codable, CaseIterable, Hashable, Sendable {
    case `default` = "default"
    case therapy
    case teacher
    case brainstorm
    case journal

    var label: String {
        switch self {
        case .default: return "Default"
        case .therapy: return "Therapy"
        case .teacher: return "Teacher"
        case .brainstorm: return "Brainstorm"
        case .journal: return "Journal"
        }
    }

    var description: String {
        switch self {
        case .default: return "Balanced, helpful assistant — clear and genuine."
        case .therapy: return "Reflective listening, validates emotions, explores feelings."
        case .teacher: return "Socratic method, step-by-step, checks understanding."
        case .brainstorm: return "Builds on ideas, generates alternatives, never shoots down."
        case .journal: return "Prompts reflection, finds patterns, summarizes insights."
        }
    }

    var color: Color {
        switch self {
        case .default: return .green
        case .therapy: return Color(red: 0.9, green: 0.3, blue: 0.35)
        case .teacher: return .blue
        case .brainstorm: return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .journal: return Color(red: 0.55, green: 0.35, blue: 0.85)
        }
    }
}

enum ChatMemoryMode: String, Codable, CaseIterable, Sendable {
    case alwaysPersist = "persist"
    case persistClearable = "persist_clearable"
    case fresh
    case extractOnly = "extract_only"

    var label: String {
        switch self {
        case .alwaysPersist: return "Always persist"
        case .persistClearable: return "Persist & clearable"
        case .fresh: return "Fresh (no memory)"
        case .extractOnly: return "Extract only"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Sendable {
    case light
    case dark
    case system

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum AppFontSize: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.875
        case .medium: return 1.0
        case .large: return 1.15
        }
    }

}

enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case auto       = "auto"
    case english    = "en"
    case persian    = "fa"
    case german     = "de"
    case french     = "fr"
    case spanish    = "es"
    case dutch      = "nl"
    case arabic     = "ar"
    case chinese    = "zh"
    case japanese   = "ja"
    case korean     = "ko"
    case portuguese = "pt"
    case russian    = "ru"
    case turkish    = "tr"
    case italian    = "it"

    var label: String {
        switch self {
        case .auto:       return "Auto-detect"
        case .english:    return "English"
        case .persian:    return "فارسی"
        case .german:     return "Deutsch"
        case .french:     return "Français"
        case .spanish:    return "Español"
        case .dutch:      return "Nederlands"
        case .arabic:     return "العربية"
        case .chinese:    return "中文"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .portuguese: return "Português"
        case .russian:    return "Русский"
        case .turkish:    return "Türkçe"
        case .italian:    return "Italiano"
        }
    }
}

// MARK: - User & Auth

struct User: Codable, Identifiable, Sendable {
    let id: String
    let email: String
    let name: String?
    let image: String?
    let emailVerified: String?   // ISO-8601 date string or null

    var isEmailVerified: Bool { emailVerified != nil }
}

// MARK: - Conversation & Messages

struct Conversation: Codable, Identifiable, Sendable {
    let id: String
    var title: String?
    let createdAt: Date?
    var updatedAt: Date
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: String
    var content: String
    let role: MessageRole
    let conversationId: String?
    let createdAt: Date
    var attachments: [MessageAttachment]?
    var isStreaming: Bool
    var isError: Bool
    var streamingTopics: [ExtractedTopic]?
    var sources: [SearchSource]?

    init(
        id: String = UUID().uuidString,
        content: String,
        role: MessageRole,
        conversationId: String? = nil,
        createdAt: Date = Date(),
        attachments: [MessageAttachment]? = nil,
        isStreaming: Bool = false,
        isError: Bool = false,
        streamingTopics: [ExtractedTopic]? = nil,
        sources: [SearchSource]? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.conversationId = conversationId
        self.createdAt = createdAt
        self.attachments = attachments
        self.isStreaming = isStreaming
        self.isError = isError
        self.streamingTopics = streamingTopics
        self.sources = sources
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isStreaming == rhs.isStreaming &&
        lhs.isError == rhs.isError
    }
}

// MARK: - Question Form

struct QuestionItem: Identifiable, Sendable {
    let id: String
    let label: String
    let placeholder: String
}

struct QuestionFormResult: Sendable {
    /// Any prose text that appeared before the JSON block.
    let preamble: String?
    let form: QuestionForm
}

struct QuestionForm: Sendable {
    let questions: [QuestionItem]

    /// Attempts to find and parse a question-form JSON block in the message content.
    /// The JSON may be the entire content, wrapped in markdown code fences,
    /// or appended after some prose text. Returns nil if no valid question form is found.
    static func parse(from content: String) -> QuestionFormResult? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Find the start of the JSON object containing "questions"
        guard let jsonStart = trimmed.range(of: "{\"questions\"")
                           ?? trimmed.range(of: "{ \"questions\"") else { return nil }

        // Extract everything from the JSON opening brace onward
        var jsonString = String(trimmed[jsonStart.lowerBound...])

        // Strip trailing markdown code fence (```), which the LLM may append
        if let fenceRange = jsonString.range(of: "```", options: .backwards) {
            // Only strip if the fence comes after the JSON closing brace
            if let lastBrace = jsonString.range(of: "}", options: .backwards),
               lastBrace.lowerBound < fenceRange.lowerBound {
                jsonString = String(jsonString[..<fenceRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let data = jsonString.data(using: .utf8) else { return nil }

        struct RawForm: Decodable {
            struct RawQuestion: Decodable {
                let label: String
                let placeholder: String?
            }
            let questions: [RawQuestion]
        }

        guard let raw = try? JSONDecoder().decode(RawForm.self, from: data),
              !raw.questions.isEmpty else { return nil }

        // Build preamble from text before the JSON, stripping any code fence opener
        var preamble = String(trimmed[..<jsonStart.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove a trailing code fence opener like ```input or ```json or just ```
        if let fenceOpener = preamble.range(of: "```\\w*\\s*$", options: .regularExpression) {
            preamble = String(preamble[..<fenceOpener.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let form = QuestionForm(questions: raw.questions.map {
            QuestionItem(id: UUID().uuidString, label: $0.label, placeholder: $0.placeholder ?? "")
        })

        return QuestionFormResult(
            preamble: preamble.isEmpty ? nil : preamble,
            form: form
        )
    }
}

struct MessageAttachment: Codable, Identifiable, Sendable {
    let id: String
    let url: String
    let name: String
    let type: AttachmentKind
    let mimeType: String?
    /// Local JPEG data available for optimistic messages — not persisted/encoded.
    var localImageData: Data?

    enum AttachmentKind: String, Codable, Sendable {
        case image
        case file
    }

    // Exclude localImageData from Codable so it never hits the wire or breaks decoding.
    enum CodingKeys: String, CodingKey {
        case id, url, name, type, mimeType
    }

    init(id: String = UUID().uuidString, url: String, name: String, type: AttachmentKind, mimeType: String?, localImageData: Data? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.type = type
        self.mimeType = mimeType
        self.localImageData = localImageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.url = try container.decode(String.self, forKey: .url)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(AttachmentKind.self, forKey: .type)
        self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        self.localImageData = nil
    }
}

struct PendingAttachment: Identifiable, Sendable {
    let id: String = UUID().uuidString
    let localURL: URL
    let name: String
    let kind: AttachmentKind
    let mimeType: String?
    var uploadedURL: String?
    var data: Data?

    enum AttachmentKind: Sendable {
        case image
        case file
    }
}

// MARK: - Topics & Knowledge

struct Topic: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let path: String
    let summary: String?
    let icon: String?
    let createdAt: Date
    let updatedAt: Date
}

struct TopicTreeNode: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let summary: String?
    let icon: String?
    let slug: String?
    let depth: Int?
    let createdAt: Date?
    let updatedAt: Date?
    var children: [TopicTreeNode]
    let factCount: Int

    var totalFactCount: Int {
        factCount + children.reduce(0) { $0 + $1.totalFactCount }
    }
}

struct TopicWithStats: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let summary: String?
    let icon: String?
    let slug: String?
    let depth: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let factCount: Int
    let subtopicCount: Int?

    init(id: String, name: String, path: String, summary: String? = nil, icon: String? = nil,
         slug: String? = nil, depth: Int? = nil,
         createdAt: Date? = nil, updatedAt: Date? = nil,
         factCount: Int = 0, subtopicCount: Int? = nil) {
        self.id = id; self.name = name; self.path = path
        self.summary = summary; self.icon = icon
        self.slug = slug; self.depth = depth
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.factCount = factCount; self.subtopicCount = subtopicCount
    }

    // Custom decoder: factCount defaults to 0 when the server omits it (e.g. parentTopic objects)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self,  forKey: .id)
        name         = try c.decode(String.self,  forKey: .name)
        path         = try c.decode(String.self,  forKey: .path)
        summary      = try c.decodeIfPresent(String.self, forKey: .summary)
        icon         = try c.decodeIfPresent(String.self, forKey: .icon)
        slug         = try c.decodeIfPresent(String.self, forKey: .slug)
        depth        = try c.decodeIfPresent(Int.self,    forKey: .depth)
        createdAt    = try c.decodeIfPresent(Date.self,   forKey: .createdAt)
        updatedAt    = try c.decodeIfPresent(Date.self,   forKey: .updatedAt)
        factCount    = (try? c.decodeIfPresent(Int.self,  forKey: .factCount)) ?? 0
        subtopicCount = try c.decodeIfPresent(Int.self,   forKey: .subtopicCount)
    }
}

struct TopicDetail: Codable, Sendable {
    let topic: TopicWithStats
    let facts: [Fact]
    let children: [TopicWithStats]
    let parentTopic: TopicWithStats?
    let relatedTopics: [RelatedTopic]
}

struct Fact: Codable, Identifiable, Sendable {
    let id: String
    var content: String
    let type: FactType
    let topicId: String
    var pinned: Bool
    let confidence: Double?
    let importance: FactImportance?
    let createdAt: Date
    let sourceMessageId: String?
    let sourceConversationId: String?
}

struct RelatedTopic: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let relation: String?
}

struct ExtractedTopic: Codable, Sendable {
    let path: String
    let name: String
    let isNew: Bool
    let factsAdded: Int
}

struct SearchResult: Codable, Identifiable, Sendable {
    enum ResultType: String, Codable, Sendable {
        case topic
        case fact
    }
    let type: ResultType
    // Topic context (present in all results)
    let topicId: String
    let topicName: String
    let topicPath: String
    let topicIcon: String?
    let createdAt: Date
    // Fact fields (present when type == .fact)
    let factId: String?
    let factContent: String?
    let factType: FactType?
    let importance: FactImportance?

    var id: String { factId ?? topicId }
    var isFact: Bool { type == .fact }
}

struct TopicStats: Codable, Sendable {
    let totalTopics: Int
    let totalFacts: Int
    let factsByType: FactTypeCounts
    let recentlyUpdated: [Fact]
    let topByFactCount: [TopicWithStats]
}

struct FactTypeCounts: Codable, Sendable {
    let fact: Int
    let preference: Int
    let goal: Int
    let experience: Int
}

// MARK: - Settings & Usage

struct UserSettings: Codable, Sendable {
    let provider: AIProvider
    let model: String
    let apiKey: String?
    let chatMemory: ChatMemoryMode
    let theme: AppTheme
    let fontSize: AppFontSize
    let persona: PersonaType
    let highContrast: Bool
    let accentColor: String
    let language: String
    let autoExtract: Bool
    let showMemoryIndicators: Bool
    let plan: PlanType
    let trialEndsAt: Date?
}

struct UsageStats: Codable, Sendable {
    let plan: PlanType
    let limits: PlanLimitValues
    let trialEndsAt: Date?
    let trialExpired: Bool
    let usage: CurrentUsage
}

struct CurrentUsage: Codable, Sendable {
    let messagesUsedToday: Int
    let totalFacts: Int

    init(messagesUsedToday: Int = 0, totalFacts: Int = 0) {
        self.messagesUsedToday = messagesUsedToday
        self.totalFacts = totalFacts
    }
}

struct PlanLimitValues: Codable, Sendable {
    let messagesPerDay: Int
    let maxFacts: Int
    let maxHistoryMessages: Int?
    let voice: Bool
    let imageUploads: Bool
    let customApiKeys: Bool
    let priorityModels: Bool
    let customPersonas: Bool
    let earlyAccess: Bool
    let webSearch: Bool
}

// MARK: - SSE Events

struct SearchSource: Sendable {
    let title: String
    let url: String
}

enum SSEEvent: Sendable {
    case conversationId(String)
    case conversationTitle(String)
    case token(String)
    case searching
    case searchComplete(query: String, sources: [SearchSource])
    case extracting
    case topicsExtracted([ExtractedTopic])
    case error(String)
    case done
}

// MARK: - App Errors

enum AppError: LocalizedError, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(String)
    case networkError(String)
    case decodingError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Please sign in again."
        case .forbidden: return "You don't have permission to do this. Consider upgrading your plan."
        case .notFound: return "The requested resource was not found."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .serverError(let msg): return "Server error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .decodingError(let msg): return "Data error: \(msg)"
        case .unknown: return "An unknown error occurred."
        }
    }
}

// MARK: - Deep Link

enum DeepLink: Sendable {
    case resetPassword(token: String)
    case verifyEmail(token: String)
    case chat(id: String)
    case topic(path: String)

    static func from(url: URL) -> DeepLink? {
        guard url.scheme == "mindchat" else { return nil }
        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch host {
        case "reset-password":
            if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
                return .resetPassword(token: token)
            }
        case "verify-email":
            if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
                return .verifyEmail(token: token)
            }
        case "chat":
            let id = url.pathComponents.dropFirst().first ?? ""
            if !id.isEmpty { return .chat(id: id) }
        case "topics":
            let path = url.pathComponents.dropFirst().joined(separator: "/")
            if !path.isEmpty { return .topic(path: path) }
        default:
            break
        }
        return nil
    }
}
