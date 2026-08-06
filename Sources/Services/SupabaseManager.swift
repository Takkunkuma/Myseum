import Foundation
import Supabase

/// Owns the single `SupabaseClient`. Returns nil when no credentials are set,
/// so the rest of the app can run in on-device-only mode.
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient?

    private init() {
        if SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        } else {
            client = nil
        }
    }
}
