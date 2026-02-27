import SwiftUI
import AVFoundation
import Receptacle  // DraftState, DraftStateStack, VoiceReplyPipeline, AIProvider, ReplyTone

// MARK: - VoiceReplyView

/// Voice-to-reply pipeline view.
///
/// Pipeline: Record (AVAudioRecorder) → Transcribe (WhisperKit) → AI Reframe → Instruction Mode → Send
///
/// Draft state is managed by `DraftStateStack` from ReceptacleCore. Every AI operation
/// pushes a new `DraftState`. Undo pops back. The revision strip shows full history.
struct VoiceReplyView: View {

    let item: any Item
    let replyTone: ReplyTone
    let pipeline: VoiceReplyPipeline
    var onSend: ((Reply) -> Void)?

    @State private var isRecording = false
    @State private var draftStack = DraftStateStack()
    @State private var instructionText = ""
    @State private var isPipelineRunning = false
    @State private var errorMessage: String? = nil

    /// Holds the active AVAudioRecorder while recording is in progress.
    @State private var recorder: AVAudioRecorder? = nil

    var currentText: String { draftStack.current?.text ?? "" }

    var body: some View {
        VStack(spacing: 0) {

            // Revision timeline strip
            if draftStack.count > 1 {
                RevisionStripView(stack: draftStack) { index in
                    draftStack.jump(to: index)
                }
                .frame(height: 44)
                Divider()
            }

            // Error banner
            if let errorMessage {
                HStack {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") { self.errorMessage = nil }
                        .font(.caption2)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.08))
                Divider()
            }

            // Draft editor
            TextEditor(text: Binding(
                get: { currentText },
                set: { newValue in
                    draftStack.push(text: newValue, description: "Manual edit")
                }
            ))
            .font(.body)
            .padding()

            Divider()

            // Instruction input
            HStack {
                TextField("Instruction (e.g. make it more formal)", text: $instructionText)
                    .textFieldStyle(.roundedBorder)
                Button("Refine") {
                    Task { await runInstruction() }
                }
                .disabled(instructionText.isEmpty || currentText.isEmpty || isPipelineRunning)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Recording + send controls
            HStack {
                Button {
                    Task { await toggleRecording() }
                } label: {
                    Label(
                        isRecording ? "Stop" : "Record",
                        systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                }
                .tint(isRecording ? .red : .accentColor)
                .disabled(isPipelineRunning)

                Spacer()

                if isPipelineRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Send") {
                    guard !currentText.isEmpty else { return }
                    onSend?(Reply(
                        itemId: item.id,
                        body: currentText,
                        toAddress: ""   // caller resolves effective reply-to address
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentText.isEmpty || isPipelineRunning)
            }
            .padding()
        }
    }

    // MARK: - Pipeline Steps

    private func toggleRecording() async {
        if isRecording {
            isRecording = false
            recorder?.stop()
            await processRecording()
        } else {
            do {
#if os(iOS)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
#endif
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 16000,      // WhisperKit expects 16 kHz
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                let r = try AVAudioRecorder(url: url, settings: settings)
                r.record()
                recorder = r
                isRecording = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func processRecording() async {
        guard let r = recorder else { return }
        let audioURL = r.url
        recorder = nil

        isPipelineRunning = true
        defer { isPipelineRunning = false }

        do {
            let whisper = WhisperProvider()
            let transcript = try await whisper.transcribe(audioURL: audioURL)
            draftStack.push(text: transcript, description: "Transcribed")

            let reframed = try await pipeline.reframe(transcript: transcript, tone: replyTone)
            draftStack.push(reframed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runInstruction() async {
        let instruction = instructionText
        let current = currentText
        guard !instruction.isEmpty, !current.isEmpty else { return }

        instructionText = ""
        isPipelineRunning = true
        defer { isPipelineRunning = false }

        do {
            let revised = try await pipeline.applyInstruction(instruction, to: current)
            draftStack.push(revised)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - RevisionStripView

/// Horizontal scrollable strip showing draft revision history.
///
/// The current (latest) revision is highlighted. Tapping any revision
/// truncates the stack to that point.
struct RevisionStripView: View {
    let stack: DraftStateStack
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stack.states.indices, id: \.self) { index in
                    Button {
                        onSelect(index)
                    } label: {
                        Text(stack.states[index].changeDescription ?? "Edit")
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                index == stack.count - 1
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.2)
                            )
                            .foregroundStyle(
                                index == stack.count - 1 ? Color.white : Color.primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
