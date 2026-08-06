import Foundation
import Observation

/// Tracks what the user has hidden from Myseum — individual events and whole
/// recurring series (e.g. a "Chase Closing Today" reminder). Persisted in
/// UserDefaults.
@MainActor
@Observable
final class HiddenEventsStore {
    static let shared = HiddenEventsStore()

    private let idsKey = "hiddenEventIDs"
    private let seriesKey = "hiddenSeriesKeys"

    private(set) var hidden: Set<String>
    private(set) var hiddenSeries: Set<String>

    init() {
        hidden = Set(UserDefaults.standard.stringArray(forKey: idsKey) ?? [])
        hiddenSeries = Set(UserDefaults.standard.stringArray(forKey: seriesKey) ?? [])
    }

    var isEmpty: Bool { hidden.isEmpty && hiddenSeries.isEmpty }
    var count: Int { hidden.count + hiddenSeries.count }

    func isHidden(_ id: String) -> Bool { hidden.contains(id) }
    func isSeriesHidden(_ key: String) -> Bool { hiddenSeries.contains(key) }

    func hide(_ id: String) { hidden.insert(id); persist() }
    func unhide(_ id: String) { hidden.remove(id); persist() }

    func hideSeries(_ key: String) { hiddenSeries.insert(key); persist() }
    func unhideSeries(_ key: String) { hiddenSeries.remove(key); persist() }

    func clearAll() {
        hidden.removeAll()
        hiddenSeries.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(hidden), forKey: idsKey)
        UserDefaults.standard.set(Array(hiddenSeries), forKey: seriesKey)
    }
}
