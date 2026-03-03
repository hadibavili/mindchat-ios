import SwiftUI

struct EmptyStateView: View {

    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var appState: AppState
    @State private var appeared = false
    @State private var greeting: String = ""

    private var suggestions: [String] {
        switch vm.chatMemory {
        case .alwaysPersist, .persistClearable:
            return [
                "What do you remember?",
                "Summarize my topics",
                "Help me reflect",
                "What are my goals?"
            ]
        case .fresh, .extractOnly:
            return [
                "Think through a problem",
                "Explain something simply",
                "Give me creative ideas",
                "What should I know?"
            ]
        }
    }

    private func pickGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = appState.currentUser?.name?
            .components(separatedBy: " ").first ?? "there"
        let pool: [String]
        switch hour {
        case 5..<12:
            pool = [
                "Good morning, \(firstName)",
                "Rise and shine, \(firstName)",
                "Morning, \(firstName). What's on your mind?"
            ]
        case 12..<17:
            pool = [
                "Good afternoon, \(firstName)",
                "Hey \(firstName), how's your day going?",
                "What's up, \(firstName)?"
            ]
        case 17..<22:
            pool = [
                "Good evening, \(firstName)",
                "Hey \(firstName), winding down?",
                "Evening, \(firstName). What's on your mind?"
            ]
        default:
            pool = [
                "Still up, \(firstName)?",
                "Late night, \(firstName)?",
                "Hey \(firstName), can't sleep?"
            ]
        }
        return pool.randomElement() ?? pool[0]
    }

    var body: some View {
        Group {
            if let focus = vm.topicFocus {
                topicFocusState(focus: focus)
            } else {
                defaultGreetingState
            }
        }
    }

    // MARK: - Default Greeting State

    private var defaultGreetingState: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(Color.mcTextPrimary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.mcTextPrimary)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.mcGentle, value: appeared)
            .padding(.bottom, 16)

            // Greeting
            Text(greeting)
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.mcGentle.delay(0.05), value: appeared)

            Spacer()

            // Horizontal suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button { vm.inputText = suggestion } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(Color.mcTextSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.mcBgSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.mcGentle.delay(0.1), value: appeared)
            .padding(.bottom, 16)
        }
        .onAppear {
            greeting = pickGreeting()
            appeared = true
        }
    }

    // MARK: - Topic Focus State

    private func topicFocusState(focus: TopicFocus) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.mcTextLink.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.mcTextLink)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.mcGentle, value: appeared)

            Text("Ready to talk about \(focus.name)")
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.mcGentle.delay(0.05), value: appeared)

            Text(focus.factCount > 0 ? "\(focus.factCount) memories loaded" : "Ask me anything")
                .font(.footnote)
                .foregroundStyle(Color.mcTextTertiary)
                .opacity(appeared ? 1 : 0)
                .animation(.mcGentle.delay(0.1), value: appeared)

            Spacer()
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
                    .background(Color.mcTextPrimary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade your plan")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("More messages, pro models, and memory")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.medium))
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
        case .alwaysPersist:    return "memorychip"
        case .persistClearable: return "memorychip"
        case .fresh:            return "arrow.counterclockwise"
        case .extractOnly:      return "brain"
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
                .font(.footnote)
                .foregroundStyle(Color.mcTextLink)
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mcTextLink.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
