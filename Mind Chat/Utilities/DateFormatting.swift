import Foundation

// MARK: - Date Formatting Helpers

extension Date {

    // MARK: Relative Time (for conversation list)

    var relativeDisplay: String {
        let now = Date()
        let diff = now.timeIntervalSince(self)

        if diff < 60 {
            return "now"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h"
        } else if diff < 7 * 86400 {
            let days = Int(diff / 86400)
            return "\(days)d"
        } else {
            return shortFormatted
        }
    }

    // MARK: Date Separator (for chat)

    var dateSeparatorLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return longFormatted
        }
    }

    // MARK: Short Format (e.g., "Feb 24")

    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let calendar = Calendar.current
        if calendar.component(.year, from: self) != calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: self)
    }

    // MARK: Long Format (e.g., "February 24, 2026")

    var longFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    // MARK: Time Format

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    // MARK: Full DateTime

    var fullFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    // MARK: Trial Days Remaining

    var daysUntil: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: self)
        return max(0, components.day ?? 0)
    }
}

// MARK: - ISO 8601 Date Decoder

extension JSONDecoder {
    static var mindChat: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }

            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static var mindChat: JSONEncoder {
        let encoder = JSONEncoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso.string(from: date))
        }
        return encoder
    }
}
