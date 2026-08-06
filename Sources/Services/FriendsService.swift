import Foundation
import Supabase
import Observation

/// Loads the current user's friends and adds new ones (via invite link / QR).
@MainActor
@Observable
final class FriendsService {
    static let shared = FriendsService()

    private(set) var friends: [Profile] = []
    private(set) var isLoading = false

    private var client: SupabaseClient? { SupabaseManager.shared.client }
    private var myID: UUID? { AuthService.shared.session?.user.id }

    func load() async {
        guard let client, let me = myID else { friends = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Friendship] = try await client
                .from("friendships")
                .select()
                .or("requester.eq.\(me.uuidString),addressee.eq.\(me.uuidString)")
                .eq("status", value: "accepted")
                .execute()
                .value

            let otherIDs = rows.map { $0.otherID(than: me).uuidString }
            guard !otherIDs.isEmpty else { friends = []; return }

            friends = try await client
                .from("profiles")
                .select()
                .in("id", values: otherIDs)
                .execute()
                .value
        } catch {
            // Keep whatever we had; surfacing errors here is low value.
        }
    }

    /// Adds a friend by their user id (from an invite link or scanned QR).
    /// Frictionless: the friendship is created already accepted.
    @discardableResult
    func addFriend(targetID: UUID) async throws -> Bool {
        guard let client, let me = myID else { throw AuthService.AuthError.notConfigured }
        guard targetID != me else { return false }

        try await client
            .from("friendships")
            .upsert(
                NewFriendship(requester: me, addressee: targetID, status: "accepted"),
                onConflict: "requester,addressee"
            )
            .execute()

        await load()
        return true
    }

    /// Removes the friendship in either direction.
    func removeFriend(_ friendID: UUID) async throws {
        guard let client, let me = myID else { throw AuthService.AuthError.notConfigured }
        try await client
            .from("friendships")
            .delete()
            .or("and(requester.eq.\(me.uuidString),addressee.eq.\(friendID.uuidString)),and(requester.eq.\(friendID.uuidString),addressee.eq.\(me.uuidString))")
            .execute()
        await load()
    }

    func profile(for id: UUID) async -> Profile? {
        guard let client else { return nil }
        return try? await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
}
