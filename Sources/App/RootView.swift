import SwiftUI

struct RootView: View {
    @AppStorage(ThemeColor.storageKey) private var themeRaw = ThemeColor.default.rawValue

    @State private var selection: AppTab = .initial
    /// Direction of the most recent tab change; drives the slide transition.
    @State private var forward = true

    @State private var inviteResult: String?
    @State private var showInviteResult = false
    @State private var showSearch = false
    /// Tabs the user has opened — an unvisited tab stays idle until first shown.
    @State private var visited: Set<AppTab> = [.initial]
    /// Bumped when the active tab is tapped again, asking it to scroll to the top.
    @State private var scrollToTop = 0

    private var theme: ThemeColor { ThemeColor.current(from: themeRaw) }

    var body: some View {
        ZStack(alignment: .bottom) {
            pager

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
        .task { await AppBootstrap.shared.ready() }
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

    /// All three tabs live side by side and the row slides — so each keeps its
    /// identity (and therefore its state, scroll position and loaded data) instead
    /// of being torn down and rebuilt on every switch.
    private var pager: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                EventsListView(isActive: visited.contains(.events), scrollToTop: scrollToTop)
                    .frame(width: geo.size.width)
                CalendarView(isActive: visited.contains(.calendar))
                    .frame(width: geo.size.width)
                AccountView()
                    .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width * CGFloat(AppTab.allCases.count), alignment: .leading)
            .offset(x: -CGFloat(selection.rawValue) * geo.size.width)
        }
    }

    private func select(_ tab: AppTab) {
        // Tapping the tab you're already on scrolls it back to the top.
        guard tab != selection else {
            scrollToTop += 1
            return
        }
        forward = tab.rawValue > selection.rawValue
        withAnimation(.smooth(duration: 0.35)) {
            selection = tab
            visited.insert(tab)   // a tab starts loading the first time it's opened
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
