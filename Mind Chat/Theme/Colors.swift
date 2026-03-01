import SwiftUI

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8 & 0xF) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Adaptive Helper

extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Light Mode Palette

extension Color {
    enum Light {
        static let bgPrimary     = Color(hex: "#ffffff")
        static let bgSecondary   = Color(hex: "#f7f6f3")
        static let bgHover       = Color(hex: "#f0efec")
        static let bgActive      = Color(hex: "#e9e9e7")
        static let bgSidebar     = Color(hex: "#f7f6f3")
        static let textPrimary   = Color(hex: "#37352f")
        static let textSecondary = Color(hex: "#787774")
        static let textTertiary  = Color(hex: "#9b9a97")
        static let textLink      = Color(hex: "#2383e2")
        static let borderDefault = Color(hex: "#e9e9e7")
        static let borderLight   = Color(hex: "#f0efec")
    }
}

// MARK: - Dark Mode Palette

extension Color {
    enum Dark {
        static let bgPrimary     = Color(hex: "#09090b")
        static let bgSecondary   = Color(hex: "#18181b")
        static let bgHover       = Color(hex: "#27272a")
        static let bgActive      = Color(hex: "#3f3f46")
        static let bgSidebar     = Color(hex: "#111113")
        static let textPrimary   = Color(hex: "#fafafa")
        static let textSecondary = Color(hex: "#a1a1aa")
        static let textTertiary  = Color(hex: "#71717a")
        static let textLink      = Color(hex: "#60a5fa")
        static let borderDefault = Color(hex: "#27272a")
        static let borderLight   = Color(hex: "#1e1e22")
    }
}

// MARK: - High Contrast Overrides

extension Color {
    enum HighContrastLight {
        static let textPrimary   = Color(hex: "#1a1917")
        static let textSecondary = Color(hex: "#37352f")
        static let textTertiary  = Color(hex: "#787774")
        static let borderDefault = Color(hex: "#9b9a97")
        static let borderLight   = Color(hex: "#d3d1cb")
        static let bgSecondary   = Color(hex: "#f0efec")
        static let bgHover       = Color(hex: "#e9e9e7")
        static let bgActive      = Color(hex: "#d3d1cb")
    }

    enum HighContrastDark {
        static let textPrimary   = Color(hex: "#f5f5f5")
        static let textSecondary = Color(hex: "#c0c0c0")
        static let textTertiary  = Color(hex: "#999999")
        static let borderDefault = Color(hex: "#555555")
        static let borderLight   = Color(hex: "#444444")
        static let bgSecondary   = Color(hex: "#1e1e22")
        static let bgHover       = Color(hex: "#2a2a2e")
        static let bgActive      = Color(hex: "#3a3a3e")
    }
}

// MARK: - Adaptive Design Tokens (auto light/dark)

extension Color {
    static let mcBgPrimary     = adaptive(light: Light.bgPrimary,     dark: Dark.bgPrimary)
    static let mcBgSecondary   = adaptive(light: Light.bgSecondary,   dark: Dark.bgSecondary)
    static let mcBgHover       = adaptive(light: Light.bgHover,       dark: Dark.bgHover)
    static let mcBgActive      = adaptive(light: Light.bgActive,      dark: Dark.bgActive)
    static let mcBgSidebar     = adaptive(light: Light.bgSidebar,     dark: Dark.bgSidebar)
    static let mcTextPrimary   = adaptive(light: Light.textPrimary,   dark: Dark.textPrimary)
    static let mcTextSecondary = adaptive(light: Light.textSecondary, dark: Dark.textSecondary)
    static let mcTextTertiary  = adaptive(light: Light.textTertiary,  dark: Dark.textTertiary)
    static let mcTextLink      = adaptive(light: Light.textLink,      dark: Dark.textLink)
    static let mcBorderDefault = adaptive(light: Light.borderDefault, dark: Dark.borderDefault)
    static let mcBorderLight   = adaptive(light: Light.borderLight,   dark: Dark.borderLight)
}

// MARK: - Semantic Accent Colors (theme-invariant)

extension Color {
    static let accentGreen  = Color(hex: "#4daa57")
    static let accentRed    = Color(hex: "#e8654a")
    static let accentOrange = Color(hex: "#d9730d")
    static let accentPurple = Color(hex: "#9065b0")
    static let accentPink   = Color(hex: "#c14c8a")
    static let accentCyan   = Color(hex: "#2e9bb0")

    /// Adaptive search-highlight background: warm yellow in light mode, dark amber in dark mode.
    static let searchHighlight = adaptive(
        light: Color(hex: "#fef08a").opacity(0.6),
        dark:  Color(hex: "#854d0e").opacity(0.5)
    )
}

// MARK: - User Accent Colors (customizable)

extension Color {
    enum UserAccent {
        static let black       = Color(hex: "#000000")
        static let blackHover  = Color(hex: "#1a1a1a")
        static let green       = Color(hex: "#10a37f")
        static let greenHover  = Color(hex: "#0d8a6a")
        static let blue        = Color(hex: "#2563eb")
        static let blueHover   = Color(hex: "#1d4ed8")
        static let purple      = Color(hex: "#8b5cf6")
        static let purpleHover = Color(hex: "#7c3aed")
        static let pink        = Color(hex: "#ec4899")
        static let pinkHover   = Color(hex: "#db2777")
        static let orange      = Color(hex: "#f97316")
        static let orangeHover = Color(hex: "#ea580c")
        static let cyan        = Color(hex: "#06b6d4")
        static let cyanHover   = Color(hex: "#0891b2")
        static let red         = Color(hex: "#ef4444")
        static let redHover    = Color(hex: "#dc2626")

