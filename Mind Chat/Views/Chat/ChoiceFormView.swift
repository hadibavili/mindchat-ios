import SwiftUI

struct ChoiceFormView: View {

    let choice: ChoiceQuestion
    let messageId: String
    @ObservedObject var vm: ChatViewModel

    @State private var appeared = false
    @State private var wasSubmittedOnAppear = false
    @State private var justSubmitted = false
    @State private var selectedOption: String?

    private var isSubmitted: Bool {
        vm.submittedForms.contains(messageId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Question label
            Text(choice.question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(
                    wasSubmittedOnAppear ? nil : .mcGentle,
                    value: appeared
                )

            // Option chips
            FlowLayout(spacing: 8) {
                ForEach(Array(choice.options.enumerated()), id: \.offset) { index, option in
                    optionChip(option, index: index)
                }
            }

            // Submitted confirmation
            if isSubmitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentGreen)
                    Text("Response shared")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.mcTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .scaleEffect(justSubmitted ? 1 : (wasSubmittedOnAppear ? 1 : 0.85))
                .opacity(justSubmitted ? 1 : (wasSubmittedOnAppear ? 1 : 0))
                .animation(
                    justSubmitted ? .spring(duration: 0.4, bounce: 0.35) : nil,
                    value: isSubmitted
                )
            }
        }
        .padding(14)
        .onAppear {
            wasSubmittedOnAppear = isSubmitted
            appeared = true
        }
    }

    // MARK: - Option Chip

    @ViewBuilder
    private func optionChip(_ option: String, index: Int) -> some View {
        let isSelected = selectedOption == option

        Button {
            guard !isSubmitted && !vm.isStreaming else { return }
            Haptics.medium()
            selectedOption = option
            justSubmitted = true
            Task { await vm.submitChoiceAnswer(messageId: messageId, answer: option) }
        } label: {
            Text(option)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : Color.mcTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? Color.accentColor
                        : (isSubmitted ? Color.mcBgSecondary.opacity(0.5) : Color.mcBgSecondary)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? Color.accentColor : Color.mcBorderDefault,
                            lineWidth: isSelected ? 0 : 1
                        )
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isSubmitted || vm.isStreaming)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .animation(
            wasSubmittedOnAppear ? nil : .mcGentle.delay(Double(index) * 0.05 + 0.06),
            value: appeared
        )
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }

        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
