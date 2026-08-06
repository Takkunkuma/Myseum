import SwiftUI
import Photos

/// Events tab: incoming invites (if any) on top, then your events newest →
/// oldest, each with its photo log.
struct EventsListView: View {
    @State private var store = EventStore.shared
    @State private var shares = EventShareService.shared
    @State private var auth = AuthService.shared
    @State private var gcal = GoogleCalendarService.shared
    @State private var photoStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showEditor = false
    @State private var editingEvent: HangoutEvent?
    @State private var pendingDelete: HangoutEvent?
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var removalStyle: RemovalStyle = .shrink

    private enum RemovalStyle { case shrink, slide }

    var body: some View {
        NavigationStack {
            Group {
                if !store.authorized && !gcal.isConnected {
                    permissionPrompt
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(shares.pending) { invite in
                                InviteCard(invite: invite) { accept in
                                    Task { try? await shares.respond(to: invite, accept: accept); await store.refresh() }
                                }
                            }

                            if store.events.isEmpty {
                                ContentUnavailableView(
                                    "No events yet",
                                    systemImage: "calendar.badge.plus",
                                    description: Text("Tap + to create an event and start logging photos.")
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(store.events) { event in
                                    EventRowView(
                                        event: event,
                                        onEdit: { editingEvent = event },
                                        onDelete: { pendingDelete = event },
                                        onHide: { hide([event.id]) },
                                        selectionMode: isSelecting,
                                        isSelected: selectedIDs.contains(event.id),
                                        onToggleSelect: { toggleSelect(event.id) }
                                    )
                                    .transition(.asymmetric(insertion: .identity, removal: currentRemoval))
                                }
                            }
                        }
                        .padding()
                    }
                    .contentMargins(.bottom, 96, for: .scrollContent)
                }
            }
            .navigationTitle(isSelecting ? "\(selectedIDs.count) selected" : "Events")
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { isSelecting = false; selectedIDs.removeAll() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { hideSelected() } label: { Label("Hide", systemImage: "eye.slash") }
                            Button(role: .destructive) { deleteSelected() } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                } else {
                    if !store.events.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Select") { isSelecting = true }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showEditor = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: { Task { await store.refresh() } }) {
                EventEditorView(initialDate: Date())
            }
            .sheet(item: $editingEvent, onDismiss: { Task { await store.refresh() } }) { event in
                EventEditorView(editing: event)
            }
            .confirmationDialog("Delete this event?", isPresented: deleteDialogBinding, titleVisibility: .visible, presenting: pendingDelete) { event in
                Button("Delete Event", role: .destructive) { delete(event) }
            }
            .task { await loadEverything() }
            .refreshable { await loadEverything() }
        }
    }

    private func toggleSelect(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func hideSelected() {
        hide(selectedIDs)
        selectedIDs.removeAll()
        isSelecting = false
    }

    /// Delete the editable selected events; non-editable ones (Google) can't be
    /// deleted, so they're hidden instead. Removed together with a shrink & fade.
    private func deleteSelected() {
        let ids = selectedIDs
        removalStyle = .shrink
        for id in ids {
            if let event = store.events.first(where: { $0.id == id }), event.isEditable {
                try? store.deleteEvent(id: id)
            } else {
                HiddenEventsStore.shared.hide(id)
            }
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            store.events.removeAll { ids.contains($0.id) }
        }
        selectedIDs.removeAll()
        isSelecting = false
        Task { await store.refresh() }
    }

    private var currentRemoval: AnyTransition {
        switch removalStyle {
        case .shrink: return .scale.combined(with: .opacity)
        case .slide:  return .move(edge: .trailing).combined(with: .opacity)
        }
    }

    /// Hide = slide out to the right. Cards animate out together.
    private func hide(_ ids: Set<String>) {
        for id in ids { HiddenEventsStore.shared.hide(id) }
        removalStyle = .slide
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            store.events.removeAll { ids.contains($0.id) }
        }
    }

    /// Delete = shrink & fade.
    private func delete(_ event: HangoutEvent) {
        removalStyle = .shrink
        try? store.deleteEvent(id: event.id)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            store.events.removeAll { $0.id == event.id }
        }
        Task { await store.refresh() }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var permissionPrompt: some View {
        ContentUnavailableView {
            Label("Calendar access needed", systemImage: "calendar")
        } description: {
            Text("Myseum needs access to your calendar to show your events and their photos.")
        } actions: {
            Button("Grant access") { Task { await loadEverything() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private func loadEverything() async {
        if !store.authorized { await store.requestAccess() }
        if photoStatus == .notDetermined {
            photoStatus = await PhotoMatcher.shared.requestAccess()
        }
        await store.refresh()
        if auth.isAuthenticated { await shares.loadPending() }
    }
}

/// A pending event invitation with Accept / Decline.
private struct InviteCard: View {
    let invite: PendingInvite
    let respond: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(invite.ownerName) invited you", systemImage: "envelope.open")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)

            Text(invite.share.title).font(.headline)
            if let start = invite.share.start {
                Text(subtitle(start: start, end: invite.share.end, allDay: invite.share.isAllDay))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button { respond(true) } label: {
                    Text("Accept").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) { respond(false) } label: {
                    Text("Decline").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(.tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.tint.opacity(0.25), lineWidth: 1))
    }

    private func subtitle(start: Date, end: Date?, allDay: Bool) -> String {
        let date = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if allDay { return "\(date) · All-day" }
        let from = start.formatted(.dateTime.hour().minute())
        if let end { return "\(date) · \(from) – \(end.formatted(.dateTime.hour().minute()))" }
        return "\(date) · \(from)"
    }
}
