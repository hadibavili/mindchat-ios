import SwiftUI

struct TopicAutocompleteOverlay: View {

    let allTopics: [TopicTreeNode]
    let query: String
    let onSelect: (TopicTreeNode) -> Void

    private var filtered: [TopicTreeNode] {
        if query.isEmpty {
            return Array(allTopics.prefix(6))
        }
        let q = query.lowercased()
        return Array(
            allTopics
                .filter { $0.name.lowercased().contains(q) }
                .prefix(6)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                HStack {
                    Text("No topics match")
                        .font(.subheadline)
                        .foregroundStyle(Color.mcTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                ForEach(filtered) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        HStack(spacing: 10) {
                            TopicIconView(iconName: node.icon ?? node.name, size: 24)

                            Text(node.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.mcTextPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(node.totalFactCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.mcTextTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if node.id != filtered.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.mcBorderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
