import Foundation

// MARK: - Auth

struct LoginResponse: Codable, Sendable {
    let token: String
    let refreshToken: String
    let user: User
}

struct RefreshResponse: Codable, Sendable {
    let token: String
    let refreshToken: String
}

// MARK: - Messages & Conversations

struct MessagesResponse: Codable, Sendable {
    let messages: [CodableChatMessage]
}

struct CodableChatMessage: Codable, Identifiable, Sendable {
    let id: String
    let content: String
    let role: MessageRole
    let conversationId: String?
    let createdAt: Date
    let attachments: [MessageAttachment]?

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            content: content,
            role: role,
            conversationId: conversationId,
            createdAt: createdAt,
            attachments: attachments
        )
    }
}

// MARK: - Topics

struct TopicsTreeResponse: Codable, Sendable {
    // The API returns TopicTreeNode[] directly
    // We decode as [TopicTreeNode]
}

struct TopicDetailResponse: Codable, Sendable {
    // Topic fields returned flat at top level
    let id: String
    let name: String
    let path: String
    let summary: String?
    let icon: String?
    let slug: String?
    let depth: Int?
    let createdAt: Date?
    let updatedAt: Date?
    // Related data
    let facts: [Fact]
    let children: [TopicWithStats]
    let parentTopic: TopicWithStats?
    let relatedTopics: [RelatedTopic]?

    // Convenience accessor so views using `detail.topic` keep working
    var topic: TopicWithStats {
        TopicWithStats(
            id: id, name: name, path: path, summary: summary, icon: icon,
            slug: slug, depth: depth,
            createdAt: createdAt, updatedAt: updatedAt,
            factCount: facts.count, subtopicCount: children.count
        )
    }
}

struct TopicLookupResponse: Codable, Sendable {
    let id: String
}

struct TopicStatsResponse: Codable, Sendable {
    let totalTopics: Int
    let totalFacts: Int
    let factsByType: FactTypeCounts
    let recentlyUpdated: [TopicWithStats]
    let topByFactCount: [TopicWithStats]
}

// MARK: - Settings & Usage

struct SettingsResponse: Codable, Sendable {
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

    enum CodingKeys: String, CodingKey {
        case provider, model, apiKey, chatMemory, theme, fontSize
        case persona = "chatMode"
        case highContrast, accentColor, language, autoExtract, showMemoryIndicators
        case plan, trialEndsAt
    }

    // Custom decoder: use defaults for any missing/unknown field so a single
    // unexpected value doesn't blow up the entire settings load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider             = (try? c.decode(AIProvider.self,      forKey: .provider))      ?? .openai
        model                = (try? c.decode(String.self,          forKey: .model))          ?? "gpt-4.1-mini"
        apiKey               = try? c.decodeIfPresent(String.self,  forKey: .apiKey)
        chatMemory           = (try? c.decode(ChatMemoryMode.self,  forKey: .chatMemory))     ?? .alwaysPersist
        theme                = (try? c.decode(AppTheme.self,        forKey: .theme))          ?? .system
        fontSize             = (try? c.decode(AppFontSize.self,     forKey: .fontSize))       ?? .medium
        persona              = (try? c.decode(PersonaType.self,     forKey: .persona))        ?? .default
        highContrast         = (try? c.decode(Bool.self,            forKey: .highContrast))   ?? false
        accentColor          = (try? c.decode(String.self,          forKey: .accentColor))    ?? "black"
        language             = (try? c.decode(String.self,          forKey: .language))       ?? "auto"
        autoExtract          = (try? c.decode(Bool.self,            forKey: .autoExtract))    ?? true
        showMemoryIndicators = (try? c.decode(Bool.self,            forKey: .showMemoryIndicators)) ?? true
        plan                 = (try? c.decode(PlanType.self,        forKey: .plan))           ?? .free
        trialEndsAt          = try? c.decodeIfPresent(Date.self,    forKey: .trialEndsAt)
    }
}

struct UsageResponse: Codable, Sendable {
    let plan: PlanType
    let limits: UsageLimits
    let trialEndsAt: Date?
    let trialExpired: Bool
    let usage: CurrentUsage

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plan        = (try? c.decode(PlanType.self,     forKey: .plan))        ?? .free
        limits      = (try? c.decode(UsageLimits.self,  forKey: .limits))      ?? UsageLimits()
        trialEndsAt = try? c.decodeIfPresent(Date.self,                          forKey: .trialEndsAt)
        trialExpired = (try? c.decode(Bool.self,        forKey: .trialExpired)) ?? false
        usage       = (try? c.decode(CurrentUsage.self, forKey: .usage))       ?? CurrentUsage()
    }
}

