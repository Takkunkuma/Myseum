import SwiftUI
import Photos

/// The selected day's events as a pull-up bottom sheet. A grabber lets the user
/// drag (or flick) it up to a full page in a single swipe. Events with photos are
/// expandable rows with a photo count; photo-less events drop to quiet plain lines.
struct DayEventsPanel: View {
    let day: Date
    let events: [HangoutEvent]
    let availableHeight: CGFloat
    var onEdit: (HangoutEvent) -> Void
    var onHide: (HangoutEvent) -> Void

    @State private var expanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var counts: [String: Int] = [:]
    @State private var countsReady = false

    private var photosGranted: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
    private var peekHeight: CGFloat { max(180, min(280, availableHeight * 0.4)) }
    private var fullHeight: CGFloat { max(peekHeight, availableHeight - 6) }
    private var height: CGFloat {
        let base = expanded ? fullHeight : peekHeight
        return min(fullHeight, max(peekHeight, base - dragOffset))
    }

    var body: some View {
        VStack(spacing: 0) {
            handle
            eventsList
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -3)
        .task(id: eventsKey) { await computeCounts() }
    }

    private var eventsKey: String { events.map(\.id).joined(separator: ",") }

    private func computeCounts() async {
        guard photosGranted else { countsReady = false; return }
        var result: [String: Int] = [:]
        for event in events { result[event.id] = PhotoMatcher.shared.count(from: event.start, to: event.end) }
        counts = result
        countsReady = true
    }

    // MARK: - Grabber (drag to expand)

    private var handle: some View {
        VStack(spacing: 8) {
            Capsule().fill(.secondary.opacity(0.5)).frame(width: 40, height: 5)
            HStack {
                Text(day.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.headline)
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { setExpanded(!expanded) }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in dragOffset = value.translation.height }
                .onEnded { value in
                    // Velocity-aware: a single upward flick fully expands (or collapses).
                    let projected = (expanded ? fullHeight : peekHeight) - value.predictedEndTranslation.height
                    let willExpand = projected > (peekHeight + fullHeight) / 2
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        expanded = willExpand
                        dragOffset = 0
                    }
                }
        )
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { expanded = value }
    }

    // MARK: - Events list

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if events.isEmpty {
                    Text("No events. Tap + to add one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } else {
                    ForEach(feedItems) { item in
                        switch item {
                        case .event(let event):
                            DayEventRow(
                                event: event,
                                photoCount: counts[event.id] ?? -1,
                                onEdit: { onEdit(event) },
                                onHide: { onHide(event) }
                            )
                        case .empties(let group):
                            EmptiesGroupView(events: group, onEdit: onEdit, onHide: onHide)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var feedItems: [DayFeedItem] {
        guard photosGranted, countsReady else { return events.map { .event($0) } }
        var items: [DayFeedItem] = []
        var group: [HangoutEvent] = []
        func flush() { if !group.isEmpty { items.append(.empties(group)); group = [] } }
        for event in events {
            if (counts[event.id] ?? 1) > 0 {
                flush()
                items.append(.event(event))
            } else {
                group.append(event)
            }
        }
        flush()
        return items
    }
}

private enum DayFeedItem: Identifiable {
    case event(HangoutEvent)
    case empties([HangoutEvent])

    var id: String {
        switch self {
        case .event(let e):   return "e-\(e.id)"
        case .empties(let g): return "g-\(g.first?.id ?? "")-\(g.count)"
        }
    }
}

/// One photo-having event inside the day panel — tap to expand and reveal its
/// photos. Shows a photo count badge so you know it has some without expanding.
private struct DayEventRow: View {
    let event: HangoutEvent
    var photoCount: Int = -1
    var onEdit: () -> Void
    var onHide: () -> Void

    @State private var expanded = false
    @State private var assets: [PHAsset] = []
    @State private var loaded = false
    @State private var selection: AssetCollection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)

            if expanded {
                if loaded && assets.isEmpty {
                    EmptyPhotosView()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                PhotoThumbnail(asset: asset)
                                    .onTapGesture {
                                        selection = AssetCollection(assets: assets, startIndex: index, eventID: event.id)
                                    }
                            }
                            if !loaded {
                                ProgressView().frame(width: 120, height: 120)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            if event.isEditable {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            }
            Button { onHide() } label: { Label("Hide from Myseum", systemImage: "eye.slash") }
        }
        .task(id: expanded) {
            if expanded && !loaded {
                assets = PhotoMatcher.shared.assets(from: event.start, to: event.end)
                    .filter { !ExcludedPhotosStore.shared.isExcluded(eventID: event.id, assetID: $0.localIdentifier) }
                loaded = true
            }
        }
        .fullScreenCover(item: $selection) { collection in
            PhotoViewerView(collection: collection) { removed in
                withAnimation { assets.removeAll { $0.localIdentifier == removed.localIdentifier } }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.source == .google ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: 6, height: 6)
            Text(event.title).foregroundStyle(.primary)
            if event.source == .google {
                Image(systemName: "g.circle").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if photoCount > 0 {
                HStack(spacing: 3) {
                    Text("\(photoCount)")
                    Image(systemName: "photo")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Text(event.isAllDay ? "All-day" : event.start.formatted(.dateTime.hour().minute()))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(expanded ? 0 : -90))
        }
        .font(.subheadline)
        .contentShape(Rectangle())
    }
}
