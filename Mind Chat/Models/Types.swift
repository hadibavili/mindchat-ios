import Foundation

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

enum PersonaType: String, Codable, CaseIterable, Sendable {
    case concise
    case balanced
    case detailed
    case casual
    case professional

    var label: String {
        switch self {
        case .concise: return "Concise"
        case .balanced: return "Balanced"
        case .detailed: return "Detailed"
        case .casual: return "Casual"
        case .professional: return "Professional"
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

struct MessageAttachment: Codable, Identifiable, Sendable {
    let id: String
    let url: String
    let name: String
    let type: AttachmentKind
    let mimeType: String?

    enum AttachmentKind: String, Codable, Sendable {
        case image
        case file
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
