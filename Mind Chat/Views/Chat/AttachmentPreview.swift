import SwiftUI

struct AttachmentPreview: View {

    @Binding var attachments: [PendingAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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

                        // Remove button — sits outside the thumbnail corner
                        Button {
                            attachments.removeAll { $0.id == att.id }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mcBgPrimary)
                                    .frame(width: 20, height: 20)
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(Color.mcTextPrimary)
                            }
                        }
                        // Offset places the button's centre on the top-right corner of the thumbnail
                        .offset(x: 8, y: -8)
                    }
                    // Inset so the overflowing button is never cropped
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 92)
    }
}
