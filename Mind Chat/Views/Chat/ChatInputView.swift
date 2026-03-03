import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

private let kCharLimit = 10000

struct ChatInputView: View {

    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @FocusState private var isInputFocused: Bool
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var showTopicPicker = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var duration: TimeInterval = 0
    @State private var dismissedRecommendationIntent: QueryIntent?
    @State private var showPersonaPicker = false
    @State private var showExpandedComposer = false

    private var charCount: Int { vm.inputText.count }

    private var visibleRecommendation: ModelRecommendation? {
        guard let rec = vm.modelRecommendation else { return nil }
        if dismissedRecommendationIntent == rec.intent { return nil }
        return rec
    }
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
            } else if vm.isTranscribing {
                // Transcribing state
                TranscribingRow()
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else if vm.isUploading {
                // Uploading state
                UploadingRow(progress: vm.uploadProgress)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                VStack(spacing: 0) {

                    // Model recommendation banner — floats above the rounded input box
                    if let rec = visibleRecommendation {
                        ModelRecommendationBanner(
                            recommendation: rec,
                            onUse: {
                                Haptics.light()
                                EventBus.shared.publish(.modelChanged(provider: rec.provider, model: rec.modelId))
                                vm.modelRecommendation = nil
                            },
                            onDismiss: { dismissedRecommendationIntent = rec.intent }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }

                    // Main input container
                    VStack(spacing: 0) {

                        personaChipRow

                        // Attachment thumbnails
                        if !vm.attachments.isEmpty {
                            AttachmentPreview(attachments: $vm.attachments)
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Topic focus chip
                        if let focus = vm.topicFocus {
                            HStack {
                                TopicFocusChip(focus: focus) {
                                    vm.clearTopicFocus()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                        }

                        // Text field
                        TextField(
                            vm.topicFocus != nil ? "Ask about \(vm.topicFocus!.name)..." : "Ask anything",
                            text: $vm.inputText,
                            axis: .vertical
                        )
                            .font(.body)
                            .lineLimit(1...8)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .focused($isInputFocused)
                            .disabled(vm.isStreaming)

                        // Bottom toolbar
                        HStack(alignment: .center, spacing: 0) {

                            // + Attach button
                            Menu {
                                Button { showTopicPicker = true } label: {
                                    Label("Focus on Topic", systemImage: "brain.head.profile")
                                }

                                Divider()

                                if vm.imageUploadsEnabled {
                                    Button { showCamera = true } label: {
                                        Label("Take Photo", systemImage: "camera")
                                    }
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
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.mcTextSecondary)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Circle())
                            }

                            Spacer()

                            // Character counter
                            if showCounter {
                                Text("\(charCount)/\(kCharLimit)")
                                    .font(.caption.monospacedDigit())
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
                            .stroke(Color.mcBorderDefault, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, visibleRecommendation != nil ? 4 : 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(Color.mcBgPrimary)
        .animation(.mcSmooth, value: isRecording)
        .animation(.mcSmooth, value: vm.isTranscribing)
        .animation(.mcSmooth, value: vm.isUploading)
        .animation(.mcSmooth, value: vm.attachments.count)
        .onChange(of: vm.isStreaming) { _, _ in
            // Dismiss keyboard on any streaming state change:
            // • on start: user sent, hide keyboard immediately
            // • on end: TextField re-enables, but focus is already false so keyboard won't reappear
            isInputFocused = false
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            Task { await loadPhotos(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                addCameraPhoto(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                for url in urls { addFile(url: url) }
            }
        }
        .sheet(isPresented: $showTopicPicker) {
            TopicPickerSheet(vm: vm)
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaSelectorSheet(vm: vm)
        }
        .sheet(isPresented: $showExpandedComposer) {
            ExpandedComposerSheet(
                text: $vm.inputText,
                placeholder: vm.topicFocus != nil ? "Ask about \(vm.topicFocus!.name)..." : "Ask anything",
                onSend: { Task { await vm.send() } }
            )
        }
        .animation(.mcSmooth, value: vm.topicFocus?.id)
        .animation(.mcGentle, value: visibleRecommendation?.modelId)
        .onChange(of: vm.modelRecommendation?.intent) { _, new in
            if let new, new != dismissedRecommendationIntent { dismissedRecommendationIntent = nil }
        }
    }

    // MARK: - Persona Chip Row

    private var personaChipRow: some View {
        HStack {
            Button { showPersonaPicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: vm.persona.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(vm.persona.color)
                    Text(vm.persona.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(vm.persona.color.opacity(0.10))
                .clipShape(Capsule())
                .animation(.mcSnappy, value: vm.persona)
            }
            .buttonStyle(.plain)

            Spacer()

            if !vm.inputText.isEmpty {
                Button { showExpandedComposer = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mcTextSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .animation(.mcSnappy, value: vm.inputText.isEmpty)
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
        case .send:        return isOverLimit ? Color.mcBgActive : Color.mcTextPrimary
        case .mic:         return Color.mcBgActive
        case .disabledMic: return Color.mcBgSecondary
        }
    }

    private var sendIconColor: Color {
        switch sendState {
        case .streaming:   return Color.mcBgPrimary
        case .send:        return Color.mcBgPrimary
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
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }

            // Transcode HEIC → JPEG. This is CPU-heavy so run it off the main thread,
            // but we must hop back to @MainActor before touching vm.attachments.
            let jpegData: Data = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = UIImage(data: raw).flatMap { $0.jpegData(compressionQuality: 0.85) } ?? raw
                    continuation.resume(returning: result)
                }
            }

            let name = "\(UUID().uuidString).jpg"
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? jpegData.write(to: tmpURL)
            var att = PendingAttachment(localURL: tmpURL, name: name, kind: .image, mimeType: "image/jpeg")
            att.data = jpegData
            // Back on @MainActor here (loadPhotos is called from .onChange which is on main)
            vm.attachments.append(att)
        }
        selectedPhotoItems = []
    }

    // MARK: - Camera

    private func addCameraPhoto(_ image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
        let name = "\(UUID().uuidString).jpg"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? jpegData.write(to: tmpURL)
        var att = PendingAttachment(localURL: tmpURL, name: name, kind: .image, mimeType: "image/jpeg")
        att.data = jpegData
        vm.attachments.append(att)
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
        print("[Voice] startRecording() called")
        let session = AVAudioSession.sharedInstance()
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    print("[Voice] Microphone permission denied")
                    return
                }
                print("[Voice] Microphone permission granted")
                do {
                    try session.setCategory(.record, mode: .default)
                    try session.setActive(true)
                    print("[Voice] Audio session activated")
                } catch {
                    print("[Voice] Audio session setup failed: \(error)")
                    return
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
                print("[Voice] Recording to: \(url.path)")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
                    print("[Voice] Failed to create AVAudioRecorder")
                    return
                }
                audioRecorder = recorder
                let started = audioRecorder?.record() ?? false
                print("[Voice] Recording started: \(started)")
                isRecording = true
                duration    = 0
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    duration += 0.1
                }
            }
        }
    }

    private func stopRecording() {
        print("[Voice] stopRecording() called, duration=\(duration)")
        recordingTimer?.invalidate()
        audioRecorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard let url = audioRecorder?.url else {
            print("[Voice] No audio URL from recorder — aborting")
            return
        }
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("[Voice] Audio file exists=\(fileExists), size=\(fileSize) bytes, path=\(url.path)")
        vm.isTranscribing = true
        print("[Voice] Starting transcription request…")
        Task {
            do {
                let text = try await UploadService.shared.transcribe(audioURL: url)
                print("[Voice] Transcription succeeded, text length=\(text.count): \"\(text.prefix(100))\"")
                if text.isEmpty {
                    print("[Voice] WARNING: Server returned empty transcription text")
                }
                vm.inputText += text
                print("[Voice] inputText after append (\(vm.inputText.count) chars): \"\(vm.inputText.prefix(100))\"")
            } catch {
                print("[Voice] Transcription FAILED: \(error)")
                vm.errorMessage = "Transcription failed. Please try again."
            }
            vm.isTranscribing = false
            print("[Voice] isTranscribing set to false")
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
                .foregroundStyle(Color.mcTextPrimary)
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

// MARK: - Transcribing Row

struct TranscribingRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.85)

            Text("Transcribing…")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Uploading Row

struct UploadingRow: View {
    let progress: (current: Int, total: Int)?

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.85)

            if let p = progress, p.total > 1 {
                Text("Uploading \(p.current) of \(p.total)…")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } else {
                Text("Uploading…")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Model Recommendation Banner

private struct ModelRecommendationBanner: View {
    let recommendation: ModelRecommendation
    let onUse: () -> Void
    let onDismiss: () -> Void

    private var providerColor: Color {
        switch recommendation.provider {
        case .openai: return .providerOpenAI
        case .claude: return .providerClaude
        case .google: return .providerGoogle
        case .xai:    return .providerXAI
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Intent icon in a tinted circle
            Image(systemName: recommendation.intent.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(providerColor)
                .frame(width: 26, height: 26)
                .background(providerColor.opacity(0.12))
                .clipShape(Circle())

            // Label
            Text("Try **\(recommendation.modelLabel)** for \(recommendation.intent.description)")
                .font(.footnote)
                .foregroundStyle(Color.mcTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            // "Use" button
            Button(action: onUse) {
                Text("Use")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(providerColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mcTextTertiary)
                    .frame(width: 20, height: 20)
                    .background(Color.mcBgActive)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(providerColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(providerColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, dismiss: dismiss) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction
        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
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
