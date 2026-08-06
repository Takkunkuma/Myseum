import Foundation

/// Encodable payload for upserting this device's APNs token for the user.
struct DeviceTokenRow: Encodable {
    let userID: UUID
    let token: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
        case platform
    }
}
