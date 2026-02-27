import Foundation
import EventKit
import Receptacle

// MARK: - CalendarSource Protocol

/// Surfaces EventKit calendar events and reminders as `Item` entries
/// in the relevant entity's feed.
protocol CalendarSource: Identifiable, Sendable {
    var calendarId: String { get }
    var displayName: String { get }

    func fetchEvents(in range: DateInterval) async throws -> [CalendarEvent]
    func createEvent(_ draft: CalendarEventDraft) async throws -> CalendarEvent
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(id: String) async throws
}

// MARK: - EventKitSource

/// Concrete CalendarSource backed by EventKit.
///
/// Pass `calendarId: "__all__"` to surface events from all calendars.
/// All methods request access before use and throw `CalendarError.accessDenied` if denied.
actor EventKitSource: CalendarSource {
    let calendarId: String
    let displayName: String

    nonisolated var id: String { calendarId }

    private let store = EKEventStore()

    init(calendarId: String, displayName: String) {
        self.calendarId = calendarId
        self.displayName = displayName
    }

    // MARK: - Access

    private func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }
    }

    // MARK: - Fetch

    func fetchEvents(in range: DateInterval) async throws -> [CalendarEvent] {
        try await requestAccess()
        let calendars: [EKCalendar]? = calendarId == "__all__"
            ? nil
            : store.calendars(for: .event).filter { $0.calendarIdentifier == calendarId }
        let pred = store.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: calendars
        )
        return store.events(matching: pred).map(mapEvent)
    }

    // MARK: - Create

    func createEvent(_ draft: CalendarEventDraft) async throws -> CalendarEvent {
        try await requestAccess()
        let ek = EKEvent(eventStore: store)
        ek.title = draft.title
        ek.startDate = draft.startDate
        ek.endDate = draft.endDate
        ek.location = draft.location
        ek.isAllDay = draft.isAllDay
        ek.notes = draft.notes

        let calList = store.calendars(for: .event).filter { $0.calendarIdentifier == calendarId }
        guard let calendar = calList.first ?? store.defaultCalendarForNewEvents else {
            throw CalendarError.saveFailed(reason: "No writable calendar available")
        }
        ek.calendar = calendar

        do {
            try store.save(ek, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(reason: error.localizedDescription)
        }
        return mapEvent(ek)
    }

    // MARK: - Update

    func updateEvent(_ event: CalendarEvent) async throws {
        try await requestAccess()
        guard let ek = store.event(withIdentifier: event.id) else {
            throw CalendarError.eventNotFound(id: event.id)
        }
        ek.title = event.title
        ek.startDate = event.date
        ek.endDate = event.endDate
        ek.location = event.location
        ek.isAllDay = event.isAllDay
        ek.notes = event.notes
        do {
            try store.save(ek, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Delete

    func deleteEvent(id: String) async throws {
        try await requestAccess()
        guard let ek = store.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound(id: id)
        }
        do {
            try store.remove(ek, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Mapping

    private func mapEvent(_ ek: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: ek.eventIdentifier ?? UUID().uuidString,
            entityId: calendarId,
            sourceId: calendarId,
            date: ek.startDate ?? Date(),
            summary: ek.title ?? "(No title)",
            title: ek.title ?? "(No title)",
            endDate: ek.endDate ?? Date().addingTimeInterval(3600),
            location: ek.location,
            attendees: ek.attendees?.compactMap { $0.url.absoluteString } ?? [],
            isAllDay: ek.isAllDay,
            notes: ek.notes
        )
    }
}
