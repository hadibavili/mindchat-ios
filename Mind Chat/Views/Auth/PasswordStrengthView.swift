import SwiftUI

struct PasswordStrengthView: View {
    let strength: PasswordStrength?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(level))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                }
            }
            if let strength {
                Text(strength.label)
                    .font(.caption)
                    .foregroundStyle(labelColor)
            }
        }
    }

    private func barColor(_ level: Int) -> Color {
        guard let strength else { return Color.PasswordStrength.inactive }
        if level <= strength.rawValue {
            switch strength {
            case .weak:   return Color.PasswordStrength.weak
            case .fair:   return Color.PasswordStrength.fair
            case .good:   return Color.PasswordStrength.good
            case .strong: return Color.PasswordStrength.strong
            }
        }
        return Color.PasswordStrength.inactive
    }

    private var labelColor: Color {
        switch strength {
        case .weak:   return Color.PasswordStrength.weak
        case .fair:   return Color.PasswordStrength.fair
        case .good:   return Color.PasswordStrength.good
        case .strong: return Color.PasswordStrength.strong
        case nil:     return Color.PasswordStrength.label
        }
    }
}
