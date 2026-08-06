import SwiftUI

/// Photo-less events shown as quiet plain lines under a "No photos" label. When a
/// run has more than four, it collapses into a tappable summary. Shared by the
/// Events feed and the Calendar day sheet.
struct EmptiesGroupView: View {
    let events: [HangoutEvent]
    var onEdit: (HangoutEvent) -> Void
    var onHide: (HangoutEvent) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if events.count > 4 {
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo").font(.caption).foregroundStyle(.tertiary)
                        Text("\(events.count) events with no photos")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if expanded { lines }
            } else {
                Text("No photos").font(.caption).foregroundStyle(.tertiary).padding(.leading, 2)
                lines
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }

    private var lines: some View {
        ForEach(events) { event in
            HStack(spacing: 9) {
                Circle().fill(.secondary.opacity(0.5)).frame(width: 5, height: 5)
                Text(event.title).font(.subheadline).foregroundStyle(.secondary)
                if event.source == .google {
                    Image(systemName: "g.circle").font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Text(event.isAllDay ? "All-day" : event.start.formatted(.dateTime.hour().minute()))
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { if event.isEditable { onEdit(event) } }
            .contextMenu {
                if event.isEditable {
                    Button { onEdit(event) } label: { Label("Edit", systemImage: "pencil") }
                }
                Button { onHide(event) } label: { Label("Hide from Myseum", systemImage: "eye.slash") }
            }
        }
    }
}
