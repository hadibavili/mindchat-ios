import SwiftUI

struct AttachmentPreview: View {

    @Binding var attachments: [PendingAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { att in
                    ZStack(alignment: .topTrailing) {
                        if att.kind == .image, let data = att.data, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            VStack(spacing: 4) {
                                FileIconView(mimeType: att.mimeType, name: att.name, size: 32)
                                Text(att.name)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 72, height: 72)
                            .background(Color.mcBgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Remove button
                        Button {
                            attachments.removeAll { $0.id == att.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 88)
    }
}
