import Foundation

// MARK: - Query Intent

enum QueryIntent: String, Equatable, Sendable, Codable {
    case news
    case coding
    case reasoning
    case creative
    case casual
    case general

    var description: String {
        switch self {
        case .news:      return "news & current events"
        case .coding:    return "technical questions"
        case .reasoning: return "math & reasoning"
        case .creative:  return "creative writing"
        case .casual:    return "general"
        case .general:   return "general"
        }
    }

    var icon: String {
        switch self {
        case .news:      return "newspaper.fill"
        case .coding:    return "chevron.left.forwardslash.chevron.right"
        case .reasoning: return "function"
        case .creative:  return "pencil.tip"
        case .casual:    return "bubble.left"
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

    /// Asks the backend to classify the user's prompt into a category.
    /// Returns `nil` on any failure — caller should treat that as "no suggestion".
    static func suggestModel(prompt: String) async -> QueryIntent? {
        do {
            let response: SuggestModelResponse = try await APIClient.shared.request(
                "/api/suggest-model",
                method: "POST",
                body: SuggestModelRequest(prompt: prompt)
            )
            return response.category
        } catch {
            return nil
        }
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
        case .coding:    orderedProviders = [.claude]
        case .creative:  orderedProviders = [.claude, .openai]
        case .reasoning: orderedProviders = [.openai, .claude]
        case .casual, .general: return nil
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
