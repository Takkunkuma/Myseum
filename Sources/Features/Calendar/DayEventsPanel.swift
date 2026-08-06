import SwiftUI
import Photos

/// The selected day's events as a pull-up bottom sheet. A grabber lets the user
/// drag (or tap) it up to a full page. Each event expands inline to show its
/// photos.
struct DayEventsPanel: View {
    let day: Date
    let events: [HangoutEvent]
    let availableHeight: CGFloat
    var onEdit: (HangoutEvent) -> Void
    var onHide: (HangoutEvent) -> Void

    @State private var expanded = false
    @GestureState private var dragTranslation: CGFloat = 0

    private var peekHeight: CGFloat { max(180, min(280, availableHeight * 0.4)) }
    private var fullHeight: CGFloat { max(peekHeight, availableHeight - 6) }
    private var height: CGFloat {
        let base = expanded ? fullHeight : peekHeight
        return min(fullHeight, max(peekHeight, base - dragTranslation))
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
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: expanded)
    }

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
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { expanded.toggle() }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragTranslation) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let projected = (expanded ? fullHeight : peekHeight) - value.translation.height
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        expanded = projected > (peekHeight + fullHeight) / 2
                    }
                }
        )
    }

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
                    ForEach(events) { event in
                        DayEventRow(event: event, onEdit: { onEdit(event) }, onHide: { onHide(event) })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

/// One event inside the day panel — tap to expand and reveal its photos.
private struct DayEventRow: View {
    let event: HangoutEvent
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
