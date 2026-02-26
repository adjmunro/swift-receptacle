import Foundation

// MARK: - WhisperProvider

/// On-device speech transcription using WhisperKit (Argmax).
///
/// Privacy-first default: audio never leaves the device.
/// Phase 8/9 implementation: integrate WhisperKit.
actor WhisperProvider: AIProvider {
    let providerId = "local-whisper"
    let displayName = "On-Device Whisper"
    let isLocal = true

    init() {}

    /// Transcribe audio data to text (primary use: voice reply pipeline)
    func transcribe(audioData: Data) async throws -> String {
        // TODO Phase 9:
        // let transcriber = try await WhisperKit(modelFolder: "openai_whisper-base")
        // let results = try await transcriber.transcribe(audioArray: audioData.toFloatArray())
        // return results.map { $0.text }.joined(separator: " ")
        throw AIProviderError.modelUnavailable(modelId: "whisper-base")
    }

    func summarise(text: String) async throws -> String {
        // TODO Phase 8: use CoreML / MLX on-device model for summarisation
        throw AIProviderError.modelUnavailable(modelId: "local-summariser")
    }

    func reframe(text: String, tone: ReplyTone) async throws -> String {
        // TODO Phase 8/9: on-device tone reframing
        throw AIProviderError.modelUnavailable(modelId: "local-reframer")
    }

    func parseEvent(from text: String) async throws -> CalendarEventDraft {
        // TODO Phase 12: on-device NL event parsing
        throw AIProviderError.modelUnavailable(modelId: "local-event-parser")
    }

    func suggestTags(for text: String) async throws -> [String] {
        // TODO Phase 10: on-device tag suggestion
        throw AIProviderError.modelUnavailable(modelId: "local-tagger")
    }
}
