import SwiftUI

struct SkeletonView: View {

    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            colors: [
                Color.mcBorderLight,
                Color.mcBorderLight.opacity(0.3),
                Color.mcBorderLight
            ],
            startPoint: UnitPoint(x: phase, y: 0.5),
            endPoint: UnitPoint(x: phase + 1, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
