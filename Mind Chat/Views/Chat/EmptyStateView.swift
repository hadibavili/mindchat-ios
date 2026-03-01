import SwiftUI

struct EmptyStateView: View {

    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var appState: AppState
    @State private var appeared = false
    @State private var greeting: String = ""
    @State private var showPersonaPicker = false

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
        .sheet(isPresented: $showPersonaPicker) {
            PersonaSelectorSheet(vm: vm)
        }
    }

    // MARK: - Default Greeting State

    private var defaultGreetingState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Greeting
            Text(greeting)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.mcGentle, value: appeared)

            // Subtitle
            Text("I remember everything you've shared — just pick up where you left off.")
                .font(.subheadline)
                .foregroundStyle(Color.mcTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.mcGentle.delay(0.05), value: appeared)

            // Chat mode chip
            Button { showPersonaPicker = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: vm.persona.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(vm.persona.color)
                    Text(vm.persona.label)
                        .font(.caption.bold())
                        .foregroundStyle(Color.mcTextPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.mcTextTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.mcBgSecondary)
                .clipShape(Capsule())
            }
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
            .animation(.mcGentle.delay(0.08), value: appeared)

            // Memory mode banner
            MemoryModeBanner(mode: vm.chatMemory)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            Spacer()

            // Upgrade card for free users
            if vm.plan == .free {
                UpgradeBannerCard(onTap: {})
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.mcGentle.delay(0.1), value: appeared)
            }
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
                    .frame(width: 72, height: 72)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.mcTextLink)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.mcGentle, value: appeared)

            Text("Ready to talk about \(focus.name)")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.mcGentle.delay(0.05), value: appeared)

            Text(focus.factCount > 0 ? "\(focus.factCount) memories loaded" : "Ask me anything")
                .font(.subheadline)
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
                .font(.caption)
                .foregroundStyle(Color.mcTextLink)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mcTextLink.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
