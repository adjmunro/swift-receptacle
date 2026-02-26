import Foundation

// MARK: - MockAIProvider

/// In-memory `AIProvider` for unit tests and `ReceptacleVerify`.
///
/// Tracks every call and returns configurable stub values.
/// Supports optional error injection to test failure paths.
///
/// Usage:
/// ```swift
/// let provider = MockAIProvider()
/// provider.summariseResult = "Key points: ..."
///
/// let summary = try await provider.summarise(text: "Long email...")
/// assert(summary == "Key points: ...")
/// assert(await provider.summariseCalled == 1)
/// ```
public actor MockAIProvider: AIProvider {

    // MARK: Identity

    public let providerId: String
    public let displayName: String
    public let isLocal: Bool

    // MARK: Configurable responses

    public var summariseResult:   String              = "Mock summary."
    public var reframeResult:     String              = "Mock reframe."
    public var parseEventResult:  CalendarEventDraft  = CalendarEventDraft(
        title: "Mock Event",
        startDate: Date(timeIntervalSinceNow: 86_400),
        endDate:   Date(timeIntervalSinceNow: 90_000)
    )
    public var suggestTagsResult: [String]            = ["swift", "ios", "productivity"]

    // MARK: Error injection (nil = no error)

    public var shouldThrow: AIProviderError? = nil

    // MARK: Call tracking

    public private(set) var summariseCalled:   Int = 0
    public private(set) var reframeCalled:     Int = 0
    public private(set) var parseEventCalled:  Int = 0
    public private(set) var suggestTagsCalled: Int = 0

    public private(set) var lastSummariseInput:  String? = nil
    public private(set) var lastReframeInput:    String? = nil
    public private(set) var lastReframeTone:     ReplyTone? = nil

    // MARK: Init

    public init(
        providerId: String = "mock-ai",
        displayName: String = "Mock AI Provider",
        isLocal: Bool = true
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.isLocal = isLocal
    }

    // MARK: AIProvider

    public func summarise(text: String) async throws -> String {
        if let err = shouldThrow { throw err }
        summariseCalled += 1
        lastSummariseInput = text
        return summariseResult
    }

    public func reframe(text: String, tone: ReplyTone) async throws -> String {
        if let err = shouldThrow { throw err }
        reframeCalled += 1
        lastReframeInput = text
        lastReframeTone = tone
        return reframeResult
    }

    public func parseEvent(from text: String) async throws -> CalendarEventDraft {
        if let err = shouldThrow { throw err }
        parseEventCalled += 1
        return parseEventResult
    }

    public func suggestTags(for text: String) async throws -> [String] {
        if let err = shouldThrow { throw err }
        suggestTagsCalled += 1
        return suggestTagsResult
    }

    // MARK: - Configuration setters

    /// Set the result returned by `summarise(text:)`.
    public func set(summariseResult: String) { self.summariseResult = summariseResult }
    /// Set the result returned by `reframe(text:tone:)`.
    public func set(reframeResult: String)   { self.reframeResult = reframeResult }
    /// Set the result returned by `suggestTags(for:)`.
    public func set(suggestTagsResult: [String]) { self.suggestTagsResult = suggestTagsResult }
    /// Inject an error to be thrown by every AIProvider method.
    public func set(shouldThrow: AIProviderError?) { self.shouldThrow = shouldThrow }

    // MARK: Reset

    /// Resets all call counters (useful for multi-step tests).
    public func resetCallCounts() {
        summariseCalled   = 0
        reframeCalled     = 0
        parseEventCalled  = 0
        suggestTagsCalled = 0
        lastSummariseInput = nil
        lastReframeInput   = nil
        lastReframeTone    = nil
    }
}
