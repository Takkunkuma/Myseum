import Foundation
import EventKit

/// Where an event came from. Apple/EventKit and in-app local events are editable;
/// Google events are read-only (for now).
enum EventSource: Hashable {
    case apple   // EventKit (also visible in Apple Calendar)
    case local   // created in-app when no system calendar is available
    case google  // read-only Google Calendar sync
}

/// App-facing event model, mapped from an EventKit `EKEvent`, a local event, or a
/// Google event.
struct HangoutEvent: Identifiable, Hashable {
    let id: String          // unique per occurrence ("<ekID>#<ts>", "local-…", "gcal-…")
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var source: EventSource = .apple
    /// Non-nil for recurring events; shared by every occurrence in the series.
    var seriesKey: String? = nil

    var isEditable: Bool { source == .apple || source == .local }
    var isRecurring: Bool { seriesKey != nil }
}

/// Repeat options exposed in the editor, mapped to EventKit recurrence rules.
enum RecurrenceOption: String, CaseIterable, Identifiable {
    case none = "Never"
    case daily = "Every Day"
    case weekly = "Every Week"
    case monthly = "Every Month"

    var id: String { rawValue }

    var rule: EKRecurrenceRule? {
        switch self {
        case .none:    return nil
        case .daily:   return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:  return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly: return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        }
    }
}
