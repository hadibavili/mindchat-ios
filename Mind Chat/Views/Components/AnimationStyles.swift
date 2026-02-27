import SwiftUI

// MARK: - Pressable Button Style
// Applies a satisfying spring press (scale + opacity) to any Button.

struct PressableButtonStyle: ButtonStyle {
    var scale:   CGFloat = 0.95
    var opacity: Double  = 0.75

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(
                .spring(duration: 0.25, bounce: 0.45),
                value: configuration.isPressed
            )
    }
}

// MARK: - Card Press Style
// Slightly gentler scale for larger card surfaces.

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(
                .spring(duration: 0.3, bounce: 0.35),
                value: configuration.isPressed
            )
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Applies a subtle spring-press scale to the view when wrapped in a Button.
    func pressStyle(scale: CGFloat = 0.95) -> some View {
        self.buttonStyle(PressableButtonStyle(scale: scale))
    }

    /// Applies a gentle card-level press scale (for NavigationLinks and large surfaces).
    func cardPressStyle() -> some View {
        self.buttonStyle(CardPressStyle())
    }
}

// MARK: - Spring Constants
// Reusable spring presets so every animation has the same character.

extension Animation {
    /// Snappy spring for small UI interactions (button presses, icon swaps).
    static let mcSnappy = Animation.spring(duration: 0.28, bounce: 0.4)
    /// Smooth spring for panels and layout transitions.
    static let mcSmooth = Animation.spring(duration: 0.38, bounce: 0.2)
    /// Gentle spring for content appearance (messages, cards fading in).
    static let mcGentle = Animation.spring(duration: 0.45, bounce: 0.15)
}

// MARK: - Transition Presets

extension AnyTransition {
    /// Message bubble slides up from just below and fades in.
    static let messageAppear = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )
    /// Status indicators (thinking, searching) fade + slide down from above.
    static let indicatorAppear = AnyTransition.move(edge: .top).combined(with: .opacity)
    /// Chips / pills scale up from 80% while fading in.
    static let chipAppear = AnyTransition.scale(scale: 0.82).combined(with: .opacity)
}
