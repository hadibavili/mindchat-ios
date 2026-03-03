import UIKit

/// A simple disk-backed image cache stored in the system Caches directory.
/// Images are keyed by their source URL and expire after 1 day.
/// iOS may evict the Caches directory under storage pressure, which is fine —
/// images will simply be re-downloaded on next access.
final class ImageDiskCache {
    static let shared = ImageDiskCache()
    private init() {}

    private let ttl: TimeInterval = 86_400  // 1 day

    private let cacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MindChatImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func filename(for url: String) -> String {
        "\(url.hashValue).jpg"
    }

    /// Returns a cached UIImage if one exists on disk and is younger than the TTL.
    func read(for url: String) -> UIImage? {
        let file = cacheDir.appendingPathComponent(filename(for: url))
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
            let modified = attrs[.modificationDate] as? Date,
            Date().timeIntervalSince(modified) < ttl,
            let data = try? Data(contentsOf: file),
            let image = UIImage(data: data)
        else { return nil }
        return image
    }

    /// Writes an image to disk as JPEG. Silently ignores write failures.
    func write(_ image: UIImage, for url: String) {
        let file = cacheDir.appendingPathComponent(filename(for: url))
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// Removes cache files older than the TTL. Safe to call on a background thread at launch.
    func purgeExpired() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-ttl)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