struct UsageLimits: Codable, Sendable {
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

    init(messagesPerDay: Int = 15, maxFacts: Int = 50, maxHistoryMessages: Int? = nil,
         voice: Bool = false, imageUploads: Bool = false, customApiKeys: Bool = false,
         priorityModels: Bool = false, customPersonas: Bool = false,
         earlyAccess: Bool = false, webSearch: Bool = false) {
        self.messagesPerDay = messagesPerDay; self.maxFacts = maxFacts
        self.maxHistoryMessages = maxHistoryMessages; self.voice = voice
        self.imageUploads = imageUploads; self.customApiKeys = customApiKeys
        self.priorityModels = priorityModels; self.customPersonas = customPersonas
        self.earlyAccess = earlyAccess; self.webSearch = webSearch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messagesPerDay      = (try? c.decode(Int.self,  forKey: .messagesPerDay))      ?? 15
        maxFacts            = (try? c.decode(Int.self,  forKey: .maxFacts))            ?? 50
        maxHistoryMessages  = try? c.decodeIfPresent(Int.self, forKey: .maxHistoryMessages)
        voice               = (try? c.decode(Bool.self, forKey: .voice))               ?? false
        imageUploads        = (try? c.decode(Bool.self, forKey: .imageUploads))        ?? false
        customApiKeys       = (try? c.decode(Bool.self, forKey: .customApiKeys))       ?? false
        priorityModels      = (try? c.decode(Bool.self, forKey: .priorityModels))      ?? false
        customPersonas      = (try? c.decode(Bool.self, forKey: .customPersonas))      ?? false
        earlyAccess         = (try? c.decode(Bool.self, forKey: .earlyAccess))         ?? false
        webSearch           = (try? c.decode(Bool.self, forKey: .webSearch))           ?? false
    }
}

// MARK: - Upload & Transcribe

struct UploadResponse: Codable, Sendable {
    let url: String
    let name: String
    let type: String   // "image" | "file"
    let mimeType: String?
}

struct TranscribeResponse: Codable, Sendable {
    let text: String
}

// MARK: - Stripe

struct CheckoutResponse: Codable, Sendable {
    let url: String
}

struct PortalResponse: Codable, Sendable {
    let url: String
}

struct TrialResponse: Codable, Sendable {
    let success: Bool
    let trialEndsAt: Date?
}

// MARK: - Generic

struct SuccessResponse: Codable, Sendable {
    let success: Bool
}

struct MessageResponse: Codable, Sendable {
    let message: String
}

struct CreateConversationResponse: Codable, Sendable {
    let id: String
}

struct RenameConversationResponse: Codable, Sendable {
    let id: String
    let title: String?
}

struct ErrorResponse: Codable, Sendable {
    let error: String
    let field: String?
}

// MARK: - Fact Update

struct FactUpdateRequest: Codable, Sendable {
    let content: String?
    let pinned: Bool?
    let confidence: Double?
}

// MARK: - Settings Update

struct SettingsUpdateRequest: Codable, Sendable {
    var provider: AIProvider?
    var model: String?
    var apiKey: String?
    var chatMemory: ChatMemoryMode?
    var theme: AppTheme?
    var fontSize: AppFontSize?
    var persona: PersonaType?
    var highContrast: Bool?
    var accentColor: String?
    var language: String?
    var autoExtract: Bool?
    var showMemoryIndicators: Bool?

    enum CodingKeys: String, CodingKey {
        case provider, model, apiKey, chatMemory, theme, fontSize
        case persona = "chatMode"
        case highContrast, accentColor, language, autoExtract, showMemoryIndicators
    }
}

// MARK: - Chat Request

struct HistoryMessage: Codable, Sendable {
    let role: MessageRole
    let content: String
}

struct ChatRequest: Codable, Sendable {
    let message: String
    let conversationId: String?
    let provider: AIProvider?
    let model: String?
    let history: [HistoryMessage]?
    let attachments: [AttachmentRef]?
    let topicId: String?

    struct AttachmentRef: Codable, Sendable {
        let url: String
        let name: String
        let type: String
        let mimeType: String?
    }
}
