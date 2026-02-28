import Foundation
import Combine

// MARK: - Cache Key

enum CacheKey {
    case conversations           // TTL: 5min
    case topicsTree              // TTL: 10min
    case topicsStats             // TTL: 10min
    case topicDetail(id: String) // TTL: 5min
    case settings                // TTL: 1hr  — disk-persisted
    case usage                   // TTL: 15min — disk-persisted

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
        case .conversations:  return 5 * 60
        case .topicsTree:     return 10 * 60
        case .topicsStats:    return 10 * 60
        case .topicDetail:    return 5 * 60
        case .settings:       return 5 * 60
        case .usage:          return 15 * 60
        }
    }

    /// Keys whose values are written to UserDefaults and survive app restarts.
    var persistsToDisk: Bool {
        switch self {
        case .settings, .usage: return true
        default:                return false
        }
    }

    /// UserDefaults key for the encoded DiskEntry blob.
    var diskKey: String { "mc_disk_cache_\(rawKey)" }
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

    /// Envelope written to UserDefaults for disk-persisted keys.
    private struct DiskEntry: Codable {
        let data: Data        // JSONEncoded value
        let expiresAt: Date
    }

    // MARK: - Storage

    private var store: [String: Entry] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
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
        // 2. Disk fallback for persistent keys (cold launch)
        // The cast to T: Decodable is checked at runtime; non-Decodable types simply miss.
        return getFromDisk(key)
    }

    private func getFromDisk<T>(_ key: CacheKey) -> T? {
        // Only attempt disk read if T is Decodable — use conditional conformance trick
        guard key.persistsToDisk else { return nil }
        // We decode via AnyDecodable indirection: try to find the SettingsResponse / UsageResponse
        // by decoding the raw DiskEntry and then casting to T.
        guard let raw = UserDefaults.standard.data(forKey: key.diskKey),
              let entry = try? JSONDecoder.mindChat.decode(DiskEntry.self, from: raw),
              entry.expiresAt > Date()
        else { return nil }

        // Attempt decode using the concrete types that are actually disk-persisted.
        let value: Any?
        switch key {
        case .settings:
            value = try? JSONDecoder.mindChat.decode(SettingsResponse.self, from: entry.data)
        case .usage:
            value = try? JSONDecoder.mindChat.decode(UsageResponse.self, from: entry.data)
        default:
            return nil
        }
        guard let v = value as? T else { return nil }
        store[key.rawKey] = Entry(value: v, expiresAt: entry.expiresAt)
        return v
    }

    func set<T>(_ key: CacheKey, value: T) {
        let expiresAt = Date().addingTimeInterval(key.ttl)
        store[key.rawKey] = Entry(value: value, expiresAt: expiresAt)
        // Write to disk for persistent keys (only if T is Encodable)
        if key.persistsToDisk, let encodable = value as? any Encodable {
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
    }

    func invalidateAll() {
        store.removeAll()
        // Clear all disk-persisted entries
        removeFromDisk(.settings)
        removeFromDisk(.usage)
    }

    // MARK: - Disk Persistence (UserDefaults)

    private func writeToDisk(_ key: CacheKey, encodable: any Encodable, expiresAt: Date) {
        guard key.persistsToDisk,
              let data = try? JSONEncoder.mindChat.encode(encodable),
              let entryData = try? JSONEncoder.mindChat.encode(DiskEntry(data: data, expiresAt: expiresAt))
        else { return }
        UserDefaults.standard.set(entryData, forKey: key.diskKey)
    }

    private func removeFromDisk(_ key: CacheKey) {
        guard key.persistsToDisk else { return }
        UserDefaults.standard.removeObject(forKey: key.diskKey)
    }
}
