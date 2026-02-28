import SwiftUI

struct EmptyStateView: View {

    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var appState: AppState
    @State private var appeared = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = appState.currentUser?.name?
            .components(separatedBy: " ").first ?? "there"
        switch hour {
        case 5..<12:  return "Good morning, \(firstName)"
        case 12..<17: return "Good afternoon, \(firstName)"
        case 17..<21: return "Good evening, \(firstName)"
        default:      return "Good night, \(firstName)"
        }
    }

    private let suggestions: [(icon: String, text: String)] = [
        ("lightbulb",                "What's on your mind?"),
        ("brain",                    "What have I learned recently?"),
        ("target",                   "Help me set a goal"),
        ("doc.text.magnifyingglass", "Summarise a topic for me"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Greeting
            Text(greeting)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.mcGentle, value: appeared)

            // Memory mode banner
            MemoryModeBanner(mode: vm.chatMemory)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            Spacer()

            // Suggestion chips
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(Array(suggestions.enumerated()), id: \.element.text) { idx, item in
                    Button { vm.useSuggestion(item.text) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 1)
                            Text(item.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mcBgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(CardPressStyle())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.mcGentle.delay(0.1 + Double(idx) * 0.07), value: appeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Upgrade Banner Card

struct UpgradeBannerCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade your plan")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("More messages, pro models, and memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Memory Mode Banner

struct MemoryModeBanner: View {
    let mode: ChatMemoryMode

    private var icon: String {
        switch mode {
        case .alwaysPersist:   return "memorychip"
        case .persistClearable: return "memorychip"
        case .fresh:           return "arrow.counterclockwise"
        case .extractOnly:     return "brain"
        }
    }

    private var description: String {
        switch mode {
        case .alwaysPersist:    return "Full conversation history is saved"
        case .persistClearable: return "History saved – you can clear it anytime"
        case .fresh:            return "Each session starts fresh – no chat history"
        case .extractOnly:      return "Facts are extracted, but messages aren't saved"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
