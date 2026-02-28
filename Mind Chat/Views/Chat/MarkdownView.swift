import SwiftUI

// MARK: - Markdown View
// Block-level markdown renderer for chat messages.
// Supports headings, code blocks, lists, blockquotes, and inline formatting.

struct MarkdownView: View {

    let text: String

    var body: some View {
        let blocks = MarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            inlineText(text)
                .padding(.bottom, 10)

        case .heading(let level, let text):
            headingView(level: level, text: text)
                .padding(.bottom, 8)
                .padding(.top, level == 1 ? 6 : 4)

        case .codeBlock(let language, let code):
            CodeBlockView(code: code, language: language)
                .padding(.bottom, 10)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(Color.mcTextSecondary)
                        inlineText(item)
                    }
                }
            }
            .padding(.leading, 4)
            .padding(.bottom, 10)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.body)
                            .foregroundStyle(Color.mcTextSecondary)
                            .frame(minWidth: 20, alignment: .trailing)
                        inlineText(item)
                    }
                }
            }
            .padding(.leading, 4)
            .padding(.bottom, 10)

        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.mcBorderDefault)
                    .frame(width: 3)
                inlineText(text)
                    .foregroundStyle(Color.mcTextSecondary)
                    .padding(.leading, 12)
            }
            .padding(.bottom, 10)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 8)

        case .empty:
            EmptyView()
        }
    }

    private func headingView(level: Int, text: String) -> some View {
        Group {
            switch level {
            case 1:
                inlineText(text)
                    .font(.title2.bold())
            case 2:
                inlineText(text)
                    .font(.title3.bold())
            default:
                inlineText(text)
                    .font(.headline)
            }
        }
    }

    private func inlineText(_ text: String) -> some View {
        Group {
            if let attributed = parseInline(text) {
                Text(attributed)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func parseInline(_ text: String) -> AttributedString? {
        try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )
    }
}

// MARK: - Markdown Block Types

enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)
    case codeBlock(String?, String)
    case unorderedList([String])
    case orderedList([String])
    case blockquote(String)
    case horizontalRule
    case empty
}

// MARK: - Markdown Parser

enum MarkdownParser {

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Code block (fenced)
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(language.isEmpty ? nil : language, code))
                continue
            }

            // Heading
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let ql = lines[i].trimmingCharacters(in: .whitespaces)
                    if ql.hasPrefix(">") {
                        let content = String(ql.dropFirst()).trimmingCharacters(in: .whitespaces)
                        quoteLines.append(content)
                        i += 1
                    } else if ql.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(quoteLines.joined(separator: " ")))
                continue
            }

            // Unordered list
            if isUnorderedListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let li = lines[i].trimmingCharacters(in: .whitespaces)
                    if isUnorderedListItem(li) {
                        items.append(stripListMarker(li))
                        i += 1
                    } else if li.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.unorderedList(items))
                continue
            }

            // Ordered list
            if isOrderedListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let li = lines[i].trimmingCharacters(in: .whitespaces)
                    if isOrderedListItem(li) {
                        items.append(stripOrderedMarker(li))
                        i += 1
                    } else if li.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.orderedList(items))
                continue
            }

            // Paragraph — collect contiguous non-empty, non-special lines
            var paraLines: [String] = []
            while i < lines.count {
                let pl = lines[i]
                let pt = pl.trimmingCharacters(in: .whitespaces)
                if pt.isEmpty || pt.hasPrefix("```") || pt.hasPrefix("#") ||
                   pt.hasPrefix(">") || isUnorderedListItem(pt) || isOrderedListItem(pt) ||
                   isHorizontalRule(pt) {
                    break
                }
                paraLines.append(pl)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(paraLines.joined(separator: "\n")))
            }
        }

        return blocks
    }

    // MARK: - Helpers

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        if line.hasPrefix("### ") {
            return .heading(3, String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return .heading(2, String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return .heading(1, String(line.dropFirst(2)))
        }
        return nil
    }

    private static func isUnorderedListItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func isOrderedListItem(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let prefix = line[line.startIndex..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }) else { return false }
        let afterDot = line.index(after: dotIndex)
        return afterDot < line.endIndex && line[afterDot] == " "
    }

    private static func stripListMarker(_ line: String) -> String {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2))
        }
        return line
    }

    private static func stripOrderedMarker(_ line: String) -> String {
        guard let dotIndex = line.firstIndex(of: ".") else { return line }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return line }
        return String(line[line.index(after: afterDot)...])
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        return (stripped.allSatisfy({ $0 == "-" }) && stripped.count >= 3) ||
               (stripped.allSatisfy({ $0 == "*" }) && stripped.count >= 3) ||
               (stripped.allSatisfy({ $0 == "_" }) && stripped.count >= 3)
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(language?.lowercased() ?? "code")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    Haptics.light()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(copied ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.mcBgHover)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color.mcBgSecondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.mcBorderDefault, lineWidth: 0.5)
        }
    }
}
