import Foundation
import WhisperKit
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - WhisperProvider

/// On-device speech transcription using WhisperKit (Argmax).
///
/// Privacy-first default: audio and text never leave the device.
/// All calls are gated by `AIGate` + `AIPermissionManager`.
///
/// Model download happens automatically on first use (~150 MB for base model).
/// Progress is logged via WhisperKit's built-in logging.
public actor WhisperProvider: AIProvider {

    public let providerId   = "local-whisper"
    public let displayName  = "On-Device Whisper"
    public let isLocal      = true

    /// Model name. "openai_whisper-base" balances speed and quality on Apple Silicon.
    private let modelName = "openai_whisper-base"

    public init() {}

    // MARK: - Transcribe (primary use: voice reply pipeline)

    /// Transcribe a recorded audio file to text.
    ///
    /// Used by `VoiceReplyView` for the voice-to-reply pipeline.
    /// The audio file is the m4a/wav written by `AVAudioRecorder` during voice capture.
    ///
    /// - Note: Downloads the Whisper model on first call (~150 MB).
    public func transcribe(audioURL: URL) async throws -> String {
        let pipe = try await WhisperKit(model: modelName)
        let results: [TranscriptionResult] = try await pipe.transcribe(audioPath: audioURL.path)
        return results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - AIProvider

    /// On-device summarisation via CoreML / Apple Foundation Models (future).
    /// For now all summarise calls route to a cloud provider via AIGate.
    public func summarise(text: String) async throws -> String {
        throw AIProviderError.modelUnavailable(modelId: "local-summariser")
    }

    /// On-device tone reframing — falls back to cloud provider via AIGate.
    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        throw AIProviderError.modelUnavailable(modelId: "local-reframer")
    }

    /// On-device NL event parsing — falls back to cloud provider via AIGate.
    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        throw AIProviderError.modelUnavailable(modelId: "local-event-parser")
    }

    /// On-device tag suggestion — falls back to cloud provider via AIGate.
    public func suggestTags(for text: String) async throws -> [String] {
        throw AIProviderError.modelUnavailable(modelId: "local-tagger")
    }

    // MARK: - Helpers

    /// Returns true if the Whisper base model is available on this device.
    public static func isAvailable() -> Bool {
        WhisperKit.recommendedModels().supported.contains("openai_whisper-base")
    }
}
