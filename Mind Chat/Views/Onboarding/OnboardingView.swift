import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState
    @State private var page = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        (
            "bubble.left.and.bubble.right.fill",
            "Chat naturally",
            "Have conversations as you normally would. MindChat follows along and understands what matters to you."
        ),
        (
            "brain.head.profile",
            "Memories are saved",
            "Key information — preferences, goals, experiences — is automatically saved and organised into topics."
        ),
        (
            "folder.fill.badge.gearshape",
            "Browse your topics",
            "Explore, search, and edit everything MindChat has learned about you in the Topics tab."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { i in
                    VStack(spacing: 24) {
                        Image(systemName: steps[i].icon)
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentColor)
                            .padding(.bottom, 8)

                        Text(steps[i].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text(steps[i].body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 400)

            Spacer()

            // CTA
            VStack(spacing: 16) {
                if page == steps.count - 1 {
                    Button {
                        appState.completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { page += 1 }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Button("Skip") {
                    appState.completeOnboarding()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .animation(.spring(duration: 0.3), value: page)

            Spacer(minLength: 40)
        }
        .interactiveDismissDisabled()
    }
}
