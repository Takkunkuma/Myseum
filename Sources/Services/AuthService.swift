import Foundation
import Supabase
import Observation

/// App-wide auth + current profile state. Backed by the Supabase client when
/// configured; otherwise stays signed-out and inert.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private(set) var profile: Profile?

    var isConfigured: Bool { SupabaseManager.shared.client != nil }
    var isAuthenticated: Bool { session != nil }

    private var client: SupabaseClient? { SupabaseManager.shared.client }

    /// Loads any persisted session and then observes auth changes. Call once at launch.
    func start() async {
        guard let client else { return }
        session = try? await client.auth.session
        if session != nil {
            await loadProfile()
            await NotificationService.shared.syncToken()
        }

        for await change in client.auth.authStateChanges {
            session = change.session
            if session != nil {
                await loadProfile()
                await NotificationService.shared.syncToken()
            } else {
                profile = nil
            }
        }
    }

    func signUp(email: String, password: String, username: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)]
        )
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        try await client.auth.signIn(email: email, password: password)
    }

    /// Native Google sign-in: get tokens from the GoogleSignIn SDK (also granting
    /// the calendar scope) and exchange the ID token for a Supabase session.
    func signInWithGoogle() async throws {
        guard let client else { throw AuthError.notConfigured }
        let tokens = try await GoogleAuthManager.shared.signIn(requestCalendar: true)
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: tokens.idToken, accessToken: tokens.accessToken)
        )
    }

    func signOut() async throws {
        guard let client else { throw AuthError.notConfigured }
        try await client.auth.signOut()
    }

    /// Updates the profile's display name.
    func updateUsername(_ username: String) async throws {
        guard let client, let userID = session?.user.id else { throw AuthError.notConfigured }
        let clean = username.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        try await client
            .from("profiles")
            .update(["username": clean])
            .eq("id", value: userID.uuidString)
            .execute()
        await loadProfile()
    }

    /// Uploads a new avatar image to Storage and points the profile at it.
    func updateAvatar(jpeg data: Data) async throws {
        guard let client, let userID = session?.user.id else { throw AuthError.notConfigured }
        // Lowercase: the storage RLS policy compares the folder to auth.uid()::text,
        // which Postgres returns lowercase. uuidString is uppercase and would be denied.
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"

        try await client.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        // Cache-buster so SwiftUI reloads the new image.
        let urlString = publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"

        try await client
            .from("profiles")
            .update(["avatar_url": urlString])
            .eq("id", value: userID.uuidString)
            .execute()

        await loadProfile()
    }

    private func loadProfile() async {
        guard let client, let userID = session?.user.id else { return }
        profile = try? await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .single()
            .execute()
            .value
    }

    enum AuthError: LocalizedError {
        case notConfigured
        var errorDescription: String? {
            "Supabase isn't configured yet. Add your credentials in Secrets.swift."
        }
    }
}
