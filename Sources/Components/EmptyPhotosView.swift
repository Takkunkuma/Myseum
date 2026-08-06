import SwiftUI

/// Shown inside an event card when no photos were captured during the event.
struct EmptyPhotosView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "figure.wave")
                    .font(.title2)
                Text("No photos! Just hanging!")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 120)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
