import SwiftUI
import Combine

// MARK: - Conversations View Model

@MainActor
final class ConversationsViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let chat = ChatService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        EventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .conversationCreated = event {
                    Task { await self?.refresh() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func load() async {
        // Cache-first: return cached data immediately without showing spinner
        if let cached: [Conversation] = CacheStore.shared.get(.conversations) {
            conversations = cached
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await chat.conversations()
            conversations = result
            CacheStore.shared.set(.conversations, value: result)
        } catch let e as AppError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            let result = try await chat.conversations()
            conversations = result
            CacheStore.shared.set(.conversations, value: result)
        } catch {}
    }

    // MARK: - Delete

    func delete(conversation: Conversation) async {
        conversations.removeAll { $0.id == conversation.id }
        CacheStore.shared.invalidate(.conversations)
        do {
            try await chat.deleteConversation(id: conversation.id)
        } catch {
            // Rollback
            await refresh()
        }
    }

    func delete(at offsets: IndexSet) async {
        let ids = offsets.map { conversations[$0].id }
        conversations.remove(atOffsets: offsets)
        CacheStore.shared.invalidate(.conversations)
        for id in ids {
            try? await chat.deleteConversation(id: id)
        }
    }

    // MARK: - Rename

    func rename(conversation: Conversation, title: String) async {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].title = title   // optimistic
        CacheStore.shared.invalidate(.conversations)
        do {
            try await chat.renameConversation(id: conversation.id, title: title)
        } catch {
            conversations[idx].title = conversation.title  // rollback
        }
    }
}
