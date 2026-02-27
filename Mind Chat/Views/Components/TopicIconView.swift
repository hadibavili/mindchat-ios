import SwiftUI

struct TopicIconView: View {

    let iconName: String
    var size: CGFloat = 32

    private var sfSymbol: String {
        let map: [String: String] = [
            "health":       "heart.fill",
            "fitness":      "figure.run",
            "work":         "briefcase.fill",
            "career":       "chart.line.uptrend.xyaxis",
            "food":         "fork.knife",
            "cooking":      "frying.pan.fill",
            "travel":       "airplane",
            "music":        "music.note",
            "books":        "book.fill",
            "reading":      "books.vertical.fill",
            "finance":      "dollarsign.circle.fill",
            "money":        "banknote.fill",
            "family":       "figure.2.and.child.holdinghands",
            "friends":      "person.2.fill",
            "technology":   "laptopcomputer",
            "programming":  "chevron.left.forwardslash.chevron.right",
            "code":         "chevron.left.forwardslash.chevron.right",
            "science":      "flask.fill",
            "art":          "paintbrush.fill",
            "design":       "paintpalette.fill",
            "nature":       "leaf.fill",
            "pets":         "pawprint.fill",
            "sports":       "sportscourt.fill",
            "movies":       "film.fill",
            "tv":           "tv.fill",
            "gaming":       "gamecontroller.fill",
            "home":         "house.fill",
            "education":    "graduationcap.fill",
            "learning":     "graduationcap.fill",
            "philosophy":   "lightbulb.fill",
            "psychology":   "brain",
            "language":     "globe",
            "meditation":   "wind",
            "sleep":        "moon.fill",
            "goals":        "target",
            "habits":       "repeat",
            "projects":     "folder.fill",
            "ideas":        "sparkles",
            "notes":        "note.text",
            "journal":      "book.closed.fill",
            "hobbies":      "star.fill",
            "politics":     "building.columns.fill",
            "religion":     "sparkles",
            "relationships":"heart.fill",
            "personal":     "person.fill",
            "business":     "chart.bar.fill",
            "shopping":     "bag.fill",
            "style":        "tshirt.fill",
        ]
        let lower = iconName.lowercased()
        for (key, symbol) in map where lower.contains(key) {
            return symbol
        }
        return "folder.fill"
    }

    private var isEmoji: Bool {
        guard iconName.count == 1 else { return false }
        return iconName.unicodeScalars.first.map { $0.value > 127 } ?? false
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: size, height: size)

            if isEmoji {
                Text(iconName)
                    .font(.system(size: size * 0.6))
            } else {
                Image(systemName: sfSymbol)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
