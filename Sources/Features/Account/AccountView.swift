import SwiftUI

/// Account tab: auth + profile entry, calendars, events settings, theme.
struct AccountView: View {
    @AppStorage(ThemeColor.storageKey) private var themeRaw = ThemeColor.default.rawValue
    @State private var auth = AuthService.shared
    @State private var showAuth = false
    @State private var isSigningOut = false
    @State private var gcal = GoogleCalendarService.shared
    @State private var isConnectingCalendar = false
    @State private var calendarError: String?
    @State private var hidden = HiddenEventsStore.shared

    private var theme: ThemeColor { ThemeColor.current(from: themeRaw) }

    var body: some View {
        NavigationStack {
            List {
                profileSection

                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Theme color")
                            Spacer()
                            Text(theme.title).foregroundStyle(.secondary)
                        }
                        themeSwatches
                    }
                    .padding(.vertical, 4)
                }

                if gcal.isConfigured {
                    Section("Calendars") {
                        if gcal.isConnected {
                            Label("Google Calendar connected", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                            Button("Disconnect Google Calendar", role: .destructive) {
                                gcal.disconnect()
                                Task { await EventStore.shared.refresh() }
                            }
                        } else {
                            Button { connectCalendar() } label: {
                                HStack {
                                    Label("Connect Google Calendar", systemImage: "calendar.badge.plus")
                                    if isConnectingCalendar { Spacer(); ProgressView() }
                                }
                            }
                            .disabled(isConnectingCalendar)
                        }
                        if let calendarError {
                            Text(calendarError).font(.footnote).foregroundStyle(.red)
                        }
                    }
                }

                Section("Events") {
                    NavigationLink {
                        RecurringEventsView()
                    } label: {
                        Label("Recurring events", systemImage: "repeat")
                    }
                    if !hidden.isEmpty {
                        Button("Unhide all (\(hidden.count))") {
                            hidden.clearAll()
                            Task { await EventStore.shared.refresh() }
                        }
                    }
                }

                if auth.isAuthenticated {
                    Section {
                        NavigationLink {
                            FriendsView()
                        } label: {
                            Label("Friends", systemImage: "person.2")
                        }
                    }

                    Section {
                        Button(role: .destructive) { signOut() } label: {
                            HStack {
                                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                if isSigningOut { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(isSigningOut)
                    }
                }
            }
            .navigationTitle("Account")
            .contentMargins(.bottom, 96, for: .scrollContent)
            .sheet(isPresented: $showAuth) { AuthView() }
        }
    }

    @ViewBuilder private var profileSection: some View {
        Section {
            if auth.isAuthenticated {
                NavigationLink {
                    EditProfileView()
                } label: {
                    HStack(spacing: 14) {
                        AvatarView(urlString: auth.profile?.avatarURL, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.profile?.username ?? "Loading…")
                                .font(.headline)
                            Text(auth.profile?.email ?? auth.session?.user.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Button { showAuth = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign in or create account").font(.headline)
                            Text(auth.isConfigured
                                 ? "Add friends and share events"
                                 : "Backend not configured yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(!auth.isConfigured)
            }
        }
    }

    private var themeSwatches: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(ThemeColor.allCases) { option in
                    let isSelected = option == theme
                    Circle()
                        .fill(option.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if isSelected {
                                Circle().strokeBorder(.primary.opacity(0.6), lineWidth: 2)
                                    .padding(-3)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.snappy) { themeRaw = option.rawValue }
                        }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func connectCalendar() {
        calendarError = nil
        isConnectingCalendar = true
        Task {
            defer { isConnectingCalendar = false }
            do {
                try await gcal.connect()
                await EventStore.shared.refresh()
            } catch {
                calendarError = error.localizedDescription
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        Task {
            defer { isSigningOut = false }
            try? await auth.signOut()
        }
    }
}