        static func color(for name: String) -> Color {
            switch name {
            case "black":  return black
            case "green":  return green
            case "blue":   return blue
            case "purple": return purple
            case "pink":   return pink
            case "orange": return orange
            case "cyan":   return cyan
            case "red":    return red
            default:       return black
            }
        }

        static func hoverColor(for name: String) -> Color {
            switch name {
            case "black":  return blackHover
            case "green":  return greenHover
            case "blue":   return blueHover
            case "purple": return purpleHover
            case "pink":   return pinkHover
            case "orange": return orangeHover
            case "cyan":   return cyanHover
            case "red":    return redHover
            default:       return blackHover
            }
        }

        /// Dark-mode-safe variant per accent. "black" → zinc-500 (#71717a) so it's
        /// visible against the near-black dark background (#09090b). All other accents
        /// are already dark enough to stay legible in both modes.
        static func darkColor(for name: String) -> Color {
            switch name {
            case "black": return Color(hex: "#71717a")   // zinc-500; contrast ~4.6:1 on #09090b
            default:      return color(for: name)
            }
        }

        /// Returns an adaptive Color that uses the light-mode hex in light mode and
        /// `darkColor(for:)` in dark mode, matching the app's UITraitCollection.
        static func adaptiveAccentColor(for name: String) -> Color {
            Color.adaptive(light: color(for: name), dark: darkColor(for: name))
        }
    }

    // Convenience — resolves user accent by id string
    static func accentPreset(_ id: String) -> Color {
        UserAccent.color(for: id)
    }
}

// MARK: - Provider Brand Colors

extension Color {
    static let providerOpenAI = Color(hex: "#10a37f")
    static let providerClaude = Color(hex: "#d97706")
    static let providerGoogle = Color(hex: "#4285f4")
    static let providerXAI    = Color(hex: "#9ca3af")
}

// MARK: - Password Strength Colors

extension Color {
    enum PasswordStrength {
        static let weak     = Color(hex: "#e8654a")
        static let fair     = Color(hex: "#c4890e")
        static let good     = Color(hex: "#2a6496")
        static let strong   = Color(hex: "#3a7a3a")
        static let inactive = Color(hex: "#e9e9e7")
        static let label    = Color(hex: "#9b9a97")
    }
}

// MARK: - Brand & Decorative Colors

extension Color {
    static let logoBg              = Color(hex: "#37352f")
    static let decorativePeach     = Color(hex: "#fdecc8")
    static let decorativeLightBlue = Color(hex: "#d3e5ef")
    static let tooltipBg           = Color(hex: "#1a1a1a")
    static let tooltipText         = Color(hex: "#e0e0e0")
}

// MARK: - Fact Type Colors

extension Color {
    /// Blue — matches `text-link` (adaptive light/dark)
    static let factFact       = adaptive(light: Color(hex: "#2383e2"), dark: Color(hex: "#60a5fa"))
    /// Purple — fixed semantic color
    static let factPreference = Color.accentPurple
    /// Green — fixed semantic color
    static let factGoal       = Color.accentGreen
    /// Orange — fixed semantic color
    static let factExperience = Color.accentOrange

    static func factTypeColor(_ type: FactType) -> Color {
        switch type {
        case .fact:       return .factFact
        case .preference: return .factPreference
        case .goal:       return .factGoal
        case .experience: return .factExperience
        }
    }
}

// MARK: - Plan Colors

extension Color {
    static let planFree    = Color.mcTextSecondary
    static let planPro     = adaptive(light: Color(hex: "#2383e2"), dark: Color(hex: "#60a5fa"))
    static let planPremium = Color.accentPurple

    static func planColor(_ plan: PlanType) -> Color {
        switch plan {
        case .free:    return .planFree
        case .trial:   return .planPro
        case .pro:     return .planPro
        case .premium: return .planPremium
        }
    }
}

// MARK: - Legacy Aliases (backward compatibility with existing views)

extension Color {
    static var appBackground:   Color { .mcBgPrimary }
    static var appSecondaryBg:  Color { .mcBgSecondary }
    static var appTertiaryBg:   Color { .mcBgHover }
    static var appSurface:      Color { .mcBgPrimary }
    static var appSurfaceHover: Color { .mcBgHover }
    static var appBorder:       Color { .mcBorderDefault }
    static var appPrimary:      Color { .mcTextPrimary }
    static var appSecondary:    Color { .mcTextSecondary }
    static var appMuted:        Color { .mcTextTertiary }
    static var appError:        Color { .accentRed }
    static var appSuccess:      Color { .accentGreen }
    static var appWarning:      Color { .accentOrange }
    static var appInfo:         Color { .mcTextLink }
}

// MARK: - Bubble Styles

extension ShapeStyle where Self == Color {
    static var bubbleUser:      Color { Color.accentColor }
    static var bubbleAssistant: Color { Color.mcBgPrimary }
}
