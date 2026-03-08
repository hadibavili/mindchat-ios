import Foundation
import UIKit

// MARK: - Error Reporter

/// Sends structured error reports to `POST /api/error-reports`.
/// Uses URLSession directly (not APIClient) to avoid circular reporting loops.
/// Auth is optional — reports can be sent even before login.
nonisolated final class ErrorReporter: Sendable {

    static let shared = ErrorReporter()

    private let baseURL = "https://app.mindchat.fenqor.nl"
    private let session = URLSession.shared

    private init() {}

    // MARK: - Public API

    func report(
        category: ErrorCategory,
        message: String,
        severity: ErrorSeverity = .error,
        stackTrace: String? = nil,
        endpoint: String? = nil,
        httpStatus: Int? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil,
        conversationId: String? = nil,
        metadata: [String: String]? = nil
    ) {
        Task.detached(priority: .utility) {
            await self.send(
                category: category,
                message: message,
                severity: severity,
                stackTrace: stackTrace,
                endpoint: endpoint,
                httpStatus: httpStatus,
                requestBody: requestBody,
                responseBody: responseBody,
                conversationId: conversationId,
                metadata: metadata
            )
        }
    }

    // MARK: - Convenience: API Errors

    func reportAPIError(
        endpoint: String,
        statusCode: Int,
        responseBody: String? = nil,
        conversationId: String? = nil
    ) {
        report(
            category: .apiError,
            message: "\(endpoint) failed with \(statusCode)",
            severity: statusCode >= 500 ? .critical : .error,
            endpoint: endpoint,
            httpStatus: statusCode,
            responseBody: responseBody,
            conversationId: conversationId
        )
    }

    // MARK: - Convenience: Stream Failures

    func reportStreamFailure(
        message: String,
        conversationId: String? = nil,
        model: String? = nil,
        lastEvent: String? = nil
    ) {
        var meta: [String: String] = [:]
        if let model { meta["modelId"] = model }
        if let lastEvent { meta["lastEventReceived"] = lastEvent }

        report(
            category: .promptFailure,
            message: message,
            endpoint: "/api/chat",
            conversationId: conversationId,
            metadata: meta.isEmpty ? nil : meta
        )
    }

    // MARK: - Convenience: Network Errors

    func reportNetworkError(
        endpoint: String,
        error: Error,
        conversationId: String? = nil
    ) {
        let nsError = error as NSError
        report(
            category: .networkError,
            message: "Request to \(endpoint) failed: \(error.localizedDescription)",
            endpoint: endpoint,
            metadata: [
                "errorCode": "\(nsError.code)",
                "errorDomain": nsError.domain
            ]
        )
    }

    // MARK: - Convenience: Crash

    func reportCrash(
        message: String,
        stackTrace: String? = nil,
        screenName: String? = nil
    ) {
        var meta: [String: String] = [:]
        if let screenName { meta["screenName"] = screenName }

        report(
            category: .crash,
            message: message,
            severity: .critical,
            stackTrace: stackTrace,
            metadata: meta.isEmpty ? nil : meta
        )
    }

    // MARK: - Private

    private func send(
        category: ErrorCategory,
        message: String,
        severity: ErrorSeverity,
        stackTrace: String?,
        endpoint: String?,
        httpStatus: Int?,
        requestBody: String?,
        responseBody: String?,
        conversationId: String?,
        metadata: [String: String]?
    ) async {
        let deviceInfo = await buildDeviceInfo()
        let token = await KeychainManager.shared.accessToken

        var body: [String: Any] = [
            "source": "ios",
            "category": category.rawValue,
            "severity": severity.rawValue,
            "message": message,
            "deviceInfo": deviceInfo
        ]

        if let stackTrace { body["stackTrace"] = stackTrace }
        if let endpoint { body["endpoint"] = endpoint }
        if let httpStatus { body["httpStatus"] = httpStatus }
        if let requestBody { body["requestBody"] = requestBody }
        if let responseBody { body["responseBody"] = responseBody }
        if let conversationId { body["conversationId"] = conversationId }
        if let metadata { body["metadata"] = metadata }

        guard let url = URL(string: "\(baseURL)/api/error-reports"),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Fire and forget — don't block the caller
        _ = try? await session.data(for: request)
    }

    @MainActor
    private func buildDeviceInfo() -> [String: String] {
        [
            "os": "iOS",
            "osVersion": UIDevice.current.systemVersion,
            "device": deviceModel(),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "locale": Locale.current.identifier
        ]
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}

// MARK: - Types

nonisolated enum ErrorCategory: String, Sendable {
    case crash         = "crash"
    case apiError      = "api_error"
    case promptFailure = "prompt_failure"
    case uiError       = "ui_error"
    case networkError  = "network_error"
}

nonisolated enum ErrorSeverity: String, Sendable {
    case critical = "critical"
    case error    = "error"
    case warning  = "warning"
    case info     = "info"
}
