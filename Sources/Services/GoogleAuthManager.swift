import Foundation
import UIKit
import GoogleSignIn

/// Wraps the GoogleSignIn SDK: configuration, sign-in (with optional calendar
/// scope), token refresh, and the URL callback. Token refresh is handled by the
/// SDK, which keeps Google Calendar access working long-term.
@MainActor
final class GoogleAuthManager {
    static let shared = GoogleAuthManager()

    static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    func configure() {
        guard GoogleConfig.isConfigured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: GoogleConfig.iosClientID,
            serverClientID: GoogleConfig.serverClientID.isEmpty ? nil : GoogleConfig.serverClientID
        )
    }

    func restorePreviousSignIn() async {
        guard GoogleConfig.isConfigured else { return }
        await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in continuation.resume() }
        }
    }

    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    var hasCalendarAccess: Bool {
        GIDSignIn.sharedInstance.currentUser?.grantedScopes?.contains(Self.calendarScope) ?? false
    }

    var isSignedIn: Bool { GIDSignIn.sharedInstance.currentUser != nil }

    /// Interactive sign-in. Returns the tokens Supabase needs for `signInWithIdToken`.
    /// (AppAuth injects a nonce into the ID token that can't be read back, so the
    /// Supabase Google provider must have "Skip nonce checks" enabled.)
    func signIn(requestCalendar: Bool) async throws -> (idToken: String, accessToken: String) {
        guard let presenter = Self.topViewController() else { throw GoogleError.noPresenter }
        let scopes = requestCalendar ? [Self.calendarScope] : []
        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil, additionalScopes: scopes) { result, error in
                if let error { cont.resume(throwing: error) }
                else if let result { cont.resume(returning: result) }
                else { cont.resume(throwing: GoogleError.noResult) }
            }
        }
        guard let idToken = result.user.idToken?.tokenString else { throw GoogleError.noIDToken }
        return (idToken, result.user.accessToken.tokenString)
    }

    /// Adds the calendar scope to an already-signed-in Google user.
    func addCalendarScope() async throws {
        guard let presenter = Self.topViewController() else { throw GoogleError.noPresenter }
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw GoogleError.notSignedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            user.addScopes([Self.calendarScope], presenting: presenter) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
            }
        }
    }

    /// A fresh access token for calling Google APIs (refreshes if needed).
    func freshAccessToken() async -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        return await withCheckedContinuation { continuation in
            user.refreshTokensIfNeeded { user, _ in
                continuation.resume(returning: user?.accessToken.tokenString)
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    enum GoogleError: LocalizedError {
        case noPresenter, noResult, noIDToken, notSignedIn
        var errorDescription: String? {
            switch self {
            case .noPresenter: return "Couldn't present the Google sign-in screen."
            case .noResult:    return "Google sign-in returned no result."
            case .noIDToken:   return "Google sign-in didn't return an ID token."
            case .notSignedIn: return "Sign in with Google first."
            }
        }
    }

    /// Finds the frontmost view controller to present the Google sheet from.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
