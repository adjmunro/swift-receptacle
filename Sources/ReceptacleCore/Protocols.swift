import Foundation

// MARK: - Item Protocol

/// Base type for all items from any source.
/// Email messages, RSS articles, IM messages, and calendar events all conform.
public protocol Item: Identifiable, Sendable {
    var id: String { get }
    var entityId: String { get }
    var sourceId: String { get }
    var date: Date { get }
    var summary: String { get }
}

// MARK: - Reply

public struct Reply: Sendable {
    public var itemId: String
    public var subject: String
    public var body: String
    public var toAddress: String
    public var ccAddresses: [String]

    public init(itemId: String, subject: String = "", body: String, toAddress: String, ccAddresses: [String] = []) {
        self.itemId = itemId
        self.subject = subject
        self.body = body
        self.toAddress = toAddress
        self.ccAddresses = ccAddresses
    }
}

// MARK: - MessageSource Protocol

public protocol MessageSource: Identifiable, Sendable {
    var sourceId: String { get }
    var displayName: String { get }
    var sourceType: SourceType { get }

    func fetchItems(since: Date?) async throws -> [any Item]
    func send(_ reply: Reply) async throws
    func archive(_ item: any Item) async throws
    func delete(_ item: any Item) async throws
    func markRead(_ item: any Item, read: Bool) async throws
}

// MARK: - CalendarEvent & Draft

public struct CalendarEvent: Item, Sendable {
    public var id: String
    public var entityId: String
    public var sourceId: String
    public var date: Date
    public var summary: String
    public var title: String
    public var endDate: Date
    public var location: String?
    public var attendees: [String]
    public var isAllDay: Bool
    public var notes: String?
}

public struct CalendarEventDraft: Sendable {
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var location: String?
    public var attendees: [String]
    public var isAllDay: Bool
    public var notes: String?

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        attendees: [String] = [],
        isAllDay: Bool = false,
        notes: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.attendees = attendees
        self.isAllDay = isAllDay
        self.notes = notes
    }
}

// MARK: - AIProvider Protocol

public protocol AIProvider: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var isLocal: Bool { get }

    func summarise(text: String) async throws -> String
    func reframe(text: String, tone: ReplyTone) async throws -> String
    func parseEvent(from text: String) async throws -> CalendarEventDraft
    func suggestTags(for text: String) async throws -> [String]
}

// MARK: - Error types

public enum MessageSourceError: Error, Sendable {
    case notAuthenticated
    case networkUnavailable
    case invalidConfiguration(String)
    case itemNotFound(id: String)
    case sendFailed(reason: String)
    case unsupportedOperation
}

public enum AIProviderError: Error, Sendable {
    case notConfigured
    case rateLimited
    case permissionDenied
    case networkError(reason: String)
    case modelUnavailable(modelId: String)
    case responseInvalid
    case decodingFailed
}

public enum CalendarError: Error, Sendable {
    case accessDenied
    case eventNotFound(id: String)
    case saveFailed(reason: String)
    case unsupportedOperation
}
