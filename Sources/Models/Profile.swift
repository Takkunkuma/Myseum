import Foundation

/// A user profile row from the `profiles` table.
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var email: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case avatarURL = "avatar_url"
    }
}
