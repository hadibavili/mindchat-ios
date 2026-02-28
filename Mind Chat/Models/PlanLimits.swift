import Foundation

// MARK: - Plan Limits

struct PlanLimits: Sendable {
    let messagesPerDay: Int   // -1 = unlimited
    let maxFacts: Int         // -1 = unlimited
    let voice: Bool
    let imageUploads: Bool
    let customApiKeys: Bool
    let priorityModels: Bool
    let customPersonas: Bool
    let earlyAccess: Bool
    let webSearch: Bool
    let models: [String]
}

let PLAN_LIMITS: [PlanType: PlanLimits] = [
    .free: PlanLimits(
        messagesPerDay: 25,
        maxFacts: 50,
        voice: false,
        imageUploads: false,
        customApiKeys: false,
        priorityModels: false,
        customPersonas: false,
        earlyAccess: false,
        webSearch: false,
        models: [
            "gpt-5-nano", "gpt-4.1-mini",
            "claude-haiku-4-5-20251001",
            "gemini-2.5-flash"
        ]
    ),
    .trial: PlanLimits(
        messagesPerDay: 300,
        maxFacts: 1000,
        voice: true,
        imageUploads: true,
        customApiKeys: true,
        priorityModels: false,
        customPersonas: false,
        earlyAccess: false,
        webSearch: true,
        models: [
            "gpt-5-nano", "gpt-4.1-mini",
            "gpt-5-mini", "gpt-4.1", "o4-mini",
            "claude-haiku-4-5-20251001",
            "claude-sonnet-4-6", "claude-sonnet-4-5",
            "gemini-2.5-flash",
            "gemini-3-flash-preview", "gemini-2.5-pro"
        ]
    ),
    .pro: PlanLimits(
        messagesPerDay: 300,
        maxFacts: 1000,
        voice: true,
        imageUploads: true,
        customApiKeys: true,
        priorityModels: false,
        customPersonas: false,
        earlyAccess: false,
        webSearch: true,
        models: [
            "gpt-5-nano", "gpt-4.1-mini",
            "gpt-5-mini", "gpt-4.1", "o4-mini",
            "claude-haiku-4-5-20251001",
            "claude-sonnet-4-6", "claude-sonnet-4-5",
            "gemini-2.5-flash",
            "gemini-3-flash-preview", "gemini-2.5-pro"
        ]
    ),
    .premium: PlanLimits(
        messagesPerDay: 1000,
        maxFacts: 5000,
        voice: true,
        imageUploads: true,
        customApiKeys: true,
        priorityModels: true,
        customPersonas: true,
        earlyAccess: true,
        webSearch: true,
        models: [
            "gpt-5-nano", "gpt-4.1-mini",
            "gpt-5-mini", "gpt-4.1", "o4-mini",
            "gpt-5.2", "gpt-5.1", "o3",
            "claude-haiku-4-5-20251001",
            "claude-sonnet-4-6", "claude-sonnet-4-5",
            "claude-opus-4-6",
            "gemini-2.5-flash",
            "gemini-3-flash-preview", "gemini-2.5-pro",
            "gemini-3.1-pro-preview"
        ]
    )
]

// MARK: - Model Options

struct ModelOption: Identifiable, Sendable {
    let id: String
    let label: String
    let provider: AIProvider
    let tier: ModelTier   // "free" | "pro" | "premium"
    var comingSoon: Bool = false
}

enum ModelTier: String, Sendable, Comparable {
    case free
    case pro
    case premium

    private var order: Int {
        switch self {
        case .free:    return 0
        case .pro:     return 1
        case .premium: return 2
        }
    }

    static func < (lhs: ModelTier, rhs: ModelTier) -> Bool {
        lhs.order < rhs.order
    }
}

let MODEL_OPTIONS: [ModelOption] = [
    // OpenAI — free tier
    ModelOption(id: "gpt-5-nano",    label: "GPT-5 Nano",    provider: .openai, tier: .free),
    ModelOption(id: "gpt-4.1-mini",  label: "GPT-4.1 Mini",  provider: .openai, tier: .free),
    // OpenAI — pro tier
    ModelOption(id: "gpt-5-mini",    label: "GPT-5 Mini",    provider: .openai, tier: .pro),
    ModelOption(id: "gpt-4.1",       label: "GPT-4.1",       provider: .openai, tier: .pro),
    ModelOption(id: "o4-mini",       label: "O4 Mini",       provider: .openai, tier: .pro),
    // OpenAI — premium tier
    ModelOption(id: "gpt-5.2",       label: "GPT-5.2",       provider: .openai, tier: .premium),
    ModelOption(id: "gpt-5.1",       label: "GPT-5.1",       provider: .openai, tier: .premium),
    ModelOption(id: "o3",            label: "O3",            provider: .openai, tier: .premium),
    // Anthropic — free tier
    ModelOption(id: "claude-haiku-4-5-20251001",   label: "Claude Haiku 4.5",  provider: .claude, tier: .free),
    // Anthropic — pro tier
    ModelOption(id: "claude-sonnet-4-6",           label: "Claude Sonnet 4.6", provider: .claude, tier: .pro),
    ModelOption(id: "claude-sonnet-4-5",           label: "Claude Sonnet 4.5", provider: .claude, tier: .pro),
    // Anthropic — premium tier
    ModelOption(id: "claude-opus-4-6",             label: "Claude Opus 4.6",   provider: .claude, tier: .premium),
    // Google — free tier
    ModelOption(id: "gemini-2.5-flash",        label: "Gemini 2.5 Flash",  provider: .google, tier: .free),
    // Google — pro tier
    ModelOption(id: "gemini-3-flash-preview",  label: "Gemini 3 Flash",    provider: .google, tier: .pro),
    ModelOption(id: "gemini-2.5-pro",          label: "Gemini 2.5 Pro",    provider: .google, tier: .pro),
    // Google — premium tier
    ModelOption(id: "gemini-3.1-pro-preview",  label: "Gemini 3.1 Pro",    provider: .google, tier: .premium),
    // xAI — free tier (coming soon)
    ModelOption(id: "grok-3-mini",             label: "Grok 3 Mini",       provider: .xai, tier: .free,    comingSoon: true),
    // xAI — pro tier (coming soon)
    ModelOption(id: "grok-4-1-fast-reasoning", label: "Grok 4.1 Fast",     provider: .xai, tier: .pro,     comingSoon: true),
    ModelOption(id: "grok-3",                  label: "Grok 3",            provider: .xai, tier: .pro,     comingSoon: true),
]

