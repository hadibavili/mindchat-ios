import SwiftUI
import Combine

// MARK: - Import Memory View Model

@MainActor
final class ImportMemoryViewModel: ObservableObject {

    // MARK: - State

    @Published var isImporting: Bool = false
    @Published var isSuccess: Bool = false
    @Published var pastedText: String = ""
    @Published var showCopied: Bool = false
    @Published var importResult: ImportMemoryResponse?
    @Published var errorMessage: String?

    // MARK: - Prompt

    static let importPrompt = """
    I'd like you to create a comprehensive summary of everything you know about me from our conversations. Format your response as a JSON array:

    [
      {
        "path": ["category", "specific-entity"],
        "facts": [
          { "content": "A clear standalone fact about this topic", "confidence": 90 }
        ],
        "type": "fact",
        "importance": "medium",
        "icon": "user"
      }
    ]

    Guidelines:
    - "path": hierarchical, max 3 levels, lowercase. E.g. ["work", "acme corp"], ["pets", "buddy"], ["relationships", "sarah"]
    - "content": standalone sentence, third person ("Works at Google" not "You work at Google")
    - "confidence": 0-100 (100 = explicitly stated, 70-90 = strongly implied)
    - "type": one of "fact", "preference", "goal", "experience"
    - "importance": one of "low", "medium", "high"
    - "icon": one of: user, users, heart, brain, stethoscope, pill, apple, dumbbell, home, utensils, briefcase, building-2, laptop, code-2, wrench, target, book-open, graduation-cap, lightbulb, wallet, credit-card, trending-up, plane, car, map-pin, globe, bike, music, camera, palette, gamepad-2, film, headphones, tree-pine, mountain, coffee, pizza, smartphone, trophy, star, calendar, dog, cat, gift, sparkles

    Cover everything: personal info, work, education, relationships, health, hobbies, preferences, goals, routines, finances, travel, significant events, and anything else.

    Be thorough — include even small details. Only include things I actually told you. Output ONLY the JSON array.
    """

    var canImport: Bool {
        !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isImporting
    }

    var promptPreview: String {
        let trimmed = Self.importPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 150 {
            return String(trimmed.prefix(150)) + "..."
        }
        return trimmed
    }

    // MARK: - Actions

    func copyPrompt() {
        UIPasteboard.general.string = Self.importPrompt
        Haptics.light()
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showCopied = false
        }
    }

    func performImport() async {
        guard canImport else { return }
        isImporting = true
        errorMessage = nil
        do {
            let response = try await AccountService.shared.importMemory(rawText: pastedText)
            importResult = response
            isSuccess = true
            isImporting = false
            Haptics.success()
            EventBus.shared.publish(.topicsUpdated)
            EventBus.shared.publish(.factsUpdated)
        } catch {
            if let appError = error as? AppError {
                errorMessage = appError.errorDescription ?? "Import failed. Please try again."
            } else {
                errorMessage = error.localizedDescription
            }
            isImporting = false
            Haptics.error()
        }
    }

    func reset() {
        pastedText = ""
        importResult = nil
        errorMessage = nil
        isSuccess = false
    }

    func tryAgain() {
        errorMessage = nil
    }
}
