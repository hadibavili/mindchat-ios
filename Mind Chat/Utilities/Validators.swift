import Foundation

// MARK: - Validators

enum Validators {

    // MARK: Email

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: Password

    static func passwordStrength(_ password: String) -> PasswordStrength {
        guard password.count >= 8 else { return .weak }
        var score = 0
        if password.count >= 12 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...1: return .fair
        case 2:     return .good
        default:    return .strong
        }
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    // MARK: Name

    static func isValidName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2
    }
}

// MARK: - Password Strength

enum PasswordStrength: Int, Sendable {
    case weak  = 1
    case fair  = 2
    case good  = 3
    case strong = 4

    var label: String {
        switch self {
        case .weak:   return "Weak"
        case .fair:   return "Fair"
        case .good:   return "Good"
        case .strong: return "Strong"
        }
    }

    var color: String {
        switch self {
        case .weak:   return "red"
        case .fair:   return "orange"
        case .good:   return "yellow"
        case .strong: return "green"
        }
    }
}
