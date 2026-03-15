import SwiftUI
import UIKit

struct SelectableTextSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SelectableTextRepresentable(text: text)
                .background(Color.mcBgPrimary)
                .navigationTitle("Select Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - UITextView wrapper for native text selection

private struct SelectableTextRepresentable: UIViewRepresentable {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.dataDetectorTypes = [.link]
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let textColor: UIColor = colorScheme == .dark ? .white : .black
        let blocks = MarkdownParser.parse(text)
        let result = NSMutableAttributedString()

        for block in blocks {
            switch block {
            case .heading(let level, let headingText):
                let style: UIFont.TextStyle = switch level {
                case 1: .title2
                case 2: .title3
                default: .headline
                }
                let font = UIFont.preferredFont(forTextStyle: style)
                let bold = UIFont.boldSystemFont(ofSize: font.pointSize)
                result.append(inlineAttributed(headingText, baseFont: bold, color: textColor))
                result.append(newline())

            case .paragraph(let paraText):
                result.append(inlineAttributed(paraText, baseFont: .preferredFont(forTextStyle: .body), color: textColor))
                result.append(newline())

            case .codeBlock(_, let code):
                let monoFont = UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize - 1,
                    weight: .regular
                )
                result.append(NSAttributedString(string: code, attributes: [
                    .font: monoFont,
                    .foregroundColor: textColor,
                    .backgroundColor: UIColor.secondarySystemBackground
                ]))
                result.append(newline())

            case .unorderedList(let items):
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                for item in items {
                    result.append(NSAttributedString(string: "  \u{2022}  ", attributes: [
                        .font: bodyFont, .foregroundColor: UIColor.secondaryLabel
                    ]))
                    result.append(inlineAttributed(item, baseFont: bodyFont, color: textColor))
                    result.append(NSAttributedString(string: "\n"))
                }
                result.append(NSAttributedString(string: "\n"))

            case .orderedList(let items):
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                for (idx, item) in items.enumerated() {
                    result.append(NSAttributedString(string: "  \(idx + 1).  ", attributes: [
                        .font: bodyFont, .foregroundColor: UIColor.secondaryLabel
                    ]))
                    result.append(inlineAttributed(item, baseFont: bodyFont, color: textColor))
                    result.append(NSAttributedString(string: "\n"))
                }
                result.append(NSAttributedString(string: "\n"))

            case .blockquote(let quoteText):
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                let style = NSMutableParagraphStyle()
                style.firstLineHeadIndent = 16
                style.headIndent = 16
                let attr = inlineAttributed(quoteText, baseFont: bodyFont, color: textColor)
                let mutable = NSMutableAttributedString(attributedString: attr)
                mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: mutable.length))
                result.append(mutable)
                result.append(newline())

            case .image(let alt, _):
                if !alt.isEmpty {
                    result.append(NSAttributedString(string: "[\(alt)]\n\n", attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .body),
                        .foregroundColor: UIColor.secondaryLabel
                    ]))
                }

            case .horizontalRule:
                result.append(NSAttributedString(string: "\n---\n\n", attributes: [
                    .foregroundColor: UIColor.separator
                ]))

            case .empty:
                break
            }
        }

        // Trim trailing newlines
        while result.length > 0 && result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }

        tv.attributedText = result
    }

    // MARK: - Helpers

    private func newline() -> NSAttributedString {
        NSAttributedString(string: "\n\n")
    }

    private func inlineAttributed(_ text: String, baseFont: UIFont, color: UIColor) -> NSAttributedString {
        if let attrStr = try? NSAttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let mutable = NSMutableAttributedString(attributedString: attrStr)
            let range = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.font, value: baseFont, range: range)
            mutable.addAttribute(.foregroundColor, value: color, range: range)
            return mutable
        }
        return NSAttributedString(string: text, attributes: [
            .font: baseFont, .foregroundColor: color
        ])
    }
}
