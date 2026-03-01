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
            print("[Transcribe] Could not read audio file at \(audioURL.path)")
            throw AppError.networkError("Could not read audio file")
        }
        print("[Transcribe] Uploading \(data.count) bytes to /api/transcribe")
        // Debug: log first 4 bytes to verify file header (M4A starts with 0x00 0x00 0x00 followed by 'ftyp')
        let header = data.prefix(12)
        print("[Transcribe] File header: \(header.map { String(format: "%02x", $0) }.joined(separator: " "))")
        if let headerStr = String(data: data.prefix(12).dropFirst(4), encoding: .ascii) {
            print("[Transcribe] Header ASCII (offset 4): \(headerStr)")
        }
        let response: TranscribeResponse = try await api.upload(
            "/api/transcribe",
            data: data,
            name: "audio.m4a",
            mimeType: "audio/mp4",
            fieldName: "audio"
        )
        print("[Transcribe] Response text (\(response.text.count) chars): \"\(response.text.prefix(100))\"")
        return response.text
    }
}
