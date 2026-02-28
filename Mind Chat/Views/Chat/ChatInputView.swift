import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

private let kCharLimit = 4000

struct ChatInputView: View {

    @ObservedObject var vm: ChatViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var duration: TimeInterval = 0

    private var charCount: Int { vm.inputText.count }
    private var isOverLimit: Bool { charCount > kCharLimit }
    private var showCounter: Bool { charCount > kCharLimit * 80 / 100 }

    // MARK: - Send button state

    private enum SendState: Equatable {
        case streaming, send, mic, disabledMic
    }
    private var hasContent: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.attachments.isEmpty
    }
    private var sendState: SendState {
        if vm.isStreaming         { return .streaming }
        if hasContent             { return .send }
        if vm.voiceEnabled        { return .mic }
        return .disabledMic
    }

    var body: some View {
        VStack(spacing: 0) {

            if isRecording {
                // Recording state
                RecordingRow(duration: duration) { stopRecording() }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                // Main input container
                VStack(spacing: 0) {

                    // Attachment thumbnails
                    if !vm.attachments.isEmpty {
                        AttachmentPreview(attachments: $vm.attachments)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Text field
                    TextField("Ask anything", text: $vm.inputText, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...8)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .disabled(vm.isStreaming)

                    // Bottom toolbar
                    HStack(alignment: .center, spacing: 0) {

                        // + Attach button
                        Menu {
                            if vm.imageUploadsEnabled {
                                Button { showPhotoPicker = true } label: {
                                    Label("Photos", systemImage: "photo")
                                }
                                Button { showDocumentPicker = true } label: {
                                    Label("Files", systemImage: "doc")
                                }
                            } else {
                                Button {} label: {
                                    Label("Upgrade for file uploads", systemImage: "lock.fill")
                                }
                                .disabled(true)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.mcTextSecondary)
                                .frame(width: 36, height: 36)
                                .background(Color.mcBgHover)
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }

                        Spacer()

                        // Character counter
                        if showCounter {
                            Text("\(charCount)/\(kCharLimit)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(isOverLimit ? Color.accentRed : Color.mcTextTertiary)
                                .animation(.none, value: charCount)
                                .padding(.trailing, 10)
                        }

                        // Send / Stop / Mic
                        sendButton
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .background(Color.mcBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.mcBorderDefault, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            // Disclaimer
            Text("MindChat can make mistakes.")
                .font(.caption2)
                .foregroundStyle(Color.mcTextTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
        }
        .background(Color.mcBgPrimary)
        .animation(.mcSmooth, value: isRecording)
        .animation(.mcSmooth, value: vm.attachments.count)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            Task { await loadPhotos(items) }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                for url in urls { addFile(url: url) }
            }
        }
    }

    // MARK: - Send Button Helpers

    private var sendIcon: String {
        switch sendState {
        case .streaming:   return "stop.fill"
        case .send:        return "arrow.up"
        case .mic:         return "mic.fill"
        case .disabledMic: return "mic.slash.fill"
        }
    }

    private var sendIconSize: CGFloat {
        sendState == .streaming ? 13 : 15
    }

    private var sendBgColor: Color {
        switch sendState {
        case .streaming:   return Color.mcTextPrimary
        case .send:        return isOverLimit ? Color.mcBgActive : Color.accentColor
        case .mic:         return Color.mcBgActive
        case .disabledMic: return Color.mcBgSecondary
        }
    }

    private var sendIconColor: Color {
        switch sendState {
        case .streaming:   return Color.mcBgPrimary
        case .send:        return .white
        case .mic:         return Color.mcTextPrimary
        case .disabledMic: return Color.mcTextTertiary
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        Button {
            switch sendState {
            case .streaming:
                vm.stopStreaming()
            case .send:
                Haptics.light()
                Task { await vm.send() }
            case .mic:
                startRecording()
            case .disabledMic:
                break
            }
        } label: {
            ZStack {
                Circle()
                    .fill(sendBgColor)
                    .frame(width: 36, height: 36)
                Image(systemName: sendIcon)
                    .font(.system(size: sendIconSize, weight: .bold))
                    .foregroundStyle(sendIconColor)
                    .contentTransition(.symbolEffect(.replace, options: .speed(1.5)))
            }
            .animation(.mcSnappy, value: sendState)
        }
        .disabled(sendState == .disabledMic || (isOverLimit && sendState == .send))
    }

    // MARK: - Photos

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let name = "\(UUID().uuidString).jpg"
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? data.write(to: tmpURL)
            var att = PendingAttachment(localURL: tmpURL, name: name, kind: .image, mimeType: "image/jpeg")
            att.data = data
            vm.attachments.append(att)
        }
        selectedPhotoItems = []
    }

    // MARK: - Files

    private func addFile(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        var att = PendingAttachment(localURL: url, name: url.lastPathComponent, kind: .file, mimeType: mime)
        att.data = data
        vm.attachments.append(att)
    }

    // MARK: - Recording

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { granted in
            guard granted else { return }
            try? session.setCategory(.record, mode: .default)
            try? session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            duration    = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                duration += 0.1
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        audioRecorder?.stop()
        isRecording = false
        guard let url = audioRecorder?.url else { return }
        vm.isTranscribing = true
        Task {
            do {
                let text = try await UploadService.shared.transcribe(audioURL: url)
                vm.inputText += text
            } catch {}
            vm.isTranscribing = false
        }
    }
}

// MARK: - Recording Row

struct RecordingRow: View {
    let duration: TimeInterval
    let onStop: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 9, height: 9)
                .scaleEffect(pulse ? 1.5 : 1)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            Text(formatDuration(duration))
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            Button("Done", action: onStop)
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .spreadsheet, .presentation, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
