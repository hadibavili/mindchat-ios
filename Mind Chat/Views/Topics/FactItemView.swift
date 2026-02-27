import SwiftUI

struct FactItemView: View {

    let fact: Fact
    @ObservedObject var vm: TopicDetailViewModel

    @State private var isExpanded    = false
    @State private var isEditing     = false
    @State private var editContent   = ""
    @State private var showCopied    = false
    @State private var deleteTask:   Task<Void, Never>?

    // MARK: - Confidence

    private var confidencePercent: Int? {
        guard let c = fact.confidence else { return nil }
        // Server returns 0–100; guard against 0–1 scale too
        return c > 1 ? Int(c) : Int(c * 100)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if isExpanded && !isEditing {
                actionRow
            }
        }
        .background(Color.mcBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.mcBorderLight, lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { scheduleDeletion() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await vm.togglePin(factId: fact.id) }
            } label: {
                Label(fact.pinned ? "Unpin" : "Pin",
                      systemImage: fact.pinned ? "pin.slash" : "pin")
            }
            .tint(Color.mcTextLink)
        }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(alignment: .top, spacing: 10) {
            // Type dot
            Circle()
                .fill(Color.factTypeColor(fact.type))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            // Content + metadata
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    editModeView
                } else {
                    Text(fact.content)
                        .font(.subheadline)
                        .foregroundStyle(Color.mcTextPrimary)
                }
                metadataRow
            }

            Spacer(minLength: 4)

            // Right-side buttons
            HStack(spacing: 10) {
                // Copy
                Button {
                    UIPasteboard.general.string = fact.content
                    withAnimation(.easeInOut(duration: 0.15)) { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(showCopied ? Color.accentGreen : Color.mcTextTertiary)
                }

                // Expand / collapse
                Button {
                    withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mcTextSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 6) {
            Text(fact.createdAt.relativeDisplay)
                .font(.caption2)
                .foregroundStyle(Color.mcTextTertiary)

            if fact.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextLink)
            }

            if let imp = fact.importance, imp == .high {
                Image(systemName: "arrow.up")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentOrange)
            }

            if let pct = confidencePercent {
                Text("\(pct)%")
                    .font(.caption2)
                    .foregroundStyle(pct >= 85
                        ? Color.accentGreen
                        : (pct < 70 ? Color.accentOrange : Color.mcTextTertiary))
            }
        }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editModeView: some View {
        TextEditor(text: $editContent)
            .frame(minHeight: 60)
            .padding(6)
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        HStack {
            Button("Cancel") { isEditing = false }
                .font(.caption)
                .foregroundStyle(Color.mcTextSecondary)
            Spacer()
            Button("Save") { Task { await save() } }
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Action Row (expanded)

    private var actionRow: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 14)
            HStack(spacing: 0) {
                // View source — only when sourceMessageId available
                if fact.sourceMessageId != nil, let convId = fact.sourceConversationId {
                    actionButton("Source", icon: "arrow.up.right.square") {
                        isExpanded = false
                        EventBus.shared.publish(
                            .navigateToMessage(conversationId: convId,
                                               messageId: fact.sourceMessageId!)
                        )
                    }
                }

                actionButton(fact.pinned ? "Unpin" : "Pin",
                             icon: fact.pinned ? "pin.slash" : "pin") {
                    Task { await vm.togglePin(factId: fact.id) }
                }

                actionButton("Edit", icon: "pencil") {
                    editContent = fact.content
                    isEditing   = true
                }

                actionButton("Delete", icon: "trash", isDestructive: true) {
                    withAnimation(.spring(duration: 0.2)) { isExpanded = false }
                    scheduleDeletion()
                }

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func actionButton(_ label: String, icon: String,
                               isDestructive: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(isDestructive ? Color.accentRed : Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            UIPasteboard.general.string = fact.content
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button {
            Task { await vm.togglePin(factId: fact.id) }
        } label: {
            Label(fact.pinned ? "Unpin" : "Pin",
                  systemImage: fact.pinned ? "pin.slash" : "pin")
        }

        Button {
            editContent = fact.content
            isEditing   = true
            withAnimation(.spring(duration: 0.2)) { isExpanded = true }
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        if fact.sourceMessageId != nil, let convId = fact.sourceConversationId {
            Button {
                EventBus.shared.publish(
                    .navigateToMessage(conversationId: convId,
                                       messageId: fact.sourceMessageId!)
                )
            } label: {
                Label("View Source", systemImage: "arrow.up.right.square")
            }
        }

        Divider()

        Button(role: .destructive) { scheduleDeletion() } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Undo Delete

    private func scheduleDeletion() {
        let factCopy = fact
        vm.removeFactLocally(factId: fact.id)

        let task = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await vm.commitDeleteFact(factId: factCopy.id)
        }
        deleteTask = task

        Haptics.medium()
        ToastManager.shared.info("Fact deleted", action: {
            task.cancel()
            withAnimation(.spring(duration: 0.25)) {
                vm.restoreFactLocally(factCopy)
            }
        }, actionLabel: "Undo", timeout: 5)
    }

    // MARK: - Save Edit

    private func save() async {
        await vm.updateContent(factId: fact.id, content: editContent)
        isEditing = false
    }
}
