import Foundation
import Observation

/// Read-only Google Calendar sync. Connecting requests the calendar scope via
/// GoogleSignIn; events are fetched (paginated) from the Calendar REST API and
/// merged into the app's event list.
@MainActor
@Observable
final class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    /// Observable connection state (kept in sync with the Google session).
    private(set) var isConnected: Bool = false
    var isConfigured: Bool { GoogleConfig.isConfigured }

    /// Re-reads whether a Google user with the calendar scope is signed in.
    func refreshConnectionState() {
        isConnected = GoogleConfig.isConfigured && GoogleAuthManager.shared.hasCalendarAccess
    }

    func connect() async throws {
        if GoogleAuthManager.shared.isSignedIn {
            try await GoogleAuthManager.shared.addCalendarScope()
        } else {
            _ = try await GoogleAuthManager.shared.signIn(requestCalendar: true)
        }
        refreshConnectionState()
    }

    func disconnect() {
        GoogleAuthManager.shared.signOut()
        refreshConnectionState()
    }

    /// All events from the user's primary Google calendar within [start, end],
    /// following pagination so busy calendars aren't truncated.
    func fetchEvents(from start: Date, to end: Date) async -> [HangoutEvent] {
        guard isConnected, let token = await GoogleAuthManager.shared.freshAccessToken() else { return [] }

        var results: [HangoutEvent] = []
        var pageToken: String?
        var page = 0

        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            var query = [
                URLQueryItem(name: "timeMin", value: ISO.string(start)),
                URLQueryItem(name: "timeMax", value: ISO.string(end)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "2500")
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            guard let url = components.url else { break }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { break }
                let decoded = try JSONDecoder().decode(GoogleEventList.self, from: data)
                results += decoded.items.compactMap(Self.map)
                pageToken = decoded.nextPageToken
            } catch {
                break
            }
            page += 1
        } while pageToken != nil && page < 20   // safety cap

        return results
    }

    private static func map(_ item: GoogleEvent) -> HangoutEvent? {
        let allDay = item.start.date != nil
        guard let start = item.start.resolvedDate, let end = item.end.resolvedDate else { return nil }
        return HangoutEvent(
            id: "gcal-\(item.id)",
            title: item.summary?.isEmpty == false ? item.summary! : "Untitled",
            start: start,
            end: end,
            isAllDay: allDay,
            source: .google,
            seriesKey: item.recurringEventId.map { "gcal-series-\($0)" }
        )
    }
}

// MARK: - Google Calendar API decoding

private struct GoogleEventList: Decodable {
    let items: [GoogleEvent]
    let nextPageToken: String?
}

private struct GoogleEvent: Decodable {
    let id: String
    let summary: String?
    let start: GoogleEventDate
    let end: GoogleEventDate
    let recurringEventId: String?   // present on instances of a recurring series
}

private struct GoogleEventDate: Decodable {
    let dateTime: String?   // RFC3339 for timed events
    let date: String?       // YYYY-MM-DD for all-day events

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var resolvedDate: Date? {
        if let dateTime { return ISO.date(dateTime) }
        if let date { return Self.dayFormatter.date(from: date) }
        return nil
    }
}
