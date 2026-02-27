import SwiftUI

struct ScrollToBottomButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
