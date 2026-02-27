import SwiftUI

struct ForgotPasswordView: View {

    @StateObject private var vm = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if vm.forgotSent {
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.badge.checkmark")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                        Text("Check your inbox")
                            .font(.title2.bold())
                        Text("If an account exists for \(vm.forgotEmail), you'll receive a password reset link shortly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try a different email") {
                            vm.forgotSent  = false
                            vm.forgotEmail = ""
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.open")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.accentColor)
                        Text("Reset password")
                            .font(.title2.bold())
                        Text("Enter your email and we'll send you a reset link.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        AuthTextField(
                            icon: "envelope",
                            placeholder: "Email",
                            text: $vm.forgotEmail,
                            error: vm.forgotError,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )

                        Button {
                            Task { await vm.sendForgotPassword() }
                        } label: {
                            Group {
                                if vm.forgotLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Send Reset Link").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(vm.forgotLoading)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}
