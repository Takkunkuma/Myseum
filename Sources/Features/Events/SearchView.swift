import SwiftUI

/// Search across events by name and (optionally) date. Pure local filtering of
/// the already-loaded events — instant, no network.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = EventStore.shared
    @State private var query = ""
    @State private var useDate = false
    @State private var date = Date()

    private var results: [HangoutEvent] {
        store.events.filter { event in
            let matchesText = query.isEmpty
                || event.title.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespaces))
            let matchesDate = !useDate || overlaps(event, day: date)
            return matchesText && matchesDate
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    dateFilter

                    if results.isEmpty {
                        ContentUnavailableView(
                            query.isEmpty && !useDate ? "Search your events" : "No matches",
                            systemImage: "magnifyingglass",
                            description: Text(query.isEmpty && !useDate
                                ? "Find a hangout by name or date."
                                : "Try a different name or date.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(results) { event in
                            EventRowView(event: event)
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $query, prompt: "Search event names")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var dateFilter: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $useDate.animation()) {
                Label("Filter by date", systemImage: "calendar")
            }
            if useDate {
                DatePicker("On", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func overlaps(_ event: HangoutEvent, day: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
        return event.start < end && event.end > start
    }
}
