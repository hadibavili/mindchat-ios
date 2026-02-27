import SwiftUI

struct ExtractingIndicator: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(Color.accentColor)
            Text("Extracting memories…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mcBgSecondary)
        .clipShape(Capsule())
    }
}
