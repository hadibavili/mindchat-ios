import SwiftUI

struct ImportMemoryView: View {

    @StateObject private var vm = ImportMemoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                contentSection
            }
            .padding()
            .animation(.mcSmooth, value: vm.isImporting)
            .animation(.mcSmooth, value: vm.isSuccess)
        }
        .navigationTitle("Import Memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if vm.isSuccess, let response = vm.importResult {
            successCard(response)
        } else if vm.errorMessage != nil, !vm.isImporting {
            errorCard(vm.errorMessage ?? "Something went wrong.")
        } else if vm.isImporting {
            stepOneCard
            disabledTextArea
            importingIndicator
        } else {
            stepOneCard
            stepTwoCard
            importButton
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
            Text("Import from other AI assistants")
                .font(.headline)
            Text("Copy the prompt below, paste it into ChatGPT, Gemini, or Claude, then paste their response here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Step 1: Copy Prompt

    private var stepOneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Step 1: Copy this prompt", systemImage: "1.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.mcTextPrimary)

            Text(vm.promptPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            copyButton
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var copyButton: some View {
        Button {
            vm.copyPrompt()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: vm.showCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                Text(vm.showCopied ? "Copied!" : "Copy Prompt")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(vm.showCopied ? Color.accentGreen.opacity(0.15) : Color.mcBgHover)
            .foregroundStyle(vm.showCopied ? Color.accentGreen : Color.mcTextPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Paste Response

    private var stepTwoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Step 2: Paste the AI's response", systemImage: "2.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.mcTextPrimary)

            TextEditor(text: $vm.pastedText)
                .frame(minHeight: 150, maxHeight: 300)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.mcBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mcBorderDefault, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if vm.pastedText.isEmpty {
                        Text("Paste the response here...")
                            .foregroundStyle(Color.mcTextTertiary)
                            .padding(.leading, 12)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var disabledTextArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Step 2: Paste the AI's response", systemImage: "2.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.mcTextTertiary)

            Text(String(vm.pastedText.prefix(500)) + (vm.pastedText.count > 500 ? "..." : ""))
                .font(.body)
                .foregroundStyle(Color.mcTextTertiary)
                .frame(minHeight: 60, maxHeight: 120, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.mcBgPrimary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button {
            Task { await vm.performImport() }
        } label: {
            importButtonLabel
        }
        .buttonStyle(.plain)
        .disabled(!vm.canImport)
    }

    private var importButtonLabel: some View {
        Text("Import Memories")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.canImport ? Color.mcTextPrimary : Color(.systemFill))
            .foregroundStyle(vm.canImport ? Color.white : Color(.tertiaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Importing Indicator

    private var importingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Getting to know you...")
                .font(.headline)
            Text("Processing your memories. This may take a moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Success Card

    private func successCard(_ response: ImportMemoryResponse) -> some View {
        let total = response.factsAdded + response.factsUpdated
        let topicCount = response.topicsCreated + response.topicsUpdated
        return VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentGreen)

            Text("Import complete!")
                .font(.title3.bold())

            Text("Added \(total) memories across \(topicCount) topics (\(response.topicsCreated) new).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            statsSection(response)

            Button("Import more") {
                vm.reset()
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statsSection(_ response: ImportMemoryResponse) -> some View {
        VStack(spacing: 8) {
            statsRow("Topics created", value: response.topicsCreated)
            statsRow("Topics updated", value: response.topicsUpdated)
            statsRow("Facts added", value: response.factsAdded)
            statsRow("Facts updated", value: response.factsUpdated)
        }
        .padding()
        .background(Color.accentGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statsRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundStyle(Color.mcTextPrimary)
        }
    }

    // MARK: - Error Card

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentRed)

            Text("Import failed")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                vm.tryAgain()
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
