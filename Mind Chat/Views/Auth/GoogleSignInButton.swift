import SwiftUI

struct GoogleSignInButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    Text("G")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#4285F4"))
                }
                Text("Continue with Google")
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mcBorderDefault, lineWidth: 0.5)
            }
        }
    }
}
