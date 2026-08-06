import Foundation

/// Lenient ISO-8601 helpers for Postgres `timestamptz` values, which may or may
/// not include fractional seconds.
enum ISO {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }

    static func string(_ date: Date) -> String {
        plain.string(from: date)
    }
}

/// A row from `event_shares` — an event one user invited another to.
struct EventShare: Codable, Identifiable, Hashable {
    let id: UUID
    let owner: UUID
    let invitee: UUID
    let title: String
    let startsAt: String
    let endsAt: String
    let isAllDay: Bool
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, owner, invitee, title, status
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isAllDay = "is_all_day"
    }

    var start: Date? { ISO.date(startsAt) }
    var end: Date? { ISO.date(endsAt) }
}

/// Encodable payload for inviting a friend to an event.
struct NewEventShare: Encodable {
    let owner: UUID
    let invitee: UUID
    let title: String
    let startsAt: String
    let endsAt: String
    let isAllDay: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case owner, invitee, title, status
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isAllDay = "is_all_day"
    }
}

/// A pending invite paired with the inviter's display name, for the UI.
struct PendingInvite: Identifiable {
    let share: EventShare
    let ownerName: String
    var id: UUID { share.id }
}
