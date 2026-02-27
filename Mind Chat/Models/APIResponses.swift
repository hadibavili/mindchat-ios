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
    let recentlyUpdated: [Fact]
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
}

struct UsageResponse: Codable, Sendable {
    let plan: PlanType
    let limits: UsageLimits
    let trialEndsAt: Date?
    let trialExpired: Bool
    let usage: CurrentUsage
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

    struct AttachmentRef: Codable, Sendable {
        let url: String
        let name: String
        let type: String
        let mimeType: String?
    }
}
