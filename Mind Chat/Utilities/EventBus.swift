import Foundation
import Combine

// MARK: - Event Types

enum AppEvent: Sendable {
    case conversationCreated(id: String, title: String?)
    case topicsUpdated
    case factsUpdated
    case modelChanged(provider: AIProvider, model: String)
    case userSignedOut
    case emailVerified
    case navigateToMessage(conversationId: String, messageId: String)
}

// MARK: - Event Bus

@MainActor
final class EventBus: ObservableObject {

    static let shared = EventBus()

    private let subject = PassthroughSubject<AppEvent, Never>()

    var events: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    func publish(_ event: AppEvent) {
        subject.send(event)
    }
}

// MARK: - View Extension

import SwiftUI

extension View {
    func onAppEvent(_ event: AppEvent.Type = AppEvent.self,
                    perform action: @escaping (AppEvent) -> Void) -> some View {
        self.onReceive(EventBus.shared.events) { appEvent in
            action(appEvent)
        }
    }
}
