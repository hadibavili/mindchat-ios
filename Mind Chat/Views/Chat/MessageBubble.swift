import SwiftUI

struct MessageBubble: View {

    let message: ChatMessage
    var isHighlighted: Bool = false
    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    // Single Identifiable item — eliminates the isPresented/selectedURL race condition.
    @State private var selectedImageItem: SelectedImageItem?
    @State private var showCopied = false
    @State private var showSelectableText = false
    @State private var thumbsUp = false
    @State private var thumbsDown = false

    var isUser: Bool { message.role == .user }

    /// True when this assistant message contains (or is streaming) a structured form.
    private var isQuestionFormMessage: Bool {
        !isUser && (activeQuestionForm != nil || activeChoiceQuestion != nil || isStreamingQuestionJSON)
    }

    /// Parsed multi-field form result (only when JSON is complete).
    private var activeQuestionForm: QuestionFormResult? {
        QuestionForm.parse(from: message.content)
    }

    /// Parsed single choice question (only when JSON is complete).
    private var activeChoiceQuestion: (preamble: String?, choice: ChoiceQuestion)? {
        guard activeQuestionForm == nil else { return nil }
        return ChoiceQuestion.parse(from: message.content)
    }

    /// True while the message is still streaming but the content already looks like
    /// question-form JSON. Used to suppress the raw JSON flash.
    private var isStreamingQuestionJSON: Bool {
        guard message.isStreaming else { return false }
        let t = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.contains("{\"questions\"") || t.contains("{ \"questions\"")
            || t.contains("{\"question\"") || t.contains("{ \"question\"")
    }

