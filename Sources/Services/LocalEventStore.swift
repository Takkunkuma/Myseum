import Foundation
import Observation

/// In-app event storage, used when the device has no writable system calendar.
/// Persists app-created events to a JSON file so they survive relaunches.
@MainActor
@Observable
final class LocalEventStore {
    static let shared = LocalEventStore()

    private(set) var events: [HangoutEvent] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("local_events.json")
    }()

    init() { load() }

    func create(title: String, start: Date, end: Date, isAllDay: Bool) {
        events.append(HangoutEvent(id: "local-\(UUID().uuidString)", title: title, start: start, end: end, isAllDay: isAllDay, source: .local))
        save()
    }

    func update(id: String, title: String, start: Date, end: Date, isAllDay: Bool) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].title = title
        events[index].start = start
        events[index].end = end
        events[index].isAllDay = isAllDay
        save()
    }

    func delete(id: String) {
        events.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private struct Stored: Codable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return }
        events = stored.map { HangoutEvent(id: $0.id, title: $0.title, start: $0.start, end: $0.end, isAllDay: $0.isAllDay, source: .local) }
    }

    private func save() {
        let stored = events.map { Stored(id: $0.id, title: $0.title, start: $0.start, end: $0.end, isAllDay: $0.isAllDay) }
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: fileURL)
        }
    }
}
