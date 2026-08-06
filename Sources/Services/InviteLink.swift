import Foundation

/// Builds and parses `myseum://invite?uid=<userID>` deep links used for adding
/// friends by link or QR code.
enum InviteLink {
    static let scheme = "myseum"
    static let host = "invite"

    static func url(for userID: UUID) -> URL {
        URL(string: "\(scheme)://\(host)?uid=\(userID.uuidString)")!
    }

    /// Returns the invited user's id if `url` is a valid invite link.
    static func userID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == host,
              let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "uid" }),
              let value = item.value
        else { return nil }
        return UUID(uuidString: value)
    }
}
