import SwiftUI
import UniformTypeIdentifiers

struct FileIconView: View {

    let mimeType: String?
    let name: String
    var size: CGFloat = 32

    private var sfSymbol: String {
        guard let mime = mimeType else { return "doc.fill" }
        if mime.contains("pdf")             { return "doc.richtext.fill" }
        if mime.contains("word") || mime.contains("msword") { return "doc.text.fill" }
        if mime.contains("image")           { return "photo.fill" }
        if mime.contains("audio")           { return "waveform" }
        if mime.contains("video")           { return "play.rectangle.fill" }
        if mime.contains("spreadsheet") || mime.contains("excel") { return "tablecells.fill" }
        if mime.contains("csv")             { return "chart.bar.doc.horizontal.fill" }
        if mime.contains("text")            { return "doc.plaintext.fill" }
        if mime.contains("zip") || mime.contains("archive") { return "archivebox.fill" }
        return "doc.fill"
    }

    private var accentColor: Color {
        guard let mime = mimeType else { return .gray }
        if mime.contains("pdf")   { return .red }
        if mime.contains("word")  { return .blue }
        if mime.contains("image") { return .purple }
        if mime.contains("audio") { return .orange }
        if mime.contains("video") { return .pink }
        return .gray
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(accentColor.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: sfSymbol)
                .font(.system(size: size * 0.5))
                .foregroundStyle(accentColor)
        }
    }
}
