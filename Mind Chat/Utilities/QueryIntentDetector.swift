import Foundation

// MARK: - Query Intent

enum QueryIntent: Equatable, Sendable {
    case news
    case technical
    case creative
    case math
    case general

    var description: String {
        switch self {
        case .news:      return "news & current events"
        case .technical: return "technical questions"
        case .creative:  return "creative writing"
        case .math:      return "math & reasoning"
        case .general:   return "general"
        }
    }

    var icon: String {
        switch self {
        case .news:      return "newspaper.fill"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .creative:  return "pencil.tip"
        case .math:      return "function"
        case .general:   return "bubble.left"
        }
    }
}

// MARK: - Model Recommendation

struct ModelRecommendation: Equatable, Sendable {
    let intent: QueryIntent
    let provider: AIProvider
    let modelId: String
    let modelLabel: String
}

// MARK: - Query Intent Detector

enum QueryIntentDetector {

    private static let newsKeywords: Set<String> = [
        "news", "latest", "today", "breaking", "stock", "election",
        "weather", "trending", "2025", "2026"
    ]
    private static let technicalKeywords: Set<String> = [
        "code", "debug", "function", "api", "swift", "python",
        "bug", "error", "algorithm", "deploy"
    ]
    private static let creativeKeywords: Set<String> = [
        "write", "story", "poem", "brainstorm", "imagine",
        "lyrics", "essay", "screenplay"
    ]
    private static let mathKeywords: Set<String> = [
        "math", "calculate", "equation", "solve", "derivative",
        "integral", "probability", "proof"
    ]

    /// Detects the dominant intent of `text` by keyword scoring.
    /// Returns `.general` if the text has fewer than 4 words or no keywords match.
    static func detectIntent(in text: String) -> QueryIntent {
        let words = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard words.count >= 4 else { return .general }

        var scores: [QueryIntent: Int] = [
            .news: 0, .technical: 0, .creative: 0, .math: 0
        ]
        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if newsKeywords.contains(clean)      { scores[.news,      default: 0] += 1 }
            if technicalKeywords.contains(clean) { scores[.technical, default: 0] += 1 }
            if creativeKeywords.contains(clean)  { scores[.creative,  default: 0] += 1 }
            if mathKeywords.contains(clean)      { scores[.math,      default: 0] += 1 }
        }

        guard let winner = scores.max(by: { $0.value < $1.value }), winner.value > 0 else {
            return .general
        }
        return winner.key
    }

    /// Returns a `ModelRecommendation` for the given intent if a better-suited provider
    /// exists for the user's plan, or `nil` if the user is already on the best choice.
    static func recommend(
        for intent: QueryIntent,
        plan: PlanType,
        currentProvider: AIProvider,
        currentModelId: String
    ) -> ModelRecommendation? {
        let orderedProviders: [AIProvider]
        switch intent {
        case .news:      orderedProviders = [.xai, .google]
        case .technical: orderedProviders = [.claude]
        case .creative:  orderedProviders = [.claude, .openai]
        case .math:      orderedProviders = [.openai, .claude]
        case .general:   return nil
        }

        // Already on the primary recommended provider — nothing to suggest
        if let primary = orderedProviders.first, primary == currentProvider { return nil }

        let accessible = PLAN_MODEL_ACCESS[plan] ?? []

        for provider in orderedProviders where provider != currentProvider {
            let candidates = MODEL_OPTIONS
                .filter { $0.provider == provider && !$0.comingSoon && accessible.contains($0.id) }
                .sorted { $0.tier > $1.tier }
            if let best = candidates.first {
                return ModelRecommendation(
                    intent: intent,
                    provider: provider,
                    modelId: best.id,
                    modelLabel: best.label
                )
            }
        }
        return nil
    }
}
