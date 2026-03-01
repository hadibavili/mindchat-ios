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
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = try buildURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

        let sseConnectStart = Date()
        print("[Timing] SSE → opening TCP connection to \(path)")
        let (bytes, response) = try await session.bytes(for: req)
        print("[Timing] SSE → connection established in \(String(format: "%.0f", Date().timeIntervalSince(sseConnectStart) * 1000))ms")
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
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
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw AppError.serverError("HTTP \(http.statusCode)")
        }
        return data
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200...299:
            // Detect HTML redirect masquerading as 200 (server returns login page for unauth requests)
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            if contentType.contains("text/html") {
                throw AppError.unauthorized
            }
            // Also catch HTML body even if Content-Type header is missing/wrong
            if let prefix = String(data: data.prefix(20), encoding: .utf8),
               prefix.lowercased().hasPrefix("<!doctype") || prefix.lowercased().hasPrefix("<html") {
                throw AppError.unauthorized
            }
            do {
                return try JSONDecoder.mindChat.decode(T.self, from: data)
            } catch {
                let rawBody = String(data: data.prefix(2000), encoding: .utf8) ?? "<non-utf8>"
                print("[APIClient] Decode error for \(T.self): \(error)")
                print("[APIClient] Raw body: \(rawBody)")
                throw AppError.decodingError(error.localizedDescription)
            }
        case 401:
            // Try refresh once
            if !isRefreshing {
                isRefreshing = true
                defer { isRefreshing = false }
                try await refreshTokens()
                return try await perform(retried(req))
            }
            throw AppError.unauthorized
        case 403:
            throw AppError.forbidden
        case 404:
            throw AppError.notFound
        case 429:
            throw AppError.rateLimited
        case 400:
            if let errResp = try? JSONDecoder.mindChat.decode(ErrorResponse.self, from: data) {
                throw AppError.serverError(errResp.error)
            }
            throw AppError.serverError("Bad request")
        default:
            let rawBody = String(data: data.prefix(2000), encoding: .utf8) ?? "<non-utf8>"
            print("[APIClient] HTTP \(http.statusCode) for \(req.url?.path ?? "?")")
            print("[APIClient] Response body: \(rawBody)")
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
