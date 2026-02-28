import SwiftUI

struct AttachmentPreview: View {

    @Binding var attachments: [PendingAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { att in
                    ZStack(alignment: .topTrailing) {
                        if att.kind == .image {
                            // Decode image data off the main thread
                            AsyncThumbnail(data: att.data)
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
                            ZStack {
                                Circle()
                                    .fill(Color.mcBgPrimary)
                                    .frame(width: 20, height: 20)
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(Color.mcTextPrimary)
                            }
                        }
                        .offset(x: 8, y: -8)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 92)
    }
}

// MARK: - Async Thumbnail
// Decodes UIImage from Data on a background thread so the main thread is never blocked.

private struct AsyncThumbnail: View {

    let data: Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                SkeletonView()
            }
        }
        .task(id: data) {
            guard let data else { return }
            let decoded: UIImage? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: UIImage(data: data))
                }
            }
            image = decoded
        }
    }
}
