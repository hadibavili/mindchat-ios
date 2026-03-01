import SwiftUI

struct LoginView: View {

    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.12), Color.mcBgPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.accentColor)
                            Text("MindChat")
                                .font(.largeTitle.bold())
                            Text(vm.mode == .signIn ? "Welcome back" : "Create your account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 48)

                        // Mode toggle
                        Picker("Mode", selection: $vm.mode) {
                            Text("Sign In").tag(AuthViewModel.Mode.signIn)
                            Text("Sign Up").tag(AuthViewModel.Mode.signUp)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Fields
                        VStack(spacing: 14) {
                            if vm.mode == .signUp {
                                AuthTextField(
                                    icon: "person",
                                    placeholder: "Full Name",
                                    text: $vm.name,
                                    error: vm.fieldErrors["name"]
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            AuthTextField(
                                icon: "envelope",
                                placeholder: "Email",
                                text: $vm.email,
                                error: vm.fieldErrors["email"],
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )

                            AuthSecureField(
                                icon: "lock",
                                placeholder: "Password",
                                text: $vm.password,
                                show: $showPassword,
                                error: vm.fieldErrors["password"]
                            )

                            if vm.mode == .signUp {
                                PasswordStrengthView(strength: vm.passwordStrength)
                                    .transition(.opacity)

                                // Terms
                                HStack(alignment: .top, spacing: 10) {
                                    Button {
                                        vm.acceptedTerms.toggle()
                                        Haptics.selection()
                                    } label: {
                                        Image(systemName: vm.acceptedTerms ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(vm.acceptedTerms ? Color.accentColor : .secondary)
                                    }
                                    Text("I agree to the Terms of Service and Privacy Policy")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }

                                if let termsError = vm.fieldErrors["terms"] {
                                    Text(termsError).font(.caption).foregroundStyle(Color.accentRed)
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    NavigationLink("Forgot password?") {
                                        ForgotPasswordView()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .animation(.spring(duration: 0.3), value: vm.mode)

                        // Error
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.accentRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Submit
                        Button {
                            Task {
                                await vm.submit()
                                if AuthService.shared.isAuthenticated {
                                    // AppState will pick up the keychain change on next check
                                    appState.isAuthenticated = true
                                }
                            }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(vm.mode == .signIn ? "Sign In" : "Create Account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(vm.isLoading)
                        .padding(.horizontal)

                        // Divider
                        HStack {
                            Divider()
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Divider()
                        }
                        .padding(.horizontal)

                        // Google Sign-In
                        GoogleSignInButton {
                            // Wire up GoogleSignIn SDK here:
                            // GIDSignIn.sharedInstance.signIn(withPresenting:) { result, error in ... }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var error: String?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error != nil ? Color.accentRed : Color.clear, lineWidth: 1)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Color.accentRed)
            }
        }
    }
}

// MARK: - Auth Secure Field

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var show: Bool
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
                Group {
                    if show {
                        TextField(placeholder, text: $text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.none)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                Button { show.toggle() } label: {
                    Image(systemName: show ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error != nil ? Color.accentRed : Color.clear, lineWidth: 1)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Color.accentRed)
            }
        }
    }
}
