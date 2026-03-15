import Foundation

// MARK: - API Client

@MainActor
final class APIClient {

    static let shared = APIClient()

    // MARK: Config
    private let baseURL = "https://app.mindchat.fenqor.nl"

    private let keychain = KeychainManager.shared
    private let session  = URLSession.shared
    private var isRefreshing = false

    private init() {}

    // MARK: - Request

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let url = try buildURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let timeout { req.timeoutInterval = timeout }

        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("🔑 [DEBUG] Bearer \(token)")
            #endif
        }
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            req.httpBody = try JSONEncoder.mindChat.encode(body)
        }

        return try await perform(req)
    }

    // MARK: - Upload

    func upload<T: Decodable>(
        _ path: String,
        data: Data,
        name: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        let url = try buildURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 [DEBUG] Bearer \(token)")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await perform(req)
    }

    // MARK: - SSE Stream (returns URLSession bytes sequence)

    func sseRequest(_ path: String, body: Encodable) async throws -> URLSession.AsyncBytes {
        let url = try buildURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder.mindChat.encode(body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: req)
        } catch {
            ErrorReporter.shared.reportNetworkError(endpoint: path, error: error)
            throw AppError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            ErrorReporter.shared.reportAPIError(endpoint: path, statusCode: http.statusCode)
            switch http.statusCode {
            case 401: throw AppError.unauthorized
            case 403: throw AppError.forbidden
            case 429: throw AppError.rateLimited
            default:  throw AppError.serverError("HTTP \(http.statusCode)")
            }
        }
        return bytes
    }

    // MARK: - Raw Data Request

    func requestRawData(_ path: String, method: String = "GET") async throws -> Data {
        let url = try buildURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            ErrorReporter.shared.reportNetworkError(endpoint: path, error: error)
            throw AppError.networkError(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            ErrorReporter.shared.reportAPIError(endpoint: path, statusCode: http.statusCode)
            throw AppError.serverError("HTTP \(http.statusCode)")
        }
        return data
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let endpoint = req.url?.path ?? "unknown"
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: req)
        } catch {
            // Don't report errors for the error-reports endpoint itself
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportNetworkError(endpoint: endpoint, error: error)
            }
            throw AppError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200...299:
            // Detect HTML redirect masquerading as 200 (server returns login page for unauth requests)
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            if contentType.contains("text/html") {
                if !endpoint.contains("error-reports") {
                    ErrorReporter.shared.reportAPIError(
                        endpoint: endpoint, statusCode: http.statusCode,
                        responseBody: "HTML redirect detected (Content-Type: text/html)"
                    )
                }
                throw AppError.unauthorized
            }
            // Also catch HTML body even if Content-Type header is missing/wrong
            if let prefix = String(data: data.prefix(20), encoding: .utf8),
               prefix.lowercased().hasPrefix("<!doctype") || prefix.lowercased().hasPrefix("<html") {
                if !endpoint.contains("error-reports") {
                    ErrorReporter.shared.reportAPIError(
                        endpoint: endpoint, statusCode: http.statusCode,
                        responseBody: "HTML redirect detected (body starts with HTML)"
                    )
                }
                throw AppError.unauthorized
            }
            do {
                return try JSONDecoder.mindChat.decode(T.self, from: data)
            } catch {
                if !endpoint.contains("error-reports") {
                    ErrorReporter.shared.reportAPIError(
                        endpoint: endpoint, statusCode: http.statusCode,
                        responseBody: "Decoding failed: \(error.localizedDescription)"
                    )
                }
                throw AppError.decodingError(error.localizedDescription)
            }
        case 401:
            // Try refresh once
            if !isRefreshing {
                isRefreshing = true
                defer { isRefreshing = false }
                do {
                    try await refreshTokens()
                    return try await perform(retried(req))
                } catch {
                    if !endpoint.contains("error-reports") {
                        ErrorReporter.shared.reportAPIError(endpoint: endpoint, statusCode: 401)
                    }
                    throw error
                }
            }
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(endpoint: endpoint, statusCode: 401)
            }
            throw AppError.unauthorized
        case 403:
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(endpoint: endpoint, statusCode: 403)
            }
            throw AppError.forbidden
        case 404:
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(endpoint: endpoint, statusCode: 404)
            }
            throw AppError.notFound
        case 429:
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(endpoint: endpoint, statusCode: 429)
            }
            throw AppError.rateLimited
        case 400:
            let responseStr = String(data: data, encoding: .utf8)
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(
                    endpoint: endpoint, statusCode: 400, responseBody: responseStr
                )
            }
            if let errResp = try? JSONDecoder.mindChat.decode(ErrorResponse.self, from: data) {
                throw AppError.serverError(errResp.error)
            }
            throw AppError.serverError("Bad request")
        default:
            let responseStr = String(data: data, encoding: .utf8)
            if !endpoint.contains("error-reports") {
                ErrorReporter.shared.reportAPIError(
                    endpoint: endpoint, statusCode: http.statusCode, responseBody: responseStr
                )
            }
            if let errResp = try? JSONDecoder.mindChat.decode(ErrorResponse.self, from: data) {
                throw AppError.serverError(errResp.error)
            }
            throw AppError.serverError("HTTP \(http.statusCode)")
        }
    }

    private func refreshTokens() async throws {
        guard let refreshToken = keychain.refreshToken else {
            keychain.clearAll()
            throw AppError.unauthorized
        }
        struct Body: Encodable { let refreshToken: String }
        let response: RefreshResponse = try await request(
            "/api/auth/mobile/refresh",
            method: "POST",
            body: Body(refreshToken: refreshToken)
        )
        keychain.save(tokens: (access: response.token, refresh: response.refreshToken))
    }

    private func retried(_ req: URLRequest) -> URLRequest {
        var newReq = req
        if let token = keychain.accessToken {
            newReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return newReq
    }

    private func buildURL(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw AppError.networkError("Invalid URL: \(path)")
        }
        return url
    }
}
