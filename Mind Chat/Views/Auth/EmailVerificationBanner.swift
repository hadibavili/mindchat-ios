import SwiftUI

struct EmailVerificationBanner: View {

    @State private var cooldown   = 0
    @State private var isSending  = false
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .foregroundStyle(Color.accentOrange)
            Text("Please verify your email address.")
                .font(.subheadline)
            Spacer()
            Button {
                Task { await resend() }
            } label: {
                if isSending {
                    ProgressView().scaleEffect(0.7)
                } else if cooldown > 0 {
                    Text("\(cooldown)s")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Resend")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
            .disabled(cooldown > 0 || isSending)
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onDisappear { timer?.invalidate() }
    }

    private func resend() async {
        isSending = true
        defer { isSending = false }
        do {
            try await AuthService.shared.resendVerification()
            startCooldown()
        } catch {}
    }

    private func startCooldown() {
        cooldown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if cooldown > 0 { cooldown -= 1 } else { timer?.invalidate() }
        }
    }
}
