// MARK: - VoiceReplyPipeline

/// Coordinates the voice-to-reply pipeline: transcript → AI reframe → instruction mode.
///
/// All AI calls are gated through `AIGate`. Inject `MockAIProvider` in tests.
///
/// The pipeline is stateless — it produces `DraftState` values that the caller
/// accumulates in a `DraftStateStack`. This keeps the pipeline purely functional
/// and easily testable.
///
/// ## Usage:
/// ```swift
/// let pipeline = VoiceReplyPipeline(
///     aiProvider: claudeProvider,
///     gate: AIGate.shared,
///     providerId: "claude"
/// )
///
/// // After WhisperKit transcription:
/// let reframed = try await pipeline.reframe(transcript: transcript, tone: entity.replyTone)
/// draftStack.push(reframed)
///
/// // After user enters instruction:
/// let revised = try await pipeline.applyInstruction("make it more concise", to: draftStack.current!.text)
/// draftStack.push(revised)
/// ```
public actor VoiceReplyPipeline {

    private let aiProvider: any AIProvider
    private let gate: AIGate
    private let providerId: String

    public init(
        aiProvider: any AIProvider,
        gate: AIGate,
        providerId: String
    ) {
        self.aiProvider = aiProvider
        self.gate = gate
        self.providerId = providerId
    }

    // MARK: - Pipeline Steps

    /// Reframe a transcribed voice input using the entity's preferred reply tone.
    ///
    /// - Parameters:
    ///   - transcript: Raw transcription from WhisperKit.
    ///   - tone: The entity's configured `ReplyTone`.
    /// - Returns: A `DraftState` containing the reframed text.
    /// - Throws: `AIProviderError.permissionDenied` if the user has blocked reframeTone.
    public func reframe(transcript: String, tone: ReplyTone) async throws -> DraftState {
        let provider = aiProvider   // local let — Sendable, safe to capture
        let reframed = try await gate.perform(
            providerId: providerId,
            feature: .reframeTone
        ) {
            try await provider.reframe(text: transcript, tone: tone)
        }
        return DraftState(text: reframed, changeDescription: "AI reframed")
    }

    /// Apply a user instruction to revise the current draft.
    ///
    /// Constructs a combined prompt embedding the instruction and the existing draft,
    /// then asks the AI to return a revised version following the instruction.
    ///
    /// - Parameters:
    ///   - instruction: Free-text instruction (e.g. "make it more concise").
    ///   - currentDraft: The draft text to revise.
    /// - Returns: A `DraftState` with the revised text and a description capturing the instruction.
    /// - Throws: `AIProviderError.permissionDenied` if the user has blocked reframeTone.
    public func applyInstruction(_ instruction: String, to currentDraft: String) async throws -> DraftState {
        let prompt = """
            Revise the following draft according to the instruction. \
            Return only the revised draft text, no commentary.

            Instruction: \(instruction)

            Current draft:
            \(currentDraft)
            """
        let provider = aiProvider
        let revised = try await gate.perform(
            providerId: providerId,
            feature: .reframeTone
        ) {
            try await provider.reframe(
                text: prompt,
                tone: .custom(prompt: "Follow the instruction exactly.")
            )
        }
        return DraftState(text: revised, changeDescription: "Instruction: \(instruction)")
    }
}
