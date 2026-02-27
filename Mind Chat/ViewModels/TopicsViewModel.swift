import SwiftUI
import Combine

// MARK: - Topics View Model

@MainActor
final class TopicsViewModel: ObservableObject {

    @Published var rootTopics: [TopicTreeNode] = []
    @Published var stats: TopicStatsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let topicService = TopicService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        EventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .topicsUpdated = event {
                    Task { await self?.refresh() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func load() async {
        // Cache-first: populate from cache without spinner if both entries are warm
        let cachedTree: [TopicTreeNode]? = CacheStore.shared.get(.topicsTree)
        let cachedStats: TopicStatsResponse? = CacheStore.shared.get(.topicsStats)
        if let tree = cachedTree {
            rootTopics = tree
            stats = cachedStats
            return
        }
        isLoading = true
        defer { isLoading = false }
        await loadTree()
        await loadStats()
    }

    func refresh() async {
        await loadTree()
        await loadStats()
    }

    private func loadTree() async {
        do {
            let result = try await topicService.topicsTree()
            rootTopics = result
            CacheStore.shared.set(.topicsTree, value: result)
            errorMessage = nil
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStats() async {
        // Stats are non-critical — failure doesn't affect topic display
        if let result = try? await topicService.stats() {
            stats = result
            CacheStore.shared.set(.topicsStats, value: result)
        }
    }

    // MARK: - Computed

    var totalFacts: Int { stats?.totalFacts ?? rootTopics.reduce(0) { $0 + $1.totalFactCount } }
    var totalTopics: Int { stats?.totalTopics ?? rootTopics.count }
}
