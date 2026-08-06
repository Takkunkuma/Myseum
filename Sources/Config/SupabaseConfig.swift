import Foundation

/// Reads Supabase credentials from the gitignored `Secrets.swift`.
enum SupabaseConfig {
    static let url = Secrets.supabaseURL
    static let anonKey = Secrets.supabaseAnonKey

    /// True once real credentials are filled in. When false, the app runs in
    /// on-device-only mode and the Account tab shows a "not configured" note.
    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty && URL(string: url) != nil
    }
}
