import SwiftUI

struct QuestionFormView: View {

    let form: QuestionForm
    let messageId: String
    @ObservedObject var vm: ChatViewModel

    private var isSubmitted: Bool {
        vm.submittedForms.contains(messageId)
    }

    private var hasAnyAnswer: Bool {
        let answers = vm.formAnswers[messageId] ?? [:]
        return answers.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(form.questions) { question in
                questionField(question)
            }

            if !isSubmitted {
                submitButton
            }
        }
        .padding(16)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.mcBorderDefault, lineWidth: 1)
        )
    }

    // MARK: - Question Field

    @ViewBuilder
    private func questionField(_ question: QuestionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if isSubmitted {
                let answer = vm.formAnswers[messageId]?[question.id] ?? ""
                Text(answer.isEmpty ? "(skipped)" : answer)
                    .font(.body)
                    .foregroundStyle(answer.isEmpty ? Color.mcTextTertiary : Color.mcTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mcBgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                TextField(
                    question.placeholder,
                    text: vm.formAnswerBinding(messageId: messageId, questionId: question.id),
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.mcBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mcBorderDefault, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Haptics.light()
            Task { await vm.submitQuestionForm(messageId: messageId, form: form) }
        } label: {
            Text("Submit")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(hasAnyAnswer ? Color.accentColor : Color.mcBgActive)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!hasAnyAnswer || vm.isStreaming)
        .animation(.mcSnappy, value: hasAnyAnswer)
    }
}
