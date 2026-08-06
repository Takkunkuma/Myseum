import Foundation

/// A row from the `friendships` table.
struct Friendship: Codable, Identifiable, Hashable {
    let id: UUID
    let requester: UUID
    let addressee: UUID
    var status: String

    /// The other party relative to `me`.
    func otherID(than me: UUID) -> UUID {
        requester == me ? addressee : requester
    }
}

/// Encodable payload for inserting a new friendship.
struct NewFriendship: Encodable {
    let requester: UUID
    let addressee: UUID
    let status: String
}
