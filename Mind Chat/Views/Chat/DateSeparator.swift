import SwiftUI

struct DateSeparator: View {

    let date: Date

    var body: some View {
        Text(date.dateSeparatorLabel)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.mcTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}
