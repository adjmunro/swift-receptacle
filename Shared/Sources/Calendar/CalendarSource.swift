import Foundation

// MARK: - CalendarSource Protocol

/// Surfaces EventKit calendar events and reminders as `Item` entries
/// in the relevant entity's feed.
///
/// Phase 12 implementation: integrate EventKit.
protocol CalendarSource: Identifiable, Sendable {
    var calendarId: String { get }
    var displayName: String { get }

    func fetchEvents(in range: DateInterval) async throws -> [CalendarEvent]
    func createEvent(_ draft: CalendarEventDraft) async throws -> CalendarEvent
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(id: String) async throws
}

// MARK: - CalendarEvent (Item)

/// An EventKit event surfaced as an inbox item.
struct CalendarEvent: Item, Sendable {
    var id: String
    var entityId: String
    var sourceId: String
    var date: Date
    var summary: String

    var title: String
    var endDate: Date
    var location: String?
    var attendees: [String]
    var isAllDay: Bool
    var notes: String?
}

// MARK: - CalendarEventDraft

/// Intermediate representation used before committing to EventKit.
/// Created by AI natural-language parsing; shown in confirmation sheet.
struct CalendarEventDraft: Sendable {
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var attendees: [String]
    var isAllDay: Bool
    var notes: String?
}

// MARK: - EventKitSource (stub)

/// Concrete CalendarSource backed by EventKit.
actor EventKitSource: CalendarSource {
    let calendarId: String
    let displayName: String

    var id: String { calendarId }

    init(calendarId: String, displayName: String) {
        self.calendarId = calendarId
        self.displayName = displayName
    }

    func fetchEvents(in range: DateInterval) async throws -> [CalendarEvent] {
        // TODO Phase 12: use EventStore to fetch EKEvent within range
        return []
    }

    func createEvent(_ draft: CalendarEventDraft) async throws -> CalendarEvent {
        // TODO Phase 12: create EKEvent and save to EventStore
        throw CalendarError.unsupportedOperation
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        throw CalendarError.unsupportedOperation
    }

    func deleteEvent(id: String) async throws {
        throw CalendarError.unsupportedOperation
    }
}

enum CalendarError: Error, Sendable {
    case accessDenied
    case eventNotFound(id: String)
    case saveFailed(reason: String)
    case unsupportedOperation
}
