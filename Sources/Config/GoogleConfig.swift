import Foundation

/// Google OAuth configuration, read from the gitignored `Secrets.swift`.
enum GoogleConfig {
    static let iosClientID = Secrets.googleIOSClientID
    static let serverClientID = Secrets.googleServerClientID

    /// True once the iOS client ID is filled in. When false, Google sign-in and
    /// calendar connect are hidden.
    static var isConfigured: Bool { !iosClientID.isEmpty }

    /// URL scheme Google redirects back to = the reversed iOS client ID, e.g.
    /// "123-abc.apps.googleusercontent.com" -> "com.googleusercontent.apps.123-abc".
    static var reversedClientID: String? {
        guard isConfigured else { return nil }
        let parts = iosClientID.components(separatedBy: ".")
        return parts.reversed().joined(separator: ".")
    }
}
