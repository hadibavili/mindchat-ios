import UIKit

@MainActor
final class BackgroundStreamManager {

    static let shared = BackgroundStreamManager()

    private(set) var isInBackground = false
    private(set) var streamInterruptedByExpiry = false
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    func beginBackgroundProcessing() {
        guard backgroundTaskId == .invalid else { return }
        isInBackground = true
        streamInterruptedByExpiry = false

        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "MindChatStream") { [weak self] in
            // iOS is about to reclaim background time
            self?.streamInterruptedByExpiry = true
            self?.endTask()
        }
    }

    func streamDidComplete() {
        endTask()
    }

    func didReturnToForeground() {
        isInBackground = false
        endTask()
    }

    private func endTask() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }
}
