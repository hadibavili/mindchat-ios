import SwiftUI

struct ResetPasswordView: View {

    let token: String
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showPass    = false
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Image(systemName: vm.resetSuccess ? "checkmark.circle.fill" : "lock.rotation")
                            .font(.system(size: 64))
                            .foregroundStyle(vm.resetSuccess ? .green : Color.accentColor)
                        Text(vm.resetSuccess ? "Password updated!" : "New password")
                            .font(.title2.bold())
                        if vm.resetSuccess {
                            Text("Redirecting to sign in…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 50)
                    .animation(.spring(), value: vm.resetSuccess)

                    if !vm.resetSuccess {
                        VStack(spacing: 16) {
                            AuthSecureField(
                                icon: "lock",
                                placeholder: "New password",
                                text: $vm.resetPassword,
                                show: $showPass
                            )
                            PasswordStrengthView(
                                strength: vm.resetPassword.isEmpty ? nil : Validators.passwordStrength(vm.resetPassword)
                            )
                            AuthSecureField(
                                icon: "lock.fill",
                                placeholder: "Confirm password",
                                text: $vm.resetConfirm,
                                show: $showConfirm,
                                error: vm.resetError
                            )

                            Button {
                                Task { await vm.submitReset() }
                            } label: {
                                Group {
                                    if vm.resetLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Update Password").fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(vm.resetLoading)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear { vm.resetToken = token }
            .onChange(of: vm.resetSuccess) { _, success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        appState.pendingDeepLink = nil
                    }
                }
            }
        }
    }
}
