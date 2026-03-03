import SwiftUI
import UIKit
import Photos

struct ImageViewerSheet: View {

    let item: SelectedImageItem
    @Environment(\.dismiss) private var dismiss

    @State private var displayImage: UIImage?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var saveStatus: SaveStatus = .idle

    enum SaveStatus { case idle, saving, saved, failed }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = displayImage {
                Image(uiImage: img)
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
                            .onChanged { value in if scale > 1 { offset = value.translation } }
                            .onEnded   { _ in if scale <= 1 { withAnimation { offset = .zero } } }
                    )
            } else {
                ProgressView().tint(.white)
            }
        }
        // Close button — always visible
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        // Save / Share toolbar
        .overlay(alignment: .bottom) {
            HStack(spacing: 20) {
                // Save to Photos
                Button { saveToPhotos() } label: {
                    HStack(spacing: 6) {
                        Group {
                            switch saveStatus {
                            case .idle:   Image(systemName: "square.and.arrow.down")
                            case .saving: ProgressView().tint(.white).scaleEffect(0.8)
                            case .saved:  Image(systemName: "checkmark")
                            case .failed: Image(systemName: "exclamationmark.triangle")
                            }
                        }
                        .frame(width: 16)
                        Text(saveStatus == .saved ? "Saved" : saveStatus == .failed ? "Failed" : "Save")
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(displayImage == nil || saveStatus == .saving)

                // Share
                Button { showShareSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share").fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(displayImage == nil)
            }
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = displayImage {
                ShareSheet(items: [img]).ignoresSafeArea()
            }
        }
        .statusBarHidden()
        .task {
            await loadImage()
        }
    }

    // MARK: - Load Image

    private func loadImage() async {
        // Use preloaded image from cache if available
        if let pre = item.preloadedImage {
            displayImage = pre
            return
        }
        // Otherwise download with Bearer auth (rewrite raw blob URLs to proxy)
        let resolvedURLString: String
        if let u = URL(string: item.url),
           let host = u.host,
           host.hasSuffix(".blob.vercel-storage.com"),
           let encoded = item.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            resolvedURLString = "https://app.mindchat.fenqor.nl/api/blob?url=\(encoded)"
        } else {
            resolvedURLString = item.url
        }
        guard let url = URL(string: resolvedURLString) else {
            print("[ImageViewerSheet] invalid URL: \(item.url)")
            return
        }
        var request = URLRequest(url: url)
        if let token = KeychainManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let img = UIImage(data: data) else {
            print("[ImageViewerSheet] failed to load image from \(item.url)")
            return
        }
        print("[ImageViewerSheet] loaded \(data.count) bytes")
        displayImage = img
    }

    // MARK: - Save to Photos

    private func saveToPhotos() {
        guard let img = displayImage else { return }
        saveStatus = .saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { saveStatus = .failed }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    saveStatus = success ? .saved : .failed
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveStatus = .idle }
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
