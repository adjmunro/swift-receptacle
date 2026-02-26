import Foundation
import Receptacle  // AIProvider, AIProviderError, ReplyTone, CalendarEventDraft

// MARK: - WhisperProvider

/// On-device speech transcription and AI using WhisperKit (Argmax) + CoreML.
///
/// Privacy-first default: audio and text never leave the device.
/// All calls are gated by `AIGate` + `AIPermissionManager`.
///
/// ## WhisperKit integration (requires Xcode + package linked):
///
/// ### Transcribe audio file:
/// ```swift
/// import WhisperKit
///
/// public func transcribe(audioURL: URL) async throws -> String {
///     let pipe = try await WhisperKit(model: "openai_whisper-base")
///     let results = try await pipe.transcribe(audioPath: audioURL.path)
///     return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
/// }
/// ```
///
/// ### Transcribe raw audio data:
/// ```swift
/// // WhisperKit accepts a file path; write data to a temp file first:
/// let tmp = FileManager.default.temporaryDirectory
///     .appendingPathComponent(UUID().uuidString + ".m4a")
/// try data.write(to: tmp)
/// defer { try? FileManager.default.removeItem(at: tmp) }
/// let pipe = try await WhisperKit(model: "openai_whisper-base")
/// let results = try await pipe.transcribe(audioPath: tmp.path)
/// return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
/// ```
///
/// ### Model selection:
/// ```swift
/// // Available models (smallest → largest, speed ↔ quality tradeoff):
/// // "openai_whisper-tiny"   – fastest, lowest quality
/// // "openai_whisper-base"   – good balance (default)
/// // "openai_whisper-small"  – better accuracy
/// // "openai_whisper-medium" – near-cloud quality, slower
/// // "openai_whisper-large-v3" – highest quality, ~3 GB model download
/// let pipe = try await WhisperKit(model: "openai_whisper-base")
/// ```
///
/// ### Summarise (on-device via CoreML / MLX — future):
/// ```swift
/// // Phase 8+: use a CoreML-converted model (e.g. via mlx-lm or Apple's
/// // Foundation Models framework once stable) for on-device summarisation.
/// // For now falls back to modelUnavailable; cloud providers are used instead.
/// ```
public actor WhisperProvider: AIProvider {

    public let providerId   = "local-whisper"
    public let displayName  = "On-Device Whisper"
    public let isLocal      = true

    public init() {}

    // MARK: - Transcribe (primary use: voice reply pipeline)

    /// Transcribe a recorded audio file to text.
    ///
    /// Used by `VoiceReplyView` (Phase 9). The audio file is the m4a/wav
    /// written by `AVAudioRecorder` during voice capture.
    public func transcribe(audioURL: URL) async throws -> String {
        // Uncomment when WhisperKit is linked in Xcode target (Phase 9):
        //
        // import WhisperKit
        // let pipe = try await WhisperKit(model: "openai_whisper-base")
        // let results = try await pipe.transcribe(audioPath: audioURL.path)
        // return results.map { $0.text }.joined(separator: " ")
        //     .trimmingCharacters(in: .whitespaces)
        throw AIProviderError.modelUnavailable(modelId: "whisper-base")
    }

    // MARK: - AIProvider

    public func summarise(text: String) async throws -> String {
        // On-device summarisation via CoreML / Apple Foundation Models (future).
        // For now all summarise calls route to a cloud provider via AIGate.
        throw AIProviderError.modelUnavailable(modelId: "local-summariser")
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        // On-device tone reframing (Phase 9+).
        throw AIProviderError.modelUnavailable(modelId: "local-reframer")
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        // On-device NL event parsing (Phase 12).
        throw AIProviderError.modelUnavailable(modelId: "local-event-parser")
    }

    public func suggestTags(for text: String) async throws -> [String] {
        // On-device tag suggestion (Phase 10).
        throw AIProviderError.modelUnavailable(modelId: "local-tagger")
    }

    // MARK: - Helpers

    public static func isAvailable() -> Bool {
        // Check if the WhisperKit model has been downloaded.
        // Uncomment when WhisperKit is linked:
        //
        // return WhisperKit.recommendedModels().supported.contains("openai_whisper-base")
        return false
    }
}
