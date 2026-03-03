import Foundation

// MARK: - Query Intent

enum QueryIntent: Equatable, Sendable {
    case news
    case technical
    case creative
    case math
    case research
    case general

    var description: String {
        switch self {
        case .news:      return "news & current events"
        case .technical: return "technical questions"
        case .creative:  return "creative writing"
        case .math:      return "math & reasoning"
        case .research:  return "research & facts"
        case .general:   return "general"
        }
    }

    var icon: String {
        switch self {
        case .news:      return "newspaper.fill"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .creative:  return "pencil.tip"
        case .math:      return "function"
        case .research:  return "magnifyingglass"
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

    // MARK: Weighted keyword dictionaries (value = signal strength: 1 broad, 2 solid, 3 strong)

    private static let newsKeywords: [String: Int] = [
        // weight 3 — news-exclusive
        "breaking": 3, "headline": 3, "headlines": 3, "newsfeed": 3, "bulletin": 3,
        // weight 2 — current events
        "news": 2, "latest": 2, "today": 2, "tonight": 2, "yesterday": 2,
        "update": 2, "updates": 2, "happening": 2, "current": 2, "recent": 2,
        "election": 2, "elections": 2, "vote": 2, "voting": 2, "ballot": 2,
        "politics": 2, "political": 2, "government": 2, "legislation": 2, "policy": 2,
        "president": 2, "congress": 2, "senate": 2, "parliament": 2, "minister": 2,
        "war": 2, "conflict": 2, "crisis": 2, "protest": 2, "strike": 2,
        "stock": 2, "stocks": 2, "market": 2, "markets": 2, "crypto": 2,
        "bitcoin": 2, "ethereum": 2, "inflation": 2, "gdp": 2, "recession": 2,
        "economy": 2, "economic": 2, "forecast": 2, "earnings": 2,
        "weather": 2, "storm": 2, "hurricane": 2, "earthquake": 2, "flood": 2,
        "scores": 2, "standings": 2, "championship": 2, "playoffs": 2,
        "trending": 2, "viral": 2, "announcement": 2, "launched": 2, "released": 2,
        "2024": 2, "2025": 2, "2026": 2,
        // weight 1
        "report": 1, "reported": 1, "sources": 1, "official": 1, "confirmed": 1,
        "global": 1, "worldwide": 1, "international": 1, "national": 1, "local": 1
    ]

    private static let technicalKeywords: [String: Int] = [
        // weight 3 — unmistakably technical
        "dockerfile": 3, "kubernetes": 3, "webpack": 3, "llvm": 3, "regex": 3,
        "recursion": 3, "polymorphism": 3, "middleware": 3, "orm": 3, "coroutine": 3,
        "async": 3, "await": 3, "concurrency": 3, "multithreading": 3,
        "refactor": 3, "dequeue": 3, "deserialize": 3, "serialize": 3,
        // weight 2
        "code": 2, "coding": 2, "debug": 2, "debugging": 2, "bug": 2, "bugs": 2,
        "error": 2, "errors": 2, "exception": 2, "crash": 2, "fix": 2,
        "function": 2, "method": 2, "class": 2, "struct": 2, "enum": 2, "protocol": 2,
        "api": 2, "endpoint": 2, "rest": 2, "graphql": 2, "grpc": 2, "websocket": 2,
        "database": 2, "sql": 2, "query": 2, "schema": 2, "migration": 2,
        "git": 2, "github": 2, "commit": 2, "branch": 2, "merge": 2,
        "deploy": 2, "deployment": 2, "build": 2, "ci": 2, "pipeline": 2,
        "swift": 2, "python": 2, "javascript": 2, "typescript": 2, "kotlin": 2,
        "java": 2, "ruby": 2, "golang": 2, "rust": 2, "php": 2,
        "html": 2, "css": 2, "react": 2, "vue": 2, "angular": 2, "nextjs": 2,
        "algorithm": 2, "array": 2, "dictionary": 2, "hashmap": 2,
        "server": 2, "client": 2, "request": 2, "response": 2, "http": 2,
        "authentication": 2, "authorization": 2, "oauth": 2, "jwt": 2,
        "xcode": 2, "vscode": 2, "compiler": 2, "linker": 2,
        "optimize": 2, "performance": 2, "memory": 2, "leak": 2,
        "test": 2, "testing": 2, "mock": 2, "coverage": 2,
        "npm": 2, "yarn": 2, "pip": 2, "brew": 2, "terminal": 2,
        // weight 1
        "implement": 1, "integration": 1, "library": 1, "framework": 1, "package": 1,
        "version": 1, "install": 1, "setup": 1, "configure": 1, "run": 1
    ]

    private static let creativeKeywords: [String: Int] = [
        // weight 3
        "screenplay": 3, "teleplay": 3, "haiku": 3, "sonnet": 3, "limerick": 3,
        "stanza": 3, "rhyme": 3, "rhyming": 3, "worldbuilding": 3, "fanfiction": 3,
        "monologue": 3, "soliloquy": 3,
        // weight 2
        "write": 2, "writing": 2, "draft": 2, "drafting": 2, "compose": 2,
        "story": 2, "stories": 2, "narrative": 2, "plot": 2, "character": 2,
        "dialogue": 2, "scene": 2, "chapter": 2, "novel": 2, "fiction": 2,
        "poem": 2, "poems": 2, "poetry": 2, "verse": 2, "lyrics": 2,
        "essay": 2, "article": 2, "blog": 2, "copywriting": 2, "caption": 2,
        "brainstorm": 2, "brainstorming": 2, "imagine": 2, "visualize": 2,
        "tagline": 2, "slogan": 2, "pitch": 2, "synopsis": 2, "outline": 2,
        "creative": 2, "metaphor": 2, "simile": 2,
        "roleplay": 2, "rpg": 2, "lore": 2,
        "humor": 2, "satire": 2, "parody": 2, "thriller": 2, "romance": 2,
        "comedic": 2, "dramatic": 2, "suspenseful": 2,
        // weight 1
        "describe": 1, "idea": 1, "concept": 1, "create": 1,
        "generate": 1, "produce": 1, "craft": 1, "tone": 1, "voice": 1, "style": 1
    ]

    private static let mathKeywords: [String: Int] = [
        // weight 3
        "derivative": 3, "integral": 3, "calculus": 3, "eigenvalue": 3, "eigenvector": 3,
        "determinant": 3, "logarithm": 3, "factorial": 3, "permutation": 3, "combinatorics": 3,
        "theorem": 3, "lemma": 3, "corollary": 3, "induction": 3, "modulo": 3,
        "trigonometry": 3, "polynomial": 3, "quadratic": 3,
        // weight 2
        "math": 2, "maths": 2, "mathematics": 2, "calculate": 2, "calculation": 2,
        "equation": 2, "equations": 2, "formula": 2, "solve": 2, "simplify": 2,
        "algebra": 2, "geometry": 2, "statistics": 2, "probability": 2,
        "prime": 2, "factor": 2, "fraction": 2,
        "decimal": 2, "percentage": 2, "proportion": 2,
        "mean": 2, "median": 2, "mode": 2, "variance": 2, "deviation": 2,
        "regression": 2, "correlation": 2,
        "area": 2, "perimeter": 2, "volume": 2, "angle": 2, "triangle": 2,
        "circle": 2, "polygon": 2, "coordinate": 2, "slope": 2, "intercept": 2,
        "proof": 2, "prove": 2,
        "interest": 2, "compound": 2, "annuity": 2,
        "sequence": 2, "series": 2, "limit": 2, "convergence": 2,
        "matrix": 2, "vector": 2, "tensor": 2,
        "differentiate": 2, "integrate": 2, "optimize": 2,
        // weight 1
        "count": 1, "sum": 1, "total": 1, "average": 1, "estimate": 1,
        "number": 1, "numbers": 1, "ratio": 1
    ]

    private static let researchKeywords: [String: Int] = [
        // weight 3 — pure research/lookup signals
        "etymology": 3, "bibliography": 3, "citation": 3,
        "methodology": 3, "taxonomy": 3, "chronology": 3,
        "anthropology": 3, "archaeology": 3, "linguistics": 3,
        // weight 2
        "define": 2, "definition": 2, "explain": 2, "explanation": 2,
        "history": 2, "historical": 2, "origin": 2, "origins": 2, "founded": 2,
        "invented": 2, "discovered": 2, "biography": 2, "timeline": 2,
        "compare": 2, "comparison": 2, "versus": 2, "vs": 2,
        "similar": 2, "different": 2, "between": 2,
        "science": 2, "scientific": 2, "biology": 2, "chemistry": 2,
        "physics": 2, "geography": 2, "culture": 2, "philosophy": 2,
        "literature": 2, "ancient": 2, "modern": 2, "century": 2,
        "fact": 2, "facts": 2, "meaning": 2, "significance": 2,
        "research": 2, "study": 2, "survey": 2, "findings": 2,
        "theory": 2, "principle": 2,
        "causes": 2, "effects": 2, "impact": 2, "relationship": 2,
        "evolution": 2, "development": 2, "invention": 2,
        "religion": 2, "civilization": 2, "empire": 2, "dynasty": 2,
        // weight 1
        "information": 1, "details": 1, "overview": 1, "summary": 1,
        "background": 1, "context": 1, "example": 1, "examples": 1
    ]

    // MARK: Bigram phrase boosts (two consecutive words → intent + bonus weight)

    private static let bigramBoosts: [String: (QueryIntent, Int)] = [
        // news
        "stock market": (.news, 3), "breaking news": (.news, 3),
        "current events": (.news, 2), "live updates": (.news, 2),
        "election results": (.news, 2), "interest rates": (.news, 2),
        "market cap": (.news, 2), "trade war": (.news, 2),

        // technical
        "machine learning": (.technical, 3), "neural network": (.technical, 3),
        "deep learning": (.technical, 3), "source code": (.technical, 2),
        "pull request": (.technical, 2), "unit test": (.technical, 2),
        "data structure": (.technical, 2), "design pattern": (.technical, 2),
        "open source": (.technical, 2), "code review": (.technical, 2),
        "type error": (.technical, 2), "null pointer": (.technical, 3),
        "memory leak": (.technical, 3), "stack overflow": (.technical, 3),
        "dependency injection": (.technical, 3), "state management": (.technical, 2),

        // creative
        "write me": (.creative, 2), "write a": (.creative, 2),
        "short story": (.creative, 3), "creative writing": (.creative, 3),
        "character development": (.creative, 3), "plot twist": (.creative, 2),
        "help me write": (.creative, 2), "a poem": (.creative, 2),
        "a story": (.creative, 2), "an essay": (.creative, 2),

        // math
        "word problem": (.math, 3), "number theory": (.math, 3),
        "linear algebra": (.math, 3), "differential equation": (.math, 3),
        "standard deviation": (.math, 3), "statistical analysis": (.math, 2),
        "what percentage": (.math, 2), "how many": (.math, 1),
        "square root": (.math, 3), "prime number": (.math, 3),

        // research
        "what is": (.research, 2), "who is": (.research, 2),
        "what was": (.research, 2), "who was": (.research, 2),
        "how did": (.research, 1), "why did": (.research, 1),
        "when did": (.research, 1), "explain the": (.research, 1),
        "history of": (.research, 3), "origin of": (.research, 2),
        "difference between": (.research, 2), "compared to": (.research, 2),
        "how does": (.research, 2), "what are": (.research, 1),
        "tell me": (.research, 1), "who invented": (.research, 3),
        "how was": (.research, 2), "why is": (.research, 1)
    ]

    // MARK: - Helpers

    /// Strips common English inflection suffixes to catch word variants.
    /// Tries longest suffix first; only strips if the remaining root is ≥4 chars.
    private static func normalize(_ word: String) -> String {
        let suffixes = ["ations", "ation", "ment", "ing", "tion", "ers", "ed", "er", "ly", "s"]
        for suffix in suffixes {
            if word.hasSuffix(suffix) && word.count - suffix.count >= 4 {
                return String(word.dropLast(suffix.count))
            }
        }
        return word
    }

    private static let allWeightedDicts: [([String: Int], QueryIntent)] = [
        (newsKeywords, .news),
        (technicalKeywords, .technical),
        (creativeKeywords, .creative),
        (mathKeywords, .math),
        (researchKeywords, .research)
    ]

    // MARK: - Public API

    /// Detects the dominant intent of `text` using weighted keyword scoring,
    /// bigram phrase detection, and suffix normalization.
    /// Returns `.general` if fewer than 3 words or no keywords match.
    static func detectIntent(in text: String) -> QueryIntent {
        let words = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard words.count >= 3 else { return .general }

        var scores: [QueryIntent: Int] = [:]
        var peaks:  [QueryIntent: Int] = [:]

        // 1. Single-word scoring with normalization fallback
        for word in words {
            let normalized = normalize(word)
            for (dict, intent) in allWeightedDicts {
                let w = dict[word] ?? (word != normalized ? dict[normalized] : nil)
                if let w {
                    scores[intent, default: 0] += w
                    peaks[intent] = max(peaks[intent, default: 0], w)
                }
            }
        }

        // 2. Bigram phrase scoring
        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i]) \(words[i + 1])"
            if let (intent, w) = bigramBoosts[bigram] {
                scores[intent, default: 0] += w
                peaks[intent] = max(peaks[intent, default: 0], w)
            }
        }

        // 3. Winner: highest total score; ties broken by highest single-keyword weight
        guard let maxScore = scores.values.max(), maxScore > 0 else { return .general }
        let candidates = scores.filter { $0.value == maxScore }
        if candidates.count == 1 { return candidates.keys.first! }
        return candidates.max(by: { (peaks[$0.key] ?? 0) < (peaks[$1.key] ?? 0) })?.key ?? .general
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
        case .research:  orderedProviders = [.google, .claude]
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
