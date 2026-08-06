import Foundation
import EventKit
import Observation

/// Aggregates events from three sources for display + photo logging:
/// EventKit (Apple Calendar), in-app local events (when there's no system
/// calendar), and read-only Google Calendar. New events are written to the
/// device's default calendar when possible, otherwise stored locally.
@MainActor
@Observable
final class EventStore {
    static let shared = EventStore()

    private let store = EKEventStore()

    var events: [HangoutEvent] = []
    /// Distinct recurring series found across all calendars (for the settings list).
    var recurringSeries: [RecurringSeries] = []
    var authorized = false

    // MARK: - Access

    func requestAccess() async {
        do {
            authorized = try await store.requestFullAccessToEvents()
        } catch {
            authorized = false
        }
        await refresh()
    }

    // MARK: - Reading

    func refresh(monthsBack: Int = 18, monthsForward: Int = 6) async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now
        let end = cal.date(byAdding: .month, value: monthsForward, to: now) ?? now

        var merged: [HangoutEvent] = []

        if authorized {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            merged += store.events(matching: predicate).map { ek in
                let ekID = ek.eventIdentifier ?? UUID().uuidString
                return HangoutEvent(
                    id: "\(ekID)#\(Int(ek.startDate.timeIntervalSince1970))",   // unique per occurrence
                    title: (ek.title?.isEmpty == false ? ek.title! : "Untitled"),
                    start: ek.startDate,
                    end: ek.endDate,
                    isAllDay: ek.isAllDay,
                    source: .apple,
                    seriesKey: ek.hasRecurrenceRules ? "ek-series-\(ekID)" : nil
                )
            }
        }

        merged += LocalEventStore.shared.events.filter { $0.start >= start && $0.start <= end }

        if GoogleCalendarService.shared.isConnected {
            merged += await GoogleCalendarService.shared.fetchEvents(from: start, to: end)
        }

        // Distinct recurring series (computed before hiding so hidden ones still list).
        var seriesMap: [String: RecurringSeries] = [:]
        for event in merged {
            if let key = event.seriesKey, seriesMap[key] == nil {
                seriesMap[key] = RecurringSeries(id: key, title: event.title, source: event.source)
            }
        }
        recurringSeries = seriesMap.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        let hidden = HiddenEventsStore.shared
        events = merged
            .filter { event in
                if hidden.isHidden(event.id) { return false }
                if let key = event.seriesKey, hidden.isSeriesHidden(key) { return false }
                return true
            }
            .sorted { $0.start > $1.start }   // newest first
    }

    func events(on day: Date) -> [HangoutEvent] {
        let (dayStart, dayEnd) = Self.dayBounds(day)
        return events
            .filter { $0.start < dayEnd && $0.end > dayStart }   // overlaps the day
            .sorted { $0.start < $1.start }
    }

    func hasEvents(on day: Date) -> Bool {
        let (dayStart, dayEnd) = Self.dayBounds(day)
        return events.contains { $0.start < dayEnd && $0.end > dayStart }
    }

    private static func dayBounds(_ day: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        return (start, cal.date(byAdding: .day, value: 1, to: start) ?? day)
    }

    // MARK: - Writing

    /// Writes to the device's default/first writable calendar; if none exists,
    /// saves to the in-app local store so creation always works.
    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool, recurrence: RecurrenceOption) throws {
        guard authorized, let calendar = writableCalendar() else {
            LocalEventStore.shared.create(title: title, start: start, end: end, isAllDay: isAllDay)
            return
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.calendar = calendar
        if let rule = recurrence.rule {
            event.recurrenceRules = [rule]
        }
        try store.save(event, span: .futureEvents, commit: true)
    }

    func updateEvent(id: String, title: String, start: Date, end: Date, isAllDay: Bool, recurrence: RecurrenceOption) throws {
        if id.hasPrefix("local-") {
            LocalEventStore.shared.update(id: id, title: title, start: start, end: end, isAllDay: isAllDay)
            return
        }
        guard let event = store.event(withIdentifier: Self.ekIdentifier(id)) else { throw StoreError.eventNotFound }
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.recurrenceRules = recurrence.rule.map { [$0] }   // nil clears any recurrence
        try store.save(event, span: .futureEvents, commit: true)
    }

    func deleteEvent(id: String) throws {
        if id.hasPrefix("local-") {
            LocalEventStore.shared.delete(id: id)
            return
        }
        guard let event = store.event(withIdentifier: Self.ekIdentifier(id)) else { throw StoreError.eventNotFound }
        try store.remove(event, span: .futureEvents, commit: true)
    }

    /// Strips the "#<timestamp>" occurrence suffix to recover the EventKit identifier.
    private static func ekIdentifier(_ id: String) -> String {
        id.firstIndex(of: "#").map { String(id[..<$0]) } ?? id
    }

    /// Reads an existing event's recurrence so the editor can prefill it.
    func recurrence(forID id: String) -> RecurrenceOption {
        guard !id.hasPrefix("local-"), let rule = store.event(withIdentifier: Self.ekIdentifier(id))?.recurrenceRules?.first else { return .none }
        switch rule.frequency {
        case .daily:   return .daily
        case .weekly:  return .weekly
        case .monthly: return .monthly
        default:       return .none
        }
    }

    /// The default calendar for new events, or the first one we can write to.
    private func writableCalendar() -> EKCalendar? {
        if let def = store.defaultCalendarForNewEvents, def.allowsContentModifications {
            return def
        }
        return store.calendars(for: .event).first { $0.allowsContentModifications }
    }

    enum StoreError: LocalizedError {
        case eventNotFound
        var errorDescription: String? { "That event could no longer be found." }
    }
}

/// A distinct recurring event series, for the "Recurring events" settings list.
struct RecurringSeries: Identifiable, Hashable {
    let id: String          // the series key
    let title: String
    let source: EventSource
}
