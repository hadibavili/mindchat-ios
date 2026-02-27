import SwiftUI

struct UsageMeterView: View {

    let label: String
    let used:  Int
    let limit: Int

    var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }

    var isUnlimited: Bool { limit == -1 }
    var isHigh: Bool      { fraction >= 0.8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                if isUnlimited {
                    Text("Unlimited")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentGreen)
                } else {
                    Text("\(used) / \(limit)")
                        .font(.caption.bold())
                        .foregroundStyle(isHigh ? .orange : .secondary)
                }
            }
            if !isUnlimited {
                ProgressView(value: fraction)
                    .tint(isHigh ? .orange : Color.accentColor)
            }
        }
    }
}
