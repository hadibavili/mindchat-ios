import SwiftUI
import Combine

// MARK: - Settings View Model

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - State

    @Published var provider:     AIProvider    = .openai
    @Published var model:        String        = "gpt-4.1-mini"
    @Published var apiKey:       String        = ""
    @Published var chatMemory:   ChatMemoryMode = .alwaysPersist
    @Published var theme:        AppTheme      = .system
    @Published var fontSize:     AppFontSize   = .medium
    @Published var persona:      PersonaType   = .default
    @Published var highContrast: Bool          = false
    @Published var accentColor:  String        = "black"
    @Published var language:     String        = AppLanguage.auto.rawValue
    @Published var autoExtract:  Bool          = true
    @Published var showMemoryIndicators: Bool  = true
    @Published var plan:         PlanType      = .free
    @Published var trialEndsAt:  Date?         = nil

    @Published var isLoading    = false
    @Published var isSaving     = false
    @Published var saveSuccess  = false
    @Published var isDirty      = false

    // Snapshot of last-saved values for dirty detection
    private var savedProvider:             AIProvider     = .openai
    private var savedModel:                String         = "gpt-4.1-mini"
    private var savedApiKey:               String         = ""
    private var savedChatMemory:           ChatMemoryMode = .alwaysPersist
    private var savedTheme:                AppTheme       = .system
    private var savedFontSize:             AppFontSize    = .medium
    private var savedPersona:              PersonaType    = .default
    private var savedHighContrast:         Bool           = false
    private var savedAccentColor:          String         = "black"
    private var savedLanguage:             String         = AppLanguage.auto.rawValue
    private var savedAutoExtract:          Bool           = true
    private var savedShowMemoryIndicators: Bool           = true

    private let settingsService = SettingsService.shared
    var themeManager: ThemeManager?

    init(themeManager: ThemeManager? = nil) {
        self.themeManager = themeManager
    }

    func checkDirty() {
        isDirty = provider             != savedProvider             ||
                  model                != savedModel                ||
                  apiKey               != savedApiKey               ||
                  chatMemory           != savedChatMemory           ||
                  theme                != savedTheme                ||
                  fontSize             != savedFontSize             ||
                  persona              != savedPersona              ||
                  highContrast         != savedHighContrast         ||
                  accentColor          != savedAccentColor          ||
                  language             != savedLanguage             ||
                  autoExtract          != savedAutoExtract          ||
                  showMemoryIndicators != savedShowMemoryIndicators
    }

    private func takeSnapshot() {
        savedProvider             = provider
        savedModel                = model
        savedApiKey               = apiKey
        savedChatMemory           = chatMemory
        savedTheme                = theme
        savedFontSize             = fontSize
        savedPersona              = persona
        savedHighContrast         = highContrast
        savedAccentColor          = accentColor
        savedLanguage             = language
        savedAutoExtract          = autoExtract
        savedShowMemoryIndicators = showMemoryIndicators
        isDirty = false
    }

    // MARK: - Load

    func load() async {
        // Phase 1: populate from disk cache instantly — no spinner, no network wait
        if let cached = settingsService.getCachedSettings() {
            applySettings(cached)
        }

        // Phase 2: always fetch fresh from server so cross-platform changes
        // (e.g. persona changed in the webapp) are picked up immediately.
        let hadCache = settingsService.getCachedSettings() != nil
        if !hadCache { isLoading = true }
        defer { isLoading = false }
        // Invalidate cache before fetching so the response always overwrites disk.
        settingsService.invalidateCache()
        do {
            let s = try await settingsService.getSettings()
            applySettings(s)
        } catch let e as AppError {
            ToastManager.shared.error(e.errorDescription ?? "Failed to load settings")
        } catch {
            ToastManager.shared.error(error.localizedDescription)
        }
    }

    /// Applies a SettingsResponse to all published properties.
    private func applySettings(_ s: SettingsResponse) {
        provider             = s.provider
        // If the saved model ID is no longer in MODEL_OPTIONS (e.g. old/renamed model),
        // fall back to the first accessible model for the current provider.
        let modelKnown = MODEL_OPTIONS.contains { $0.id == s.model }
        model = modelKnown ? s.model : (MODEL_OPTIONS.first { $0.provider == s.provider }?.id ?? s.model)
        apiKey               = s.apiKey ?? ""
        chatMemory           = s.chatMemory
        persona              = s.persona
        language             = s.language
        autoExtract          = s.autoExtract
        showMemoryIndicators = s.showMemoryIndicators
        plan                 = s.plan
        trialEndsAt          = s.trialEndsAt
        // Theme settings: read from ThemeManager (UserDefaults) not from server.
        // Server may have a stale value; the local preference is authoritative.
        if let tm = themeManager {
            theme        = tm.colorScheme
            fontSize     = tm.fontSize
            highContrast = tm.highContrast
            accentColor  = tm.accentColorId
        } else {
            theme        = s.theme
            fontSize     = s.fontSize
            highContrast = s.highContrast
            accentColor  = s.accentColor
        }
        takeSnapshot()
    }

    // MARK: - Save All

    func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let update = SettingsUpdateRequest(
                provider:  provider,
                model:     model,
                apiKey:    apiKey.isEmpty ? nil : apiKey,
                chatMemory: chatMemory,
                theme:     theme,
                fontSize:  fontSize,
                persona:   persona,
                highContrast: highContrast,
                accentColor: accentColor,
                language:  language,
                autoExtract: autoExtract,
                showMemoryIndicators: showMemoryIndicators
            )
            try await settingsService.updateSettings(update)
            takeSnapshot()
            saveSuccess = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                saveSuccess = false
            }
        } catch let e as AppError {
            ToastManager.shared.error(e.errorDescription ?? "Failed to save settings")
        } catch {
            ToastManager.shared.error(error.localizedDescription)
        }
    }

    // MARK: - Visual (immediate)

    func applyTheme(_ t: AppTheme) {
        theme = t
        themeManager?.colorScheme = t
    }

    func applyAccent(_ id: String) {
        accentColor = id
        themeManager?.accentColorId = id
    }

    func applyFontSize(_ size: AppFontSize) {
        fontSize = size
        themeManager?.fontSize = size
    }

    func applyHighContrast(_ enabled: Bool) {
        highContrast = enabled
        themeManager?.highContrast = enabled
    }

    // MARK: - Trial Expiry

    var trialExpired: Bool {
        guard plan == .trial, let end = trialEndsAt else { return false }
        return end < Date()
    }

    // MARK: - Provider Change

    func resetModelForCurrentProvider() {
        let accessibleModels = MODEL_OPTIONS.filter {
            $0.provider == provider &&
            (PLAN_MODEL_ACCESS[plan]?.contains($0.id) ?? false)
        }
        model = accessibleModels.first?.id ?? ""
    }

    // MARK: - Available Models for Current Plan

    var availableModels: [ModelOption] {
        MODEL_OPTIONS.filter { PLAN_MODEL_ACCESS[plan]?.contains($0.id) ?? false }
    }

    var allModels: [ModelOption] {
        MODEL_OPTIONS
    }

    var modelsByProvider: [AIProvider: [ModelOption]] {
        Dictionary(grouping: allModels) { $0.provider }
    }
}
