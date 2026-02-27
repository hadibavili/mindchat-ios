import SwiftUI
import Combine

// MARK: - Topic Detail View Model

@MainActor
final class TopicDetailViewModel: ObservableObject {

    @Published var detail: TopicDetailResponse?
    @Published var facts: [Fact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filters
    @Published var selectedType: FactType?       = nil
    @Published var sortOrder: FactSortOrder      = .newest
    @Published var selectedImportance: FactImportance? = nil

    private let topicId: String
    private let service = TopicService.shared
    private var cancellables = Set<AnyCancellable>()

    init(topicId: String) {
        self.topicId = topicId
        EventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .factsUpdated = event {
                    Task { await self?.refresh() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func load() async {
        // Cache-first: return cached data immediately without spinner
        if let cached: TopicDetailResponse = CacheStore.shared.get(.topicDetail(id: topicId)) {
            detail = cached
            facts  = cached.facts
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let d = try await service.topicDetail(id: topicId)
            detail = d
            facts  = d.facts
            CacheStore.shared.set(.topicDetail(id: topicId), value: d)
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            let d = try await service.topicDetail(id: topicId)
            detail = d
            facts  = d.facts
            CacheStore.shared.set(.topicDetail(id: topicId), value: d)
        } catch {}
    }

    // MARK: - Filtered & Sorted Facts

    var filteredFacts: [Fact] {
        var result = facts

        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        if let importance = selectedImportance, importance != .none {
            result = result.filter { $0.importance == importance }
        }

        switch sortOrder {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .importance:
            result.sort {
                let order: [FactImportance: Int] = [.high: 0, .medium: 1, .low: 2, .none: 3]
                let a = order[$0.importance ?? .none] ?? 3
                let b = order[$1.importance ?? .none] ?? 3
                return a < b
            }
        }
        return result
    }

    func count(for type: FactType) -> Int {
        facts.filter { $0.type == type }.count
    }

    // MARK: - Fact Actions

    func togglePin(factId: String) async {
        guard let idx = facts.firstIndex(where: { $0.id == factId }) else { return }
        let current = facts[idx].pinned
        facts[idx].pinned = !current   // Optimistic

        do {
            let updated = try await service.updateFact(id: factId, pinned: !current)
            facts[idx] = updated
            CacheStore.shared.invalidate(.topicDetail(id: topicId))
            EventBus.shared.publish(.factsUpdated)
            Haptics.light()
        } catch {
            facts[idx].pinned = current  // Rollback
        }
    }

    func updateContent(factId: String, content: String) async {
        guard let idx = facts.firstIndex(where: { $0.id == factId }) else { return }
        let old = facts[idx].content
        facts[idx].content = content  // Optimistic

        do {
            let updated = try await service.updateFact(id: factId, content: content)
            facts[idx] = updated
            CacheStore.shared.invalidate(.topicDetail(id: topicId))
            EventBus.shared.publish(.factsUpdated)
        } catch {
            facts[idx].content = old  // Rollback
        }
    }

    func deleteFact(factId: String) async {
        guard let idx = facts.firstIndex(where: { $0.id == factId }) else { return }
        let saved = facts[idx]
        facts.remove(at: idx)   // Optimistic

        do {
            try await service.deleteFact(id: factId)
            CacheStore.shared.invalidate(.topicDetail(id: topicId))
            EventBus.shared.publish(.factsUpdated)
            Haptics.medium()
        } catch {
            facts.insert(saved, at: idx)  // Rollback
        }
    }

    // MARK: - Undo-Delete Helpers (used by FactItemView for 5-second undo)

    /// Remove a fact from the local array without calling the API.
    func removeFactLocally(factId: String) {
        facts.removeAll { $0.id == factId }
    }

    /// Re-insert a fact into the local array (undo path).
    func restoreFactLocally(_ fact: Fact) {
        guard !facts.contains(where: { $0.id == fact.id }) else { return }
        // Insert in the same relative position by createdAt DESC (default sort)
        if let insertIdx = facts.firstIndex(where: { $0.createdAt < fact.createdAt }) {
            facts.insert(fact, at: insertIdx)
        } else {
            facts.append(fact)
        }
    }

    /// Commit the delete to the server (called after 5-second undo window).
    func commitDeleteFact(factId: String) async {
        do {
            CacheStore.shared.invalidate(.topicDetail(id: topicId))
            try await service.deleteFact(id: factId)
            EventBus.shared.publish(.factsUpdated)
        } catch {
            // If server delete fails, the fact is already gone from local state.
            // Re-fetch to restore consistency.
            await refresh()
        }
    }

    // MARK: - Merge

    func merge(into targetId: String) async throws {
        try await service.merge(sourceId: topicId, targetId: targetId)
    }
}
