import SwiftUI

/// Lists recurring events detected across the user's calendars so they can hide
/// notification-style ones (e.g. "Chase Closing Today"). Hiding a series hides
/// every occurrence — now and in the future. Tap a row to toggle it, or use
/// Select to hide/unhide several at once.
struct RecurringEventsView: View {
    @State private var store = EventStore.shared
    @State private var hidden = HiddenEventsStore.shared
    @State private var isSelecting = false
    @State private var selectedKeys: Set<String> = []

    var body: some View {
        List {
            if store.recurringSeries.isEmpty {
                ContentUnavailableView(
                    "No recurring events",
                    systemImage: "repeat",
                    description: Text("Recurring events from your calendars will show up here.")
                )
            } else {
                Section {
                    ForEach(store.recurringSeries) { series in
                        row(series)
                    }
                } footer: {
                    Text("Hiding one removes every occurrence of that event from Myseum, now and in the future. It stays in your real calendar.")
                }
            }
        }
        .navigationTitle(isSelecting ? "\(selectedKeys.count) selected" : "Recurring events")
        .toolbar {
            if !store.recurringSeries.isEmpty {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { isSelecting = false; selectedKeys.removeAll() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { hideSelected() } label: { Label("Hide", systemImage: "eye.slash") }
                            Button { unhideSelected() } label: { Label("Unhide", systemImage: "eye") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(selectedKeys.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Select") { isSelecting = true }
                    }
                }
            }
        }
        .task { await store.refresh() }
    }

    private func row(_ series: RecurringSeries) -> some View {
        let isHidden = hidden.isSeriesHidden(series.id)
        let isSelected = selectedKeys.contains(series.id)
        return Button {
            if isSelecting { toggleSelect(series.id) }
            else { toggleHidden(series, isHidden) }
        } label: {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                } else {
                    Image(systemName: "repeat").foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(series.title)
                        .foregroundStyle(isHidden ? .secondary : .primary)
                    Text(series.source == .google ? "Google Calendar" : "Calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelecting {
                    if isHidden {
                        Text("Hidden").font(.caption2).foregroundStyle(.tint)
                    }
                } else {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye")
                        .foregroundStyle(isHidden ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleSelect(_ key: String) {
        if selectedKeys.contains(key) { selectedKeys.remove(key) } else { selectedKeys.insert(key) }
    }

    private func toggleHidden(_ series: RecurringSeries, _ isHidden: Bool) {
        if isHidden { hidden.unhideSeries(series.id) } else { hidden.hideSeries(series.id) }
        Task { await store.refresh() }
    }

    private func hideSelected() {
        for key in selectedKeys { hidden.hideSeries(key) }
        finishSelection()
    }

    private func unhideSelected() {
        for key in selectedKeys { hidden.unhideSeries(key) }
        finishSelection()
    }

    private func finishSelection() {
        selectedKeys.removeAll()
        isSelecting = false
        Task { await store.refresh() }
    }
}
