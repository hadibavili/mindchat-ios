import SwiftUI

struct ImageViewerSheet: View {

    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat  = 1
    @State private var offset: CGSize  = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = max(1, value) }
                                .onEnded   { _ in withAnimation { if scale < 1.2 { scale = 1; offset = .zero } } }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 { offset = value.translation }
                                }
                                .onEnded { _ in
                                    if scale <= 1 { withAnimation { offset = .zero } }
                                }
                        )
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                default:
                    ProgressView().tint(.white)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .statusBarHidden()
    }
}
