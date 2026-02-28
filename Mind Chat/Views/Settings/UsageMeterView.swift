import SwiftUI

// MARK: - Arc Ring View

struct ArcRingView: View {
    let fraction: Double
    let lineWidth: CGFloat
    let trackColor: Color
    let fillColors: [Color]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = (min(size.width, size.height) / 2) - lineWidth / 2
            let start: Double = 135
            let sweep: Double = 270

            // Track arc
            var track = Path()
            track.addArc(center: center, radius: radius,
                         startAngle: .degrees(start),
                         endAngle: .degrees(start + sweep),
                         clockwise: false)
            ctx.stroke(track, with: .color(trackColor),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Fill arc
            guard fraction > 0 else { return }
            var fill = Path()
            fill.addArc(center: center, radius: radius,
                        startAngle: .degrees(start),
                        endAngle: .degrees(start + sweep * fraction),
                        clockwise: false)
            ctx.stroke(fill, with: .linearGradient(
                Gradient(colors: fillColors),
                startPoint: CGPoint(x: 0, y: size.height),
                endPoint: CGPoint(x: size.width, y: 0)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// MARK: - Usage Meter View

struct UsageMeterView: View {

    let label: String
    let icon: String
    let used: Int
    let limit: Int

    @State private var animatedFraction = 0.0

    var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }

    var isUnlimited: Bool { limit == -1 }
    var isHigh: Bool { fraction >= 0.8 }

    private var fillColors: [Color] {
        if isUnlimited {
            return [Color.accentGreen, Color.accentGreen.opacity(0.6)]
        } else if isHigh {
            return [Color.accentOrange, Color.accentRed]
        } else {
            return [Color.planPro, Color.mcTextLink]
        }
    }

    private var centerText: String { isUnlimited ? "∞" : "\(used)" }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ArcRingView(
                    fraction: isUnlimited ? 1.0 : animatedFraction,
                    lineWidth: 6,
                    trackColor: Color.secondary.opacity(0.15),
                    fillColors: fillColors
                )
                .frame(width: 56, height: 56)

                Text(centerText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(fillColors.first ?? .primary)

            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2.bold())
                    .multilineTextAlignment(.center)
                if isUnlimited {
                    Text("Unlimited")
                        .font(.caption2)
                        .foregroundStyle(Color.accentGreen)
                } else {
                    Text("\(used) of \(limit)")
                        .font(.caption2)
                        .foregroundStyle(isHigh ? Color.accentOrange : .secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            withAnimation(Animation.mcSmooth.delay(0.25)) {
                animatedFraction = fraction
            }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(.mcSmooth) { animatedFraction = newValue }
        }
    }
}