    var body: some View {
        Group {
            if isUser {
                userBubble
                    .contextMenu { userContextMenuContent }
            } else if !message.isStreaming && !message.isError && !message.content.isEmpty && !isQuestionFormMessage {
                assistantBubble
                    .contextMenu { assistantContextMenuContent }
            } else {
                assistantBubble
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHighlighted ? themeManager.accentColor.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.4), value: isHighlighted)
        // item: binding is atomic — no race condition between URL and isPresented
        .fullScreenCover(item: $selectedImageItem) { item in
            ImageViewerSheet(item: item)
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    AttachmentGrid(attachments: attachments, onImageTap: { att in
                        selectedImageItem = SelectedImageItem(url: att.url,
                                                             preloadedImage: vm.decodedImages[att.id])
                    }, vm: vm)
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(themeManager.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let attachments = message.attachments, !attachments.isEmpty {
                AttachmentGrid(attachments: attachments, onImageTap: { att in
                    selectedImageItem = SelectedImageItem(url: att.url,
                                                         preloadedImage: vm.decodedImages[att.id])
                }, vm: vm)
            }

            if message.isError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(Color.accentRed)
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(Color.accentRed)
                }
                Button { Task { await vm.retryError(messageId: message.id) } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                        Text("Retry")
                            .font(.footnote)
                    }
                    .foregroundStyle(Color.mcTextTertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else if message.content.isEmpty && message.isStreaming {
                EmptyView()
            } else if let result = activeQuestionForm {
                if let preamble = result.preamble {
                    MarkdownView(text: preamble)
                }
                QuestionFormView(form: result.form, messageId: message.id, vm: vm)
            } else if let (preamble, choice) = activeChoiceQuestion {
                if let preamble {
                    MarkdownView(text: preamble)
                }
                ChoiceFormView(choice: choice, messageId: message.id, vm: vm)
            } else if isStreamingQuestionJSON {
                if let preambleEnd = message.content.range(of: "{\"questions\"") ??
                                     message.content.range(of: "{ \"questions\"") ??
                                     message.content.range(of: "{\"question\"") ??
                                     message.content.range(of: "{ \"question\"") {
                    let preamble = String(message.content[..<preambleEnd.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "```\\w*\\s*$", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !preamble.isEmpty {
                        MarkdownView(text: preamble)
                    }
                }
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.secondary)
                    Text("Preparing questions…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                MarkdownView(text: message.content, onImageTap: { url in
                    selectedImageItem = SelectedImageItem(url: url, preloadedImage: nil)
                })

                if message.isStreaming && !message.content.isEmpty {
                    Text("●")
                        .font(.footnote)
                        .foregroundStyle(Color.mcBorderDefault)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: message.isStreaming)
                }
            }

            if let topics = message.streamingTopics, !topics.isEmpty {
                TopicPillsView(topics: topics)
            }

            if let sources = message.sources, !sources.isEmpty {
                SearchSourcesRow(sources: sources)
            }

            if !message.isStreaming && !message.isError && !message.content.isEmpty,
               QuestionForm.parse(from: message.content) == nil || vm.submittedForms.contains(message.id) {
                assistantActionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showSelectableText) {
            SelectableTextSheet(text: message.content)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Assistant Action Bar

    private var assistantActionBar: some View {
        HStack(spacing: 14) {
            Button {
                thumbsUp.toggle()
                if thumbsUp { thumbsDown = false }
            } label: {
                Image(systemName: thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 14))
                    .foregroundStyle(thumbsUp ? Color.accentGreen : Color.mcTextTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Button {
                thumbsDown.toggle()
                if thumbsDown { thumbsUp = false }
            } label: {
                Image(systemName: thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 14))
                    .foregroundStyle(thumbsDown ? Color.accentRed : Color.mcTextTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.mcBorderDefault)
                .frame(width: 0.5, height: 14)

            Button {
                vm.copyMessage(message)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(showCopied ? Color.accentGreen : Color.mcTextTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Button {
                showSelectableText = true
            } label: {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mcTextTertiary)
            }
            .buttonStyle(.plain)

            if message == vm.messages.last(where: { $0.role == .assistant }) {
                Button { Task { await vm.regenerateLast() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mcTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Context Menus

    @ViewBuilder
    private var userContextMenuContent: some View {
        Button {
            vm.copyMessage(message)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
        } label: {
            Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
        }

        if message == vm.messages.last(where: { $0.role == .user }) {
            Button { vm.editLastUserMessage() } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    @ViewBuilder
    private var assistantContextMenuContent: some View {
        Button {
            showSelectableText = true
        } label: {
            Label("Select Text", systemImage: "character.cursor.ibeam")
        }

        Button {
            vm.copyMessage(message)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if message == vm.messages.last(where: { $0.role == .assistant }) {
            Button { Task { await vm.regenerateLast() } } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }
    }
}

// MARK: - Search Sources Row

struct SearchSourcesRow: View {
    let sources: [SearchSource]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                    Link(destination: URL(string: source.url) ?? URL(string: "https://example.com")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(source.title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.mcBgSecondary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Bubble Image
// Reads from vm.decodedImages cache. For optimistic messages decodes local data
// off the main thread. For history messages, downloads with Bearer auth.

private struct BubbleImage: View {
    let attachment: MessageAttachment
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        Group {
            if let cached = vm.decodedImages[attachment.id] {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else {
                SkeletonView()
            }
        }
        .task(id: attachment.id) {
            guard vm.decodedImages[attachment.id] == nil else { return }
            if let data = attachment.localImageData {
                // Optimistic user-uploaded: decode local JPEG off-main-thread
                let decoded: UIImage? = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(returning: UIImage(data: data))
                    }
                }
                if let decoded {
                    vm.cacheImage(decoded, forId: attachment.id)
                }
            } else if !attachment.url.isEmpty {
                // History messages (user-uploaded or AI-generated): download with auth
                vm.downloadAndCacheImage(url: attachment.url, forId: attachment.id)
            }
        }
    }
}

// MARK: - Attachment Grid

struct AttachmentGrid: View {
    let attachments: [MessageAttachment]
    let onImageTap: (MessageAttachment) -> Void
    @ObservedObject var vm: ChatViewModel

    let imageAttachments: [MessageAttachment]
    let fileAttachments:  [MessageAttachment]

    init(attachments: [MessageAttachment], onImageTap: @escaping (MessageAttachment) -> Void, vm: ChatViewModel) {
        self.attachments      = attachments
        self.onImageTap       = onImageTap
        self.vm               = vm
        self.imageAttachments = attachments.filter { $0.type == .image }
        self.fileAttachments  = attachments.filter { $0.type == .file }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !imageAttachments.isEmpty {
                if imageAttachments.count == 1 {
                    BubbleImage(attachment: imageAttachments[0], vm: vm)
                        .frame(width: 220, height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("chat.message.imageThumbnail")
                        .onTapGesture { onImageTap(imageAttachments[0]) }
                } else {
                    let cellSize: CGFloat = 108
                    let columns = [
                        GridItem(.fixed(cellSize), spacing: 4),
                        GridItem(.fixed(cellSize), spacing: 4)
                    ]
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(imageAttachments) { att in
                            BubbleImage(attachment: att, vm: vm)
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityIdentifier("chat.message.imageThumbnail")
                                .onTapGesture { onImageTap(att) }
                        }
                    }
                    .fixedSize()
                }
            }

            ForEach(fileAttachments) { att in
                HStack(spacing: 8) {
                    FileIconView(mimeType: att.mimeType, name: att.name, size: 26)
                    Text(att.name)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.mcBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

