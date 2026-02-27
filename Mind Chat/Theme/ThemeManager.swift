import SwiftUI
import Combine

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {

    // MARK: Published

    @Published var colorScheme: AppTheme {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }

    @Published var accentColorId: String {
        didSet { UserDefaults.standard.set(accentColorId, forKey: Keys.accentColor) }
    }

    @Published var fontSize: AppFontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: Keys.fontSize) }
    }

    @Published var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: Keys.highContrast) }
    }

    // MARK: Computed

    var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    var accentColor: Color {
        Color.accentPreset(accentColorId)
    }

    var typography: AppTypography {
        AppTypography.for_(fontSize)
    }

    // MARK: High-Contrast Aware Token Resolution
    // Views can call these to get the correct color for the current theme + contrast settings.

    func color(_ token: DesignToken, scheme: ColorScheme) -> Color {
        let isDark = scheme == .dark
        if highContrast {
            return isDark
                ? darkHighContrastColor(token)
                : lightHighContrastColor(token)
        }
        return isDark ? darkColor(token) : lightColor(token)
    }

    // MARK: Init

    init() {
        let storedScheme   = UserDefaults.standard.string(forKey: Keys.colorScheme)
        let storedAccent   = UserDefaults.standard.string(forKey: Keys.accentColor)
        let storedFont     = UserDefaults.standard.string(forKey: Keys.fontSize)
        let storedContrast = UserDefaults.standard.object(forKey: Keys.highContrast) as? Bool

        colorScheme   = AppTheme(rawValue: storedScheme ?? "") ?? .system
        accentColorId = storedAccent ?? "black"
        fontSize      = AppFontSize(rawValue: storedFont ?? "") ?? .medium
        highContrast  = storedContrast ?? false
    }

    // MARK: Sync from Server Settings

    func apply(settings: SettingsResponse) {
        colorScheme   = settings.theme
        accentColorId = settings.accentColor
        fontSize      = settings.fontSize
        highContrast  = settings.highContrast
    }

    // MARK: Keys

    private enum Keys {
        static let colorScheme  = "mc_theme"
        static let accentColor  = "mc_accent"
        static let fontSize     = "mc_font_size"
        static let highContrast = "mc_high_contrast"
    }

    // MARK: - Private Token Maps

    private func lightColor(_ token: DesignToken) -> Color {
        switch token {
        case .bgPrimary:     return Color.Light.bgPrimary
        case .bgSecondary:   return Color.Light.bgSecondary
        case .bgHover:       return Color.Light.bgHover
        case .bgActive:      return Color.Light.bgActive
        case .bgSidebar:     return Color.Light.bgSidebar
        case .textPrimary:   return Color.Light.textPrimary
        case .textSecondary: return Color.Light.textSecondary
        case .textTertiary:  return Color.Light.textTertiary
        case .textLink:      return Color.Light.textLink
        case .borderDefault: return Color.Light.borderDefault
        case .borderLight:   return Color.Light.borderLight
        }
    }

    private func darkColor(_ token: DesignToken) -> Color {
        switch token {
        case .bgPrimary:     return Color.Dark.bgPrimary
        case .bgSecondary:   return Color.Dark.bgSecondary
        case .bgHover:       return Color.Dark.bgHover
        case .bgActive:      return Color.Dark.bgActive
        case .bgSidebar:     return Color.Dark.bgSidebar
        case .textPrimary:   return Color.Dark.textPrimary
        case .textSecondary: return Color.Dark.textSecondary
        case .textTertiary:  return Color.Dark.textTertiary
        case .textLink:      return Color.Dark.textLink
        case .borderDefault: return Color.Dark.borderDefault
        case .borderLight:   return Color.Dark.borderLight
        }
    }

    private func lightHighContrastColor(_ token: DesignToken) -> Color {
        switch token {
        case .textPrimary:   return Color.HighContrastLight.textPrimary
        case .textSecondary: return Color.HighContrastLight.textSecondary
        case .textTertiary:  return Color.HighContrastLight.textTertiary
        case .borderDefault: return Color.HighContrastLight.borderDefault
        case .borderLight:   return Color.HighContrastLight.borderLight
        case .bgSecondary:   return Color.HighContrastLight.bgSecondary
        case .bgHover:       return Color.HighContrastLight.bgHover
        case .bgActive:      return Color.HighContrastLight.bgActive
        default:             return lightColor(token)
        }
    }

    private func darkHighContrastColor(_ token: DesignToken) -> Color {
        switch token {
        case .textPrimary:   return Color.HighContrastDark.textPrimary
        case .textSecondary: return Color.HighContrastDark.textSecondary
        case .textTertiary:  return Color.HighContrastDark.textTertiary
        case .borderDefault: return Color.HighContrastDark.borderDefault
        case .borderLight:   return Color.HighContrastDark.borderLight
        case .bgSecondary:   return Color.HighContrastDark.bgSecondary
        case .bgHover:       return Color.HighContrastDark.bgHover
        case .bgActive:      return Color.HighContrastDark.bgActive
        default:             return darkColor(token)
        }
    }
}

// MARK: - Design Token Enum

enum DesignToken {
    case bgPrimary, bgSecondary, bgHover, bgActive, bgSidebar
    case textPrimary, textSecondary, textTertiary, textLink
    case borderDefault, borderLight
}
