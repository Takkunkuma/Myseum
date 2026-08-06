import SwiftUI
import Photos

/// One event card: date + name, and a horizontal scroller of the photos/videos
/// captured during the event. Shows the empty state when there are none.
struct EventRowView: View {
    let event: HangoutEvent
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onHide: () -> Void = {}
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: () -> Void = {}

    @State private var assets: [PHAsset] = []
    @State private var loaded = false
    @State private var selection: AssetCollection?

    var body: some View {
        HStack(spacing: 12) {
            if selectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 10) {
                header

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
                                ProgressView()
                                    .frame(width: 120, height: 120)
                            }
                        }
                    }
                    .allowsHitTesting(!selectionMode)   // taps select the card in selection mode
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.tint, lineWidth: selectionMode && isSelected ? 2 : 0)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { if selectionMode { onToggleSelect() } }
        .contextMenu {
            if !selectionMode {
                if event.isEditable {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                }
                Button { onHide() } label: { Label("Hide from Myseum", systemImage: "eye.slash") }
            }
        }
        .task(id: event.id) {
            assets = PhotoMatcher.shared.assets(from: event.start, to: event.end)
                .filter { !ExcludedPhotosStore.shared.isExcluded(eventID: event.id, assetID: $0.localIdentifier) }
            loaded = true
        }
        .fullScreenCover(item: $selection) { collection in
            PhotoViewerView(collection: collection) { removed in
                withAnimation { assets.removeAll { $0.localIdentifier == removed.localIdentifier } }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline)
                Text(EventDateFormatter.subtitle(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loaded && !assets.isEmpty {
                Label("\(assets.count)", systemImage: "photo.on.rectangle.angled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Shared date formatting for event cards.
enum EventDateFormatter {
    static func subtitle(for event: HangoutEvent) -> String {
        let cal = Calendar.current
        // For all-day events the end is the next midnight, so step back to the real last day.
        let lastDay = event.isAllDay ? (cal.date(byAdding: .second, value: -1, to: event.end) ?? event.end) : event.end

        if !cal.isDate(event.start, inSameDayAs: lastDay) {
            let s = event.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            let e = lastDay.formatted(.dateTime.month(.abbreviated).day())
            return "\(s) – \(e)"   // multi-day block
        }

        let date = event.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if event.isAllDay { return "\(date) · All-day" }
        let from = event.start.formatted(.dateTime.hour().minute())
        let to = event.end.formatted(.dateTime.hour().minute())
        return "\(date) · \(from) – \(to)"
    }
}
