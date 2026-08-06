import SwiftUI

/// Calendar tab: a simple but roomy month grid. Tap a day to see its events
/// (compact list) and tap + to add one. Month changes slide horizontally.
struct CalendarView: View {
    @State private var store = EventStore.shared
    @State private var displayedMonth = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showEditor = false
    @State private var editingEvent: HangoutEvent?
    @State private var monthForward = true

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let rowHeight: CGFloat = 50

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 14) {
                        monthHeader
                        weekdayHeader
                        slidingGrid
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    DayEventsPanel(
                        day: selectedDay,
                        events: store.events(on: selectedDay),
                        availableHeight: geo.size.height,
                        onEdit: { editingEvent = $0 },
                        onHide: { hide($0) }
                    )
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: { Task { await store.refresh() } }) {
                EventEditorView(initialDate: selectedDay)
            }
            .sheet(item: $editingEvent, onDismiss: { Task { await store.refresh() } }) { event in
                EventEditorView(editing: event)
            }
            .task {
                if !store.authorized { await store.requestAccess() }
                await store.refresh()
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.semibold))
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Sliding month grid

    private var slidingGrid: some View {
        ZStack {
            daysGrid
                .id(monthKey)
                .transition(.asymmetric(
                    insertion: .move(edge: monthForward ? .trailing : .leading),
                    removal:   .move(edge: monthForward ? .leading : .trailing)
                ))
        }
        .frame(height: rowHeight * 6)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -40 { changeMonth(1) }
                    else if value.translation.width > 40 { changeMonth(-1) }
                }
        )
    }

    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: rowHeight)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 5) {
                Text(day.formatted(.dateTime.day()))
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                Circle()
                    .fill(store.hasEvents(on: day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight - 6)
            .background(isSelected ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.clear))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func hide(_ event: HangoutEvent) {
        HiddenEventsStore.shared.hide(event.id)
        Task { await store.refresh() }
    }

    // MARK: - Helpers

    private var monthKey: Int {
        cal.component(.year, from: displayedMonth) * 100 + cal.component(.month, from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.shortStandaloneWeekdaySymbols
        let shift = cal.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Days of the displayed month, padded with leading nils for alignment.
    private var monthDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: displayedMonth),
              let range = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            days.append(cal.date(byAdding: .day, value: offset, to: interval.start))
        }
        return days
    }

    private func changeMonth(_ delta: Int) {
        monthForward = delta > 0
        withAnimation(.smooth(duration: 0.3)) {
            displayedMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        }
    }
}
