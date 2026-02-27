import SwiftUI

// MARK: - Typography Scale

struct AppTypography {
    let scale: CGFloat

    // MARK: Display
    var largeTitle: Font { .system(size: 34 * scale, weight: .bold) }
    var title:      Font { .system(size: 28 * scale, weight: .bold) }
    var title2:     Font { .system(size: 22 * scale, weight: .semibold) }
    var title3:     Font { .system(size: 20 * scale, weight: .semibold) }

    // MARK: Body
    var headline:   Font { .system(size: 17 * scale, weight: .semibold) }
    var body:       Font { .system(size: 17 * scale, weight: .regular) }
    var callout:    Font { .system(size: 16 * scale, weight: .regular) }
    var subheadline:Font { .system(size: 15 * scale, weight: .regular) }
    var footnote:   Font { .system(size: 13 * scale, weight: .regular) }
    var caption:    Font { .system(size: 12 * scale, weight: .regular) }
    var caption2:   Font { .system(size: 11 * scale, weight: .regular) }

    // MARK: Mono
    var mono:       Font { .system(size: 14 * scale, weight: .regular, design: .monospaced) }
    var monoSmall:  Font { .system(size: 12 * scale, weight: .regular, design: .monospaced) }

    static func for_(_ size: AppFontSize) -> AppTypography {
        AppTypography(scale: size.scale)
    }
}

// MARK: - Environment Key

private struct TypographyKey: EnvironmentKey {
    static let defaultValue = AppTypography(scale: 1.0)
}

extension EnvironmentValues {
    var typography: AppTypography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}

// MARK: - Font Size View Modifier

struct FontSizeModifier: ViewModifier {
    let typography: AppTypography

    func body(content: Content) -> some View {
        content.environment(\.typography, typography)
    }
}

extension View {
    func appTypography(_ typography: AppTypography) -> some View {
        modifier(FontSizeModifier(typography: typography))
    }
}
