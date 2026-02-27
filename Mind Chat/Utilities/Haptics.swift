import UIKit

// MARK: - Haptic Feedback Helpers

enum Haptics {

    static func light() {
        #if !targetEnvironment(simulator)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func medium() {
        #if !targetEnvironment(simulator)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func heavy() {
        #if !targetEnvironment(simulator)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func success() {
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }

    static func warning() {
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func selection() {
        #if !targetEnvironment(simulator)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
}
