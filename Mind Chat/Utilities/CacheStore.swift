import Foundation
import Combine

// MARK: - Cache Key

enum CacheKey {
    case conversations           // TTL: 5min
    case topicsTree              // TTL: 10min
    case topicsStats             // TTL: 10min
    case topicDetail(id: String) // TTL: 5min

    var rawKey: String {
        switch self {
        case .conversations:        return "conversations"
        case .topicsTree:           return "topics_tree"
        case .topicsStats:          return "topics_stats"
        case .topicDetail(let id):  return "topic_detail_\(id)"
        }
    }

    var ttl: TimeInterval {
        switch self {
        case .conversations:  return 5 * 60
        case .topicsTree:     return 10 * 60
        case .topicsStats:    return 10 * 60
        case .topicDetail:    return 5 * 60
        }
    }
}

// MARK: - Cache Store

@MainActor
final class CacheStore {

    static let shared = CacheStore()

    private struct Entry {
        let value: Any
        let expiresAt: Date
    }

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
        guard let entry = store[key.rawKey], entry.expiresAt > Date() else { return nil }
        return entry.value as? T
    }

    func set<T>(_ key: CacheKey, value: T) {
        store[key.rawKey] = Entry(value: value, expiresAt: Date().addingTimeInterval(key.ttl))
    }

    // MARK: - Invalidation

    func invalidate(_ key: CacheKey) {
        store.removeValue(forKey: key.rawKey)
    }

    func invalidateAllTopicDetails() {
        store.keys
            .filter { $0.hasPrefix("topic_detail_") }
            .forEach { store.removeValue(forKey: $0) }
    }

    func invalidateAll() {
        store.removeAll()
    }
}
