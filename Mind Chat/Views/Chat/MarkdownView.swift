import SwiftUI

// MARK: - Markdown View
// Lightweight SwiftUI markdown renderer using AttributedString.
// For full GFM support, add the MarkdownUI SPM package and replace this implementation.

struct MarkdownView: View {

    let text: String

    var body: some View {
        // Render as text with basic formatting
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language {
                HStack {
                    Text(lang.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        Haptics.light()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mcBgHover)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.mcBgPrimary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mcBorderDefault, lineWidth: 0.5)
        }
    }
}
