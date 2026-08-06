import SwiftUI

/// Friends list + your invite link / QR code + a way to scan someone else's.
struct FriendsView: View {
    @State private var auth = AuthService.shared
    @State private var friends = FriendsService.shared
    @State private var showScanner = false
    @State private var banner: String?

    private var myInviteURL: URL? {
        guard let id = auth.session?.user.id else { return nil }
        return InviteLink.url(for: id)
    }

    var body: some View {
        List {
            if let url = myInviteURL {
                Section("Add me") {
                    VStack(spacing: 14) {
                        QRCodeView(string: url.absoluteString, size: 200)
                        Text("Have a friend scan this, or send them your link.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        ShareLink(item: url) {
                            Label("Share invite link", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan a friend's QR", systemImage: "qrcode.viewfinder")
                }
            }

            Section("Friends") {
                if friends.friends.isEmpty {
                    Text(friends.isLoading ? "Loading…" : "No friends yet. Share your link to add some!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friends.friends) { friend in
                        FriendRow(friend: friend)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        try? await friends.removeFriend(friend.id)
                                        await showBanner("Removed \(friend.username)")
                                    }
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .overlay(alignment: .top) {
            if let banner {
                Text(banner)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.tint, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { url in
                Task { await accept(url) }
            }
        }
        .task { await friends.load() }
        .refreshable { await friends.load() }
    }

    private func accept(_ url: URL) async {
        guard let id = InviteLink.userID(from: url) else { return }
        do {
            let added = try await friends.addFriend(targetID: id)
            await showBanner(added ? "Friend added!" : "That's you 🙂")
        } catch {
            await showBanner("Couldn't add friend")
        }
    }

    @MainActor private func showBanner(_ text: String) async {
        withAnimation { banner = text }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { banner = nil }
    }
}

private struct FriendRow: View {
    let friend: Profile

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(urlString: friend.avatarURL, size: 38)
            Text(friend.username)
            Spacer()
        }
    }
}
