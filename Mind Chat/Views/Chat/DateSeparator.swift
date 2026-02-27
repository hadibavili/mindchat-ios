import SwiftUI

struct DateSeparator: View {

    let date: Date

    var body: some View {
        HStack {
            line
            Text(date.dateSeparatorLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            line
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.mcBorderDefault)
            .frame(height: 0.5)
    }
}
