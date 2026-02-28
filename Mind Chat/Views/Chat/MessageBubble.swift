import SwiftUI

struct MessageBubble: View {

    let message: ChatMessage
    var isHighlighted: Bool = false
    @ObservedObject var vm: ChatViewModel
    @State private var showImageViewer = false
    @State private var selectedImageURL: String?
    @State private var showCopied = false

    var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHighlighted ? Color.accentColor.opacity(0.07) : Color.clear)
        .animation(.easeInOut(duration: 0.4), value: isHighlighted)
        .contextMenu { contextMenuContent }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let url = selectedImageURL {
                ImageViewerSheet(imageURL: url)
            }
        }
    }

    // MARK: - User Bubble (subtle gray background, right-aligned)

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    AttachmentGrid(attachments: attachments) { url in
                        selectedImageURL = url
                        showImageViewer = true
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    // MARK: - Assistant Bubble (clean full-width text, left-aligned, no avatar)

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let attachments = message.attachments, !attachments.isEmpty {
                AttachmentGrid(attachments: attachments) { url in
                    selectedImageURL = url
                    showImageViewer = true
                }
            }

            if message.isError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(Color.accentRed)
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(Color.accentRed)
                }
            } else if message.content.isEmpty && message.isStreaming {
                EmptyView()
            } else {
                MarkdownView(text: message.content)

                if message.isStreaming && !message.content.isEmpty {
                    Text("●")
                        .font(.caption)
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

            // Action bar (copy/regenerate) for completed assistant messages
            if !message.isStreaming && !message.isError && !message.content.isEmpty {
                assistantActionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Assistant Action Bar

    private var assistantActionBar: some View {
        HStack(spacing: 16) {
            Button {
                vm.copyMessage(message)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mcTextTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if message == vm.messages.last(where: { $0.role == .assistant }) {
                Button { Task { await vm.regenerateLast() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mcTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            vm.copyMessage(message)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
        } label: {
            Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
        }

        if message.role == .user && message == vm.messages.last(where: { $0.role == .user }) {
            Button { vm.editLastUserMessage() } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        if message.role == .assistant && message == vm.messages.last(where: { $0.role == .assistant }) {
            Button { Task { await vm.regenerateLast() } } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }

        if message.isError {
            Button { Task { await vm.retryError(messageId: message.id) } } label: {
                Label("Retry", systemImage: "arrow.counterclockwise")
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
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(source.title)
                                .font(.caption)
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

// MARK: - Attachment Grid

struct AttachmentGrid: View {
    let attachments: [MessageAttachment]
    let onImageTap: (String) -> Void

    let imageAttachments: [MessageAttachment]
    let fileAttachments:  [MessageAttachment]

    init(attachments: [MessageAttachment], onImageTap: @escaping (String) -> Void) {
        self.attachments      = attachments
        self.onImageTap       = onImageTap
        self.imageAttachments = attachments.filter { $0.type == .image }
        self.fileAttachments  = attachments.filter { $0.type == .file }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !imageAttachments.isEmpty {
                if imageAttachments.count == 1 {
                    AsyncImage(url: URL(string: imageAttachments[0].url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        SkeletonView()
                    }
                    .frame(maxWidth: 220, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture { onImageTap(imageAttachments[0].url) }
                } else {
                    let cols = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: cols, spacing: 4) {
                        ForEach(imageAttachments) { att in
                            AsyncImage(url: URL(string: att.url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                SkeletonView()
                            }
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { onImageTap(att.url) }
                        }
                    }
                    .frame(maxWidth: 220)
                }
            }

            ForEach(fileAttachments) { att in
                HStack(spacing: 8) {
                    FileIconView(mimeType: att.mimeType, name: att.name, size: 26)
                    Text(att.name)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.mcBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
