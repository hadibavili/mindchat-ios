import SwiftUI
import Combine

// MARK: - Search View Model

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query        = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading    = false
    @Published var selectedType: FactType? = nil
    @Published var errorMessage: String?

    private let service = TopicService.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - Search (debounced via onChange)

    func onQueryChanged(_ newValue: String) {
        searchTask?.cancel()
        guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await service.search(query: q, type: selectedType)
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Grouped Results

    struct SearchGroup: Identifiable {
        let id: String       // topicId
        let topicName: String
        let topicPath: String
        let topicIcon: String?
        let facts: [SearchResult]
    }

    var groupedResults: [SearchGroup] {
        var map: [String: (name: String, path: String, icon: String?, facts: [SearchResult])] = [:]
        for r in results where r.isFact {
            if map[r.topicId] == nil {
                map[r.topicId] = (r.topicName, r.topicPath, r.topicIcon, [])
            }
            map[r.topicId]?.facts.append(r)
        }
        return map
            .map { SearchGroup(id: $0.key, topicName: $0.value.name, topicPath: $0.value.path,
                               topicIcon: $0.value.icon, facts: $0.value.facts) }
            .sorted { $0.facts.count > $1.facts.count }
    }
}
