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

    /// Events shown in the Events feed — a rolling window that grows as you scroll.
    var events: [HangoutEvent] = []
    /// Events for the month the Calendar tab is showing (plus neighbouring months).
    var monthEvents: [HangoutEvent] = []
    /// Lightweight index across a wide range, built lazily for Search.
    var searchIndex: [HangoutEvent] = []
    /// Distinct recurring series found across all calendars (for the settings list).
    var recurringSeries: [RecurringSeries] = []
    var authorized = false

    private(set) var hasLoadedFeed = false
    private(set) var isLoadingMore = false
    private(set) var canLoadMore = true

    /// Months of history added per page, and how far back we've loaded so far.
    private let pageMonths = 3
    private let maxBackMonths = 36
    private let forwardMonths = 3
    private var backMonthsLoaded = 0
    private var loadedMonthKey: Int?

    // MARK: - Access

    func requestAccess() async {
        do {
            authorized = try await store.requestFullAccessToEvents()
        } catch {
            authorized = false
        }
    }

    // MARK: - Feed window (Events tab)

    /// First load of the feed: the most recent `pageMonths` of history.
    func loadFeed() async {
        guard !hasLoadedFeed else { return }
        backMonthsLoaded = pageMonths
        await reloadFeedWindow()
        hasLoadedFeed = true
    }

    /// Extends the window another page further back.
    func loadMoreFeed() async {
        guard canLoadMore, !isLoadingMore, hasLoadedFeed else { return }
        isLoadingMore = true
        backMonthsLoaded = min(backMonthsLoaded + pageMonths, maxBackMonths)
        await reloadFeedWindow()
        isLoadingMore = false
    }

    /// Re-fetches whatever is currently loaded (feed window + calendar month).
    func refresh() async {
        if hasLoadedFeed { await reloadFeedWindow() }
        if let key = loadedMonthKey { await loadMonth(Self.date(fromKey: key), force: true) }
    }

    private func reloadFeedWindow() async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -backMonthsLoaded, to: now) ?? now
        let end = cal.date(byAdding: .month, value: forwardMonths, to: now) ?? now
        events = await fetchEvents(from: start, to: end)
        canLoadMore = backMonthsLoaded < maxBackMonths
    }

    // MARK: - Calendar month

    /// Loads the displayed month plus its neighbours (so month swipes are instant).
    func loadMonth(_ month: Date, force: Bool = false) async {
        let key = Self.monthKey(month)
        guard force || key != loadedMonthKey else { return }
        loadedMonthKey = key
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return }
        let start = cal.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let end = cal.date(byAdding: .month, value: 1, to: interval.end) ?? interval.end
        monthEvents = await fetchEvents(from: start, to: end)
    }

    // MARK: - Search index

    /// Titles + dates across a wide range. Cheap: no photo matching happens here.
    func loadSearchIndex() async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -maxBackMonths, to: now) ?? now
        let end = cal.date(byAdding: .month, value: forwardMonths, to: now) ?? now
        searchIndex = await fetchEvents(from: start, to: end)
    }

    // MARK: - Fetching

    /// Merges EventKit + local + Google events for a range, filtering hidden ones.
    private func fetchEvents(from start: Date, to end: Date) async -> [HangoutEvent] {
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
        if !seriesMap.isEmpty || recurringSeries.isEmpty {
            recurringSeries = seriesMap.values.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }

        let hidden = HiddenEventsStore.shared
        return merged
            .filter { event in
                if hidden.isHidden(event.id) { return false }
                if let key = event.seriesKey, hidden.isSeriesHidden(key) { return false }
                return true
            }
            .sorted { $0.start > $1.start }   // newest first
    }

    // MARK: - Day lookups (Calendar tab, backed by monthEvents)

    func events(on day: Date) -> [HangoutEvent] {
        let (dayStart, dayEnd) = Self.dayBounds(day)
        return monthEvents
            .filter { $0.start < dayEnd && $0.end > dayStart }   // overlaps the day
            .sorted { $0.start < $1.start }
    }

    func hasEvents(on day: Date) -> Bool {
        let (dayStart, dayEnd) = Self.dayBounds(day)
        return monthEvents.contains { $0.start < dayEnd && $0.end > dayStart }
    }

    private static func monthKey(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.year, from: date) * 100 + cal.component(.month, from: date)
    }

    private static func date(fromKey key: Int) -> Date {
        var components = DateComponents()
        components.year = key / 100
        components.month = key % 100
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
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
