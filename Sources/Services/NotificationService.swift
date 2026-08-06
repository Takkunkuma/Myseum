import Foundation
import UIKit
import UserNotifications
import Supabase

/// Requests notification permission, registers for remote (APNs) notifications,
/// and stores this device's token against the signed-in user.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var deviceToken: String?

    /// Ask for permission and, if granted, register for remote notifications.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Called from the AppDelegate once APNs returns a token.
    func setDeviceToken(_ token: String) {
        deviceToken = token
        Task { await syncToken() }
    }

    /// Associates the stored device token with the current user. Safe to call on
    /// sign-in (the token may have arrived before the user signed in, or vice versa).
    func syncToken() async {
        guard let client = SupabaseManager.shared.client,
              let me = AuthService.shared.session?.user.id,
              let token = deviceToken else { return }
        try? await client
            .from("device_tokens")
            .upsert(
                DeviceTokenRow(userID: me, token: token, platform: "ios"),
                onConflict: "user_id,token"
            )
            .execute()
    }
}
