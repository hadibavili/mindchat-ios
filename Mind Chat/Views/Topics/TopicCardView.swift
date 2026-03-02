import SwiftUI

struct TopicCardView: View {

    let topic: TopicTreeNode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TopicIconView(iconName: topic.icon ?? topic.name, size: 36)
                Spacer()
                if topic.totalFactCount > 0 {
                    Text("\(topic.totalFactCount)")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentGreen.opacity(0.1))
                        .foregroundStyle(Color.accentGreen)
                        .clipShape(Capsule())
                }
            }

            Text(topic.name)
                .font(.subheadline.bold())
                .foregroundStyle(Color.mcTextPrimary)
                .lineLimit(1)

            if let summary = topic.summary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Color.mcTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                Text(topic.updatedAt?.relativeDisplay ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.mcTextTertiary)
                if !topic.children.isEmpty {
                    Spacer()
                    Text("\(topic.children.count) subtopics")
                        .font(.caption)
                        .foregroundStyle(Color.mcTextTertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(Color.mcBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.mcBorderLight, lineWidth: 1)
        )
    }
}
