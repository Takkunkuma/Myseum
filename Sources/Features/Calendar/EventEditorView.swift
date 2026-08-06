import SwiftUI

/// Create or edit an event. Saves through EventKit so it also shows in the
/// Apple Calendar app. When creating, you can also invite friends.
struct EventEditorView: View {
    /// The event being edited, or nil when creating a new one.
    let editing: HangoutEvent?

    @Environment(\.dismiss) private var dismiss
    @State private var store = EventStore.shared

    @State private var title: String
    @State private var isAllDay: Bool
    @State private var start: Date
    @State private var end: Date
    @State private var recurrence: RecurrenceOption
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    @State private var auth = AuthService.shared
    @State private var friends = FriendsService.shared
    @State private var invitedIDs: Set<UUID> = []
    @State private var isSaving = false

    private var isEditing: Bool { editing != nil }

    init(initialDate: Date) {
        self.editing = nil
        let cal = Calendar.current
        let base = cal.date(bySettingHour: 12, minute: 0, second: 0, of: initialDate) ?? initialDate
        _title = State(initialValue: "")
        _isAllDay = State(initialValue: false)
        _start = State(initialValue: base)
        _end = State(initialValue: cal.date(byAdding: .hour, value: 1, to: base) ?? base)
        _recurrence = State(initialValue: .none)
    }

    init(editing event: HangoutEvent) {
        self.editing = event
        _title = State(initialValue: event.title)
        _isAllDay = State(initialValue: event.isAllDay)
        _start = State(initialValue: event.start)
        _end = State(initialValue: event.end)
        _recurrence = State(initialValue: EventStore.shared.recurrence(forID: event.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                }

                Section("Time") {
                    Toggle("All-day", isOn: $isAllDay)
                    if isAllDay {
                        DatePicker("Date", selection: $start, displayedComponents: .date)
                    } else {
                        DatePicker("Starts", selection: $start)
                        DatePicker("Ends", selection: $end)
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(RecurrenceOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                if !isEditing {
                    inviteSection
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            HStack { Spacer(); Text("Delete Event"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Event", role: .destructive) { deleteEvent() }
            }
            .task { if !isEditing && auth.isAuthenticated { await friends.load() } }
        }
    }

    private var inviteSection: some View {
        Section("Invite friends") {
            if !auth.isAuthenticated {
                Text("Sign in (Account tab) to invite friends.")
                    .foregroundStyle(.secondary)
            } else if friends.friends.isEmpty {
                Text("No friends yet — add some from the Friends screen.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friends.friends) { friend in
                    Button {
                        toggle(friend.id)
                    } label: {
                        HStack {
                            AvatarView(urlString: friend.avatarURL, size: 30)
                            Text(friend.username).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: invitedIDs.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(invitedIDs.contains(friend.id) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if invitedIDs.contains(id) { invitedIDs.remove(id) } else { invitedIDs.insert(id) }
    }

    private func normalizedDates() -> (Date, Date) {
        let cal = Calendar.current
        if isAllDay {
            let s = cal.startOfDay(for: start)
            return (s, cal.date(byAdding: .day, value: 1, to: s) ?? s)
        }
        return (start, end <= start ? start.addingTimeInterval(3600) : end)
    }

    private func save() {
        let (startDate, endDate) = normalizedDates()
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)

        do {
            if let editing {
                try store.updateEvent(id: editing.id, title: cleanTitle, start: startDate, end: endDate, isAllDay: isAllDay, recurrence: recurrence)
            } else {
                try store.createEvent(title: cleanTitle, start: startDate, end: endDate, isAllDay: isAllDay, recurrence: recurrence)
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Invites only apply to brand-new events.
        guard !isEditing, !invitedIDs.isEmpty else { dismiss(); return }
        isSaving = true
        Task {
            defer { isSaving = false }
            try? await EventShareService.shared.invite(
                friendIDs: Array(invitedIDs), title: cleanTitle,
                start: startDate, end: endDate, isAllDay: isAllDay
            )
            dismiss()
        }
    }

    private func deleteEvent() {
        guard let editing else { return }
        do {
            try store.deleteEvent(id: editing.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
