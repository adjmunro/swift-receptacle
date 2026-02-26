import SwiftUI

/// Voice-to-reply pipeline:
/// Record → WhisperKit transcribe → AI reframe → instruction mode → editable draft → send
///
/// Draft state is a stack (`[DraftState]`). Every AI operation pushes a new state.
/// "Undo" pops back. Shown as a revision timeline strip above the draft editor.
struct VoiceReplyView: View {
    let item: any Item
    let entity: Entity
    var onSend: ((Reply) -> Void)?

    @State private var isRecording = false
    @State private var draftStack: [DraftState] = []
    @State private var instructionText = ""

    var currentDraft: String {
        draftStack.last?.body ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Revision timeline strip
            if draftStack.count > 1 {
                RevisionStripView(draftStack: draftStack) { index in
                    // Pop back to revision index
                    draftStack = Array(draftStack.prefix(index + 1))
                }
                .frame(height: 44)
                Divider()
            }

            // Draft editor
            TextEditor(text: Binding(
                get: { currentDraft },
                set: { newValue in
                    // Push manual edit as new state
                    draftStack.append(DraftState(body: newValue, source: .manualEdit))
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
                    Task { await applyInstruction() }
                }
                .disabled(instructionText.isEmpty || currentDraft.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Recording + send controls
            HStack {
                Button {
                    isRecording.toggle()
                    if !isRecording { Task { await processRecording() } }
                } label: {
                    Label(isRecording ? "Stop" : "Record", systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                }
                .tint(isRecording ? .red : .accentColor)

                Spacer()

                Button("Send") {
                    guard !currentDraft.isEmpty else { return }
                    let reply = Reply(
                        itemId: item.id,
                        body: currentDraft,
                        toAddress: ""   // resolved by caller
                    )
                    onSend?(reply)
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentDraft.isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Pipeline Steps

    private func processRecording() async {
        // TODO Phase 9:
        // 1. Stop AVAudioRecorder
        // 2. Pass audio data to WhisperProvider.transcribe()
        // 3. Push transcription as DraftState(.transcribed)
        // 4. Run AI reframe with entity.replyTone → push DraftState(.aiReframed)
    }

    private func applyInstruction() async {
        // TODO Phase 9:
        // Pass currentDraft + instructionText as second prompt turn to AI provider
        // Push result as DraftState(.instruction(instructionText))
        instructionText = ""
    }
}

// MARK: - Draft State

struct DraftState: Sendable {
    enum Source: Sendable {
        case transcribed
        case aiReframed
        case instruction(String)
        case manualEdit
    }
    var body: String
    var source: Source
    var timestamp = Date()
}

// MARK: - Revision Strip

struct RevisionStripView: View {
    let draftStack: [DraftState]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(draftStack.indices, id: \.self) { index in
                    Button {
                        onSelect(index)
                    } label: {
                        Text(draftStack[index].source.label)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                index == draftStack.count - 1 ?
                                Color.accentColor : Color.secondary.opacity(0.2)
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

extension DraftState.Source {
    var label: String {
        switch self {
        case .transcribed: "Transcribed"
        case .aiReframed: "AI Reframed"
        case .instruction(let s): "Instruction: \(s.prefix(20))"
        case .manualEdit: "Manual edit"
        }
    }
}
