import Foundation
import Supabase
import Observation

/// Sends event invites and handles incoming ones (accept → mirror into the
/// invitee's calendar; decline → just mark declined).
@MainActor
@Observable
final class EventShareService {
    static let shared = EventShareService()

    private(set) var pending: [PendingInvite] = []

    private var client: SupabaseClient? { SupabaseManager.shared.client }
    private var myID: UUID? { AuthService.shared.session?.user.id }

    func loadPending() async {
        guard let client, let me = myID else { pending = []; return }
        do {
            let shares: [EventShare] = try await client
                .from("event_shares")
                .select()
                .eq("invitee", value: me.uuidString)
                .eq("status", value: "pending")
                .order("starts_at", ascending: true)
                .execute()
                .value

            let ownerIDs = Array(Set(shares.map { $0.owner.uuidString }))
            var names: [UUID: String] = [:]
            if !ownerIDs.isEmpty {
                let owners: [Profile] = try await client
                    .from("profiles")
                    .select()
                    .in("id", values: ownerIDs)
                    .execute()
                    .value
                names = Dictionary(uniqueKeysWithValues: owners.map { ($0.id, $0.username) })
            }

            pending = shares.map { PendingInvite(share: $0, ownerName: names[$0.owner] ?? "A friend") }
        } catch {
            // Leave previous state on error.
        }
    }

    /// Creates one invite row per friend for an event the owner just made.
    func invite(friendIDs: [UUID], title: String, start: Date, end: Date, isAllDay: Bool) async throws {
        guard let client, let me = myID, !friendIDs.isEmpty else { return }
        let rows = friendIDs.map {
            NewEventShare(
                owner: me, invitee: $0, title: title,
                startsAt: ISO.string(start), endsAt: ISO.string(end),
                isAllDay: isAllDay, status: "pending"
            )
        }
        try await client.from("event_shares").insert(rows).execute()
    }

    func respond(to invite: PendingInvite, accept: Bool) async throws {
        guard let client else { return }
        if accept, let start = invite.share.start, let end = invite.share.end {
            // Mirror into this user's own calendar so its photos get logged too.
            try EventStore.shared.createEvent(
                title: invite.share.title,
                start: start, end: end,
                isAllDay: invite.share.isAllDay,
                recurrence: .none
            )
        }
        try await client
            .from("event_shares")
            .update(["status": accept ? "accepted" : "declined"])
            .eq("id", value: invite.share.id.uuidString)
            .execute()
        await loadPending()
    }
}
