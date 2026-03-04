import Foundation
import Combine

// MARK: - Cache Key

enum CacheKey {
    case conversations
    case topicsTree
    case topicsStats
    case topicDetail(id: String)
    case settings
    case usage

    var rawKey: String {
        switch self {
        case .conversations:        return "conversations"
        case .topicsTree:           return "topics_tree"
        case .topicsStats:          return "topics_stats"
        case .topicDetail(let id):  return "topic_detail_\(id)"
        case .settings:             return "settings"
        case .usage:                return "usage"
        }
    }

    var ttl: TimeInterval {
        switch self {
        case .conversations:  return 1 * 24 * 60 * 60
        case .topicsTree:     return 1 * 24 * 60 * 60
        case .topicsStats:    return 1 * 24 * 60 * 60
        case .topicDetail:    return 1 * 24 * 60 * 60
        case .settings:       return 30 * 24 * 60 * 60
        case .usage:          return 30 * 24 * 60 * 60
        }
    }

    /// Disk file name for this cache entry.
    var diskKey: String { "mc_disk_cache_\(rawKey).json" }
}

// MARK: - Cache Store

@MainActor
final class CacheStore {

    static let shared = CacheStore()

    // MARK: - Private Types

    private struct Entry {
        let value: Any
        let expiresAt: Date
    }

    /// Envelope written to disk for all cached data.
    private struct DiskEntry: Codable {
        let data: Data        // JSON-encoded value
        let expiresAt: Date
    }

    // MARK: - Storage

    private var store: [String: Entry] = [:]
    private var cancellables = Set<AnyCancellable>()

    private let cacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MindChatAPICache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        migrateFromUserDefaults()

        EventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .conversationCreated:
                    self?.invalidate(.conversations)
                case .topicsUpdated:
                    self?.invalidate(.topicsTree)
                    self?.invalidate(.topicsStats)
                case .factsUpdated:
                    self?.invalidateAllTopicDetails()
                    self?.invalidate(.topicsTree)
                    self?.invalidate(.topicsStats)
                case .userSignedOut:
                    self?.invalidateAll()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Get / Set

    func get<T>(_ key: CacheKey) -> T? {
        // 1. In-memory hit
        if let entry = store[key.rawKey], entry.expiresAt > Date() {
            return entry.value as? T
        }
        // 2. Disk fallback (cold launch)
        return getFromDisk(key)
    }

    private func getFromDisk<T>(_ key: CacheKey) -> T? {
        let file = cacheDir.appendingPathComponent(key.diskKey)
        guard let raw = try? Data(contentsOf: file),
              let entry = try? JSONDecoder.mindChat.decode(DiskEntry.self, from: raw),
              entry.expiresAt > Date()
        else { return nil }

        let value: Any?
        switch key {
        case .conversations:
            value = try? JSONDecoder.mindChat.decode([Conversation].self, from: entry.data)
        case .topicsTree:
            value = try? JSONDecoder.mindChat.decode([TopicTreeNode].self, from: entry.data)
        case .topicsStats:
            value = try? JSONDecoder.mindChat.decode(TopicStatsResponse.self, from: entry.data)
        case .topicDetail:
            value = try? JSONDecoder.mindChat.decode(TopicDetailResponse.self, from: entry.data)
        case .settings:
            value = try? JSONDecoder.mindChat.decode(SettingsResponse.self, from: entry.data)
        case .usage:
            value = try? JSONDecoder.mindChat.decode(UsageResponse.self, from: entry.data)
        }
        guard let v = value as? T else { return nil }
        // Promote to in-memory cache
        store[key.rawKey] = Entry(value: v, expiresAt: entry.expiresAt)
        return v
    }

    func set<T>(_ key: CacheKey, value: T) {
        let expiresAt = Date().addingTimeInterval(key.ttl)
        store[key.rawKey] = Entry(value: value, expiresAt: expiresAt)
        if let encodable = value as? any Encodable {
            writeToDisk(key, encodable: encodable, expiresAt: expiresAt)
        }
    }

    // MARK: - Invalidation

    func invalidate(_ key: CacheKey) {
        store.removeValue(forKey: key.rawKey)
        removeFromDisk(key)
    }

    func invalidateAllTopicDetails() {
        store.keys
            .filter { $0.hasPrefix("topic_detail_") }
            .forEach { store.removeValue(forKey: $0) }
        // Remove topic detail files from disk
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("mc_disk_cache_topic_detail_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func invalidateAll() {
        store.removeAll()
        // Remove all disk cache files
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Disk Persistence (Caches directory)

    private func writeToDisk(_ key: CacheKey, encodable: any Encodable, expiresAt: Date) {
        guard let data = try? JSONEncoder.mindChat.encode(encodable),
              let entryData = try? JSONEncoder.mindChat.encode(DiskEntry(data: data, expiresAt: expiresAt))
        else { return }
        let file = cacheDir.appendingPathComponent(key.diskKey)
        try? entryData.write(to: file, options: .atomic)
    }

    private func removeFromDisk(_ key: CacheKey) {
        let file = cacheDir.appendingPathComponent(key.diskKey)
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - Migration

    /// One-time migration: move settings & usage from UserDefaults to file-based cache.
    private func migrateFromUserDefaults() {
        let legacyKeys: [CacheKey] = [.settings, .usage]
        for key in legacyKeys {
            let udKey = "mc_disk_cache_\(key.rawKey)"
            if let data = UserDefaults.standard.data(forKey: udKey) {
                let file = cacheDir.appendingPathComponent(key.diskKey)
                if !FileManager.default.fileExists(atPath: file.path) {
                    try? data.write(to: file, options: .atomic)
                }
                UserDefaults.standard.removeObject(forKey: udKey)
            }
        }
    }
}
