import SwiftUI

struct ThinkingIndicator: View {

    let startTime: Date
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var dotPhase = 0

    var body: some View {
        HStack(spacing: 8) {
            // Animated dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotPhase == i ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: dotPhase)
                }
            }

            Text(String(format: "%.1fs", elapsed))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        elapsed = Date().timeIntervalSince(startTime)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed = Date().timeIntervalSince(startTime)
            dotPhase = (dotPhase + 1) % 3
        }
    }
}
