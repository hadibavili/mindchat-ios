import SwiftUI
import Combine

// MARK: - Settings View Model

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - State

    @Published var provider:     AIProvider    = .openai
    @Published var model:        String        = "gpt-4o-mini"
    @Published var apiKey:       String        = ""
    @Published var chatMemory:   ChatMemoryMode = .alwaysPersist
    @Published var theme:        AppTheme      = .system
    @Published var fontSize:     AppFontSize   = .medium
    @Published var persona:      PersonaType   = .balanced
    @Published var highContrast: Bool          = false
    @Published var accentColor:  String        = "black"
    @Published var language:     String        = AppLanguage.auto.rawValue
    @Published var autoExtract:  Bool          = true
    @Published var showMemoryIndicators: Bool  = true
    @Published var plan:         PlanType      = .free
    @Published var trialEndsAt:  Date?         = nil

    @Published var isLoading   = false
    @Published var isSaving    = false

    private let settingsService = SettingsService.shared
    var themeManager: ThemeManager?

    private var hasLoaded = false
    private var autoSaveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(themeManager: ThemeManager? = nil) {
        self.themeManager = themeManager
        setupAutoSave()
    }

    // MARK: - Auto-Save

    private func setupAutoSave() {
        let triggers: [AnyPublisher<Void, Never>] = [
            $provider.map { _ in }.eraseToAnyPublisher(),
            $model.map { _ in }.eraseToAnyPublisher(),
            $apiKey.map { _ in }.eraseToAnyPublisher(),
            $chatMemory.map { _ in }.eraseToAnyPublisher(),
            $theme.map { _ in }.eraseToAnyPublisher(),
            $fontSize.map { _ in }.eraseToAnyPublisher(),
            $persona.map { _ in }.eraseToAnyPublisher(),
            $highContrast.map { _ in }.eraseToAnyPublisher(),
            $accentColor.map { _ in }.eraseToAnyPublisher(),
            $language.map { _ in }.eraseToAnyPublisher(),
            $autoExtract.map { _ in }.eraseToAnyPublisher(),
            $showMemoryIndicators.map { _ in }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .sink { [weak self] _ in self?.scheduleAutoSave() }
            .store(in: &cancellables)
    }

    private func scheduleAutoSave() {
        guard hasLoaded else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await settingsService.getSettings()
            provider     = s.provider
            model        = s.model
            apiKey       = s.apiKey ?? ""
            chatMemory   = s.chatMemory
            persona      = s.persona
            language     = s.language
            autoExtract  = s.autoExtract
            showMemoryIndicators = s.showMemoryIndicators
            plan         = s.plan
            trialEndsAt  = s.trialEndsAt
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
            hasLoaded = true
        } catch let e as AppError {
            ToastManager.shared.error(e.errorDescription ?? "Failed to load settings")
        } catch {
            ToastManager.shared.error(error.localizedDescription)
        }
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
