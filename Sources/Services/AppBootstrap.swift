import Foundation

/// One-time startup work that data loading depends on — currently restoring the
/// Google session so we know whether Google Calendar is connected before the
/// first fetch. Runs once; every caller awaits the same task.
@MainActor
final class AppBootstrap {
    static let shared = AppBootstrap()

    private var task: Task<Void, Never>?

    /// Returns once startup restoration has finished (starting it if needed).
    func ready() async {
        if task == nil {
            task = Task {
                await GoogleAuthManager.shared.restorePreviousSignIn()
                GoogleCalendarService.shared.refreshConnectionState()
            }
        }
        await task?.value
    }
}
