import XCTest
import UIKit
@testable import Mind_Chat

// MARK: - ChatViewModel Image Tests (Groups G-1 through G-5)

@MainActor
final class ChatViewModelImageTests: XCTestCase {

    var sut: ChatViewModel!
    var mockChat: MockChatService!
    var mockSettings: MockSettingsService!
    var mockUpload: MockUploadService!

    override func setUp() async throws {
        mockChat     = MockChatService()
        mockSettings = MockSettingsService()
        mockUpload   = MockUploadService()
        sut = ChatViewModel(chat: mockChat, settings: mockSettings, upload: mockUpload)
    }

    override func tearDown() async throws {
        sut.stopStreaming()
        sut = nil
        mockChat     = nil
        mockSettings = nil
        mockUpload   = nil
    }

    func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func makePendingAttachment(name: String = "photo.jpg") -> PendingAttachment {
        let data = UIImage(systemName: "photo")!.jpegData(compressionQuality: 0.5)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        var att = PendingAttachment(localURL: url, name: name, kind: .image, mimeType: "image/jpeg")
        att.data = data
        return att
    }

    func assistantMessage() -> ChatMessage? {
        sut.messages.last(where: { $0.role == .assistant })
    }

    // MARK: - Group G-1: generatingImage SSE Event

    func test_generatingImage_event_clearsAfterDone() async {
        sut.inputText = "generate something"
        mockChat.stubbedStream = MockChatService.makeStream([
            .generatingImage,
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isGeneratingImage)
    }

    func test_generatingImage_clearsToolCallBlock() async {
        sut.inputText = "generate after tool call"
        mockChat.stubbedStream = MockChatService.makeStream([
            .token("<tool_call>"),
            .generatingImage,
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isGeneratingImage)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Group G-2: imageGenerated SSE Event

    func test_imageGenerated_appendsAttachmentToAssistantMessage() async {
        sut.inputText = "draw a sunset"
        mockChat.stubbedStream = MockChatService.makeStream([
            .imageGenerated(url: "https://cdn.example.com/art.png", name: "Sunset"),
            .done
        ])

        await sut.send()
        await drainTasks()

        let assistant = assistantMessage()
        XCTAssertEqual(assistant?.attachments?.count, 1)
        let att = assistant?.attachments?.first
        XCTAssertEqual(att?.url, "https://cdn.example.com/art.png")
        XCTAssertEqual(att?.name, "Sunset")
        XCTAssertEqual(att?.type, .image)
        XCTAssertEqual(att?.mimeType, "image/png")
    }

    func test_imageGenerated_clearsIsGeneratingImageFlag() async {
        sut.inputText = "make an image"
        mockChat.stubbedStream = MockChatService.makeStream([
            .generatingImage,
            .imageGenerated(url: "https://cdn.example.com/img.png", name: "Art"),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isGeneratingImage)
    }

    func test_imageGenerated_usesDefaultNameWhenNil() async {
        sut.inputText = "draw something"
        mockChat.stubbedStream = MockChatService.makeStream([
            .imageGenerated(url: "https://cdn.example.com/img.png", name: nil),
            .done
        ])

        await sut.send()
        await drainTasks()

        let att = assistantMessage()?.attachments?.first
        XCTAssertEqual(att?.name, "Generated Image")
    }

    func test_imageGenerated_appendsMultipleImages() async {
        sut.inputText = "draw two things"
        mockChat.stubbedStream = MockChatService.makeStream([
            .imageGenerated(url: "https://cdn.example.com/img1.png", name: "First"),
            .imageGenerated(url: "https://cdn.example.com/img2.png", name: "Second"),
            .done
        ])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(assistantMessage()?.attachments?.count, 2)
    }

    // MARK: - Group G-3: send() with Image Attachment

    func test_send_withImageAttachment_callsUploadService() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "What's in this image?"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()
        await drainTasks()

        XCTAssertEqual(mockUpload.uploadAttachmentCallCount, 1)
    }

    func test_send_withImageAttachment_appendsUserMessageWithAttachment() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "check this out"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()
        await drainTasks()

        let userMsg = sut.messages.first(where: { $0.role == .user })
        XCTAssertEqual(userMsg?.attachments?.count, 1)
    }

    func test_send_withAttachmentOnly_usesDefaultMessageText() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = ""
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()
        await drainTasks()

        let userMsg = sut.messages.first(where: { $0.role == .user })
        XCTAssertEqual(userMsg?.content, "What's in this?")
    }

    func test_send_clearsAttachmentsAfterSuccessfulUpload() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "look at this"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()
        await drainTasks()

        XCTAssertTrue(sut.attachments.isEmpty)
    }

    func test_send_setsIsUploadingFalseAfterDone() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "upload test"
        mockChat.stubbedStream = MockChatService.makeStream([.done])

        await sut.send()
        await drainTasks()

        XCTAssertFalse(sut.isUploading)
    }

    // MARK: - Group G-4: Upload Failure

    func test_send_uploadFailure_restoresAttachmentsAndInputText() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "original text"
        mockUpload.stubbedUploadError = AppError.networkError("Upload failed")

        await sut.send()

        XCTAssertFalse(sut.attachments.isEmpty)
        XCTAssertEqual(sut.inputText, "original text")
    }

    func test_send_uploadFailure_setsErrorMessage() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "test message"
        mockUpload.stubbedUploadError = AppError.networkError("Upload failed")

        await sut.send()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("failed to upload") == true)
    }

    func test_send_uploadFailure_setsIsStreamingFalse() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "test"
        mockUpload.stubbedUploadError = AppError.networkError("Upload failed")

        await sut.send()

        XCTAssertFalse(sut.isStreaming)
    }

    func test_send_uploadFailure_doesNotCallChatService() async {
        let att = makePendingAttachment()
        sut.attachments = [att]
        sut.inputText = "test"
        mockUpload.stubbedUploadError = AppError.networkError("Upload failed")

        await sut.send()

        XCTAssertEqual(mockChat.sendCallCount, 0)
    }

    // MARK: - Group G-5: Image Cache

    func test_cacheImage_storesImageInDecodedImages() {
        let img = UIImage(systemName: "photo")!
        sut.cacheImage(img, forId: "x")
        XCTAssertTrue(sut.decodedImages["x"] === img)
    }

    func test_cacheImage_doesNotClobberOtherEntries() {
        let img1 = UIImage(systemName: "photo")!
        let img2 = UIImage(systemName: "star")!
        sut.cacheImage(img1, forId: "a")
        sut.cacheImage(img2, forId: "b")
        XCTAssertTrue(sut.decodedImages["a"] === img1)
        XCTAssertTrue(sut.decodedImages["b"] === img2)
    }

    func test_cacheImage_overwritesExistingEntry() {
        let img1 = UIImage(systemName: "photo")!
        let img2 = UIImage(systemName: "star")!
        sut.cacheImage(img1, forId: "x")
        sut.cacheImage(img2, forId: "x")
        XCTAssertTrue(sut.decodedImages["x"] === img2)
    }
}