// MARK: - Plan → Accessible Model Tiers

private let PLAN_MODEL_TIERS: [PlanType: Set<ModelTier>] = [
    .free:    [.free],
    .trial:   [.free, .pro],
    .pro:     [.free, .pro],
    .premium: [.free, .pro, .premium]
]

let PLAN_MODEL_ACCESS: [PlanType: Set<String>] = {
    var access: [PlanType: Set<String>] = [:]
    for plan in [PlanType.free, .trial, .pro, .premium] {
        let allowedTiers = PLAN_MODEL_TIERS[plan] ?? []
        access[plan] = Set(MODEL_OPTIONS.filter { allowedTiers.contains($0.tier) }.map(\.id))
    }
    return access
}()

// MARK: - Provider Labels

let PROVIDER_LABELS: [AIProvider: String] = [
    .openai: "OpenAI",
    .claude: "Anthropic",
    .google: "Google",
    .xai:    "xAI"
]

// MARK: - Provider Helper Text

let PROVIDER_HELPER_TEXT: [AIProvider: String] = [
    .openai: "GPT-4.1 Mini is recommended for free tier. Upgrade for GPT-4.1 and GPT-5.",
    .claude: "Haiku 4.5 is recommended for free tier. Upgrade for Sonnet and Opus.",
    .google: "Gemini 2.5 Flash is fast and capable. Upgrade for Gemini 3.",
    .xai:    "xAI models are coming soon."
]

// MARK: - API Key Placeholders

let API_KEY_PLACEHOLDERS: [AIProvider: String] = [
    .openai: "sk-proj-...",
    .claude: "sk-ant-...",
    .google: "AIza...",
    .xai:    "xai-..."
]

// MARK: - Plan Features (for comparison table)

struct PlanFeature: Sendable {
    let label: String
    let free: String
    let pro: String
    let premium: String
}

let PLAN_FEATURES: [PlanFeature] = [
    PlanFeature(label: "Messages / day",  free: "25",        pro: "300",       premium: "1,000"),
    PlanFeature(label: "Memories",        free: "50",        pro: "1,000",     premium: "5,000"),
    PlanFeature(label: "AI context",      free: "20 msgs",   pro: "50 msgs",   premium: "200 msgs"),
    PlanFeature(label: "Models",          free: "Basic",     pro: "Pro",       premium: "All"),
    PlanFeature(label: "Voice input",     free: "✗",         pro: "✓",         premium: "✓"),
    PlanFeature(label: "File uploads",    free: "✗",         pro: "✓",         premium: "✓"),
    PlanFeature(label: "Custom API key",  free: "✗",         pro: "✓",         premium: "✓"),
    PlanFeature(label: "Custom personas", free: "✗",         pro: "✗",         premium: "✓"),
    PlanFeature(label: "Early access",    free: "✗",         pro: "✗",         premium: "✓"),
]

// MARK: - Accent Colors

struct AccentColorOption: Identifiable, Sendable {
    let id: String
    let label: String
    let hex: String
}

let ACCENT_COLORS: [AccentColorOption] = [
    AccentColorOption(id: "black",  label: "Black",  hex: "#000000"),
    AccentColorOption(id: "green",  label: "Green",  hex: "#10a37f"),
    AccentColorOption(id: "blue",   label: "Blue",   hex: "#2563eb"),
    AccentColorOption(id: "purple", label: "Purple", hex: "#8b5cf6"),
    AccentColorOption(id: "pink",   label: "Pink",   hex: "#ec4899"),
    AccentColorOption(id: "orange", label: "Orange", hex: "#f97316"),
    AccentColorOption(id: "cyan",   label: "Cyan",   hex: "#06b6d4"),
    AccentColorOption(id: "red",    label: "Red",    hex: "#ef4444"),
]
