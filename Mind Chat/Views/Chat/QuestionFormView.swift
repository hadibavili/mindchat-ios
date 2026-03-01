import SwiftUI

struct QuestionFormView: View {

    let form: QuestionForm
    let messageId: String
    @ObservedObject var vm: ChatViewModel

    @FocusState private var focusedField: String?
    @State private var appeared = false
    @State private var wasSubmittedOnAppear = false
    @State private var justSubmitted = false

    private var isSubmitted: Bool {
        vm.submittedForms.contains(messageId)
    }

    private var hasAnyAnswer: Bool {
        let answers = vm.formAnswers[messageId] ?? [:]
        return answers.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(form.questions.enumerated()), id: \.element.id) { index, question in
                questionCard(question, index: index)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        wasSubmittedOnAppear ? nil : .mcGentle.delay(Double(index) * 0.06),
                        value: appeared
                    )
            }

            if isSubmitted {
                confirmationRow
            } else {
                submitButton
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        wasSubmittedOnAppear ? nil : .mcGentle.delay(Double(form.questions.count) * 0.06),
                        value: appeared
                    )
            }
        }
        .padding(14)
        .onAppear {
            wasSubmittedOnAppear = isSubmitted
            appeared = true
        }
    }

    // MARK: - Question Card

    @ViewBuilder
    private func questionCard(_ question: QuestionItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                numberBadge(index + 1, questionId: question.id)
                Text(question.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mcTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isSubmitted {
                submittedAnswer(for: question)
            } else {
                inputField(for: question)
            }
        }
        .padding(12)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Number Badge

    private func numberBadge(_ number: Int, questionId: String) -> some View {
        let color: Color = isSubmitted
            ? .accentGreen
            : (focusedField == questionId ? .accentColor : .mcTextTertiary)

        return Text("\(number)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color)
            .clipShape(Circle())
            .animation(.mcSnappy, value: focusedField)
    }

    // MARK: - Input Field

    @ViewBuilder
    private func inputField(for question: QuestionItem) -> some View {
        let isFocused = focusedField == question.id

        TextField(
            question.placeholder,
            text: vm.formAnswerBinding(messageId: messageId, questionId: question.id),
            axis: .vertical
        )
        .font(.body)
        .lineLimit(1...5)
        .focused($focusedField, equals: question.id)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.mcBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isFocused ? Color.accentColor : Color.mcBorderDefault,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.mcSnappy, value: isFocused)
    }

    // MARK: - Submitted Answer

    @ViewBuilder
    private func submittedAnswer(for question: QuestionItem) -> some View {
        let answer = vm.formAnswers[messageId]?[question.id] ?? ""

        HStack(alignment: .top, spacing: 6) {
            if answer.isEmpty {
                Text("Skipped")
                    .font(.body.italic())
                    .foregroundStyle(Color.mcTextTertiary)
            } else {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextTertiary)
                    .padding(.top, 4)
                Text(answer)
                    .font(.body)
                    .foregroundStyle(Color.mcTextSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mcBgHover.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Haptics.medium()
            justSubmitted = true
            Task { await vm.submitQuestionForm(messageId: messageId, form: form) }
        } label: {
            HStack(spacing: 6) {
                Text("Share Responses")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.up.circle.fill")
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(hasAnyAnswer ? Color.accentColor : Color.mcBgActive)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: hasAnyAnswer ? Color.accentColor.opacity(0.25) : .clear,
                radius: 8, y: 4
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!hasAnyAnswer || vm.isStreaming)
        .animation(.mcSnappy, value: hasAnyAnswer)
    }

    // MARK: - Confirmation Row

    private var confirmationRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentGreen)
            Text("Responses shared")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mcTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .scaleEffect(justSubmitted ? 1 : (wasSubmittedOnAppear ? 1 : 0.5))
        .opacity(justSubmitted ? 1 : (wasSubmittedOnAppear ? 1 : 0))
        .animation(
            justSubmitted ? .spring(duration: 0.4, bounce: 0.35) : nil,
            value: isSubmitted
        )
        .onAppear {
            if justSubmitted {
                // already animated via the justSubmitted flag
            }
        }
    }
}
