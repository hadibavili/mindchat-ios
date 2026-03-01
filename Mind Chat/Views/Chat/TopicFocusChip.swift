import SwiftUI

struct TopicFocusChip: View {

    let focus: TopicFocus
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.mcTextPrimary)

            Text(focus.name)
                .font(.caption.bold())
                .foregroundStyle(Color.mcTextPrimary)
                .lineLimit(1)

            if focus.factCount > 0 {
                Text("\(focus.factCount) memories")
                    .font(.caption2)
                    .foregroundStyle(Color.mcTextTertiary)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.mcTextTertiary)
                    .frame(width: 18, height: 18)
                    .background(Color.mcBgActive)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.mcTextPrimary.opacity(0.1))
        .clipShape(Capsule())
        .transition(.chipAppear)
    }
}
