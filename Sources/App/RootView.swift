import SwiftUI

struct RootView: View {
    @AppStorage(ThemeColor.storageKey) private var themeRaw = ThemeColor.default.rawValue

    @State private var selection: AppTab = .initial
    /// Direction of the most recent tab change; drives the slide transition.
    @State private var forward = true

    @State private var inviteResult: String?
    @State private var showInviteResult = false
    @State private var showSearch = false

    private var theme: ThemeColor { ThemeColor.current(from: themeRaw) }

    var body: some View {
        ZStack(alignment: .bottom) {
            page
                .id(selection)
                .transition(slide)

            HStack(spacing: 10) {
                GlassTabBar(selection: selection, onSelect: select)
                if selection == .events {
                    SearchIsland { showSearch = true }
                        .transition(.scale.combined(with: .opacity).combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, -12)
        }
        .tint(theme.color)
        .sheet(isPresented: $showSearch) { SearchView() }
        .task { await AuthService.shared.start() }
        .task { await NotificationService.shared.requestAuthorizationAndRegister() }
        .task {
            await GoogleAuthManager.shared.restorePreviousSignIn()
            GoogleCalendarService.shared.refreshConnectionState()
            await EventStore.shared.refresh()
        }
        .onOpenURL { url in
            if GoogleAuthManager.shared.handle(url) { return }
            handleInvite(url)
        }
        .alert("Friends", isPresented: $showInviteResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(inviteResult ?? "")
        }
    }

    @ViewBuilder private var page: some View {
        switch selection {
        case .events:   EventsListView()
        case .calendar: CalendarView()
        case .account:  AccountView()
        }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading),
            removal:   .move(edge: forward ? .leading : .trailing)
        )
    }

    private func select(_ tab: AppTab) {
        guard tab != selection else { return }
        forward = tab.rawValue > selection.rawValue
        withAnimation(.smooth(duration: 0.35)) {
            selection = tab
        }
    }

    private func handleInvite(_ url: URL) {
        guard let targetID = InviteLink.userID(from: url) else { return }
        Task {
            guard AuthService.shared.isAuthenticated else {
                present("Sign in first, then open the invite link again to add your friend.")
                select(.account)
                return
            }
            do {
                let added = try await FriendsService.shared.addFriend(targetID: targetID)
                present(added ? "You're now friends! 🎉" : "That invite link is your own.")
            } catch {
                present("Couldn't add friend. Please try again.")
            }
        }
    }

    @MainActor private func present(_ message: String) {
        inviteResult = message
        showInviteResult = true
    }
}
