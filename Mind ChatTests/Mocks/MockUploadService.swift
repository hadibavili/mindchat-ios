import Foundation
@testable import Mind_Chat

// MARK: - Mock Upload Service

@MainActor
final class MockUploadService: UploadServiceProtocol {

    // MARK: - Call Tracking
    var uploadAttachmentCallCount = 0
    var uploadedAttachments: [PendingAttachment] = []

    // MARK: - Stubs
    var stubbedUploadResponse = UploadResponse(
        url: "https://cdn.example.com/uploaded.jpg",
        name: "photo.jpg",
        type: "image",
        mimeType: "image/jpeg"
    )
    var stubbedUploadError: Error?
    var stubbedTranscribeResult = "transcribed text"
    var stubbedTranscribeError: Error?

    // MARK: - UploadServiceProtocol

    func upload(attachment: PendingAttachment) async throws -> UploadResponse {
        uploadAttachmentCallCount += 1
        uploadedAttachments.append(attachment)
        if let error = stubbedUploadError { throw error }
        return UploadResponse(
            url: stubbedUploadResponse.url,
            name: attachment.name,
            type: stubbedUploadResponse.type,
            mimeType: attachment.mimeType
        )
    }

    func upload(data: Data, name: String, mimeType: String) async throws -> UploadResponse {
        if let error = stubbedUploadError { throw error }
        return stubbedUploadResponse
    }

    func transcribe(audioURL: URL) async throws -> String {
        if let error = stubbedTranscribeError { throw error }
        return stubbedTranscribeResult
    }
}
