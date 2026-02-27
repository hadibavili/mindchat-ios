import Foundation
import UIKit
import AVFoundation

// MARK: - Upload Service

@MainActor
final class UploadService {

    static let shared = UploadService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - File / Image Upload

    func upload(data: Data, name: String, mimeType: String) async throws -> UploadResponse {
        return try await api.upload(
            "/api/upload",
            data: data,
            name: name,
            mimeType: mimeType
        )
    }

    func upload(attachment: PendingAttachment) async throws -> UploadResponse {
        guard let data = attachment.data ?? (try? Data(contentsOf: attachment.localURL)) else {
            throw AppError.networkError("Could not read file data")
        }
        let mime = attachment.mimeType ?? "application/octet-stream"
        return try await upload(data: data, name: attachment.name, mimeType: mime)
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL) async throws -> String {
        guard let data = try? Data(contentsOf: audioURL) else {
            throw AppError.networkError("Could not read audio file")
        }
        let response: TranscribeResponse = try await api.upload(
            "/api/transcribe",
            data: data,
            name: "audio.m4a",
            mimeType: "audio/m4a",
            fieldName: "audio"
        )
        return response.text
    }
}
