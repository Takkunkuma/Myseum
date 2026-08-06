import SwiftUI
import Photos

/// Square thumbnail for a single PHAsset, with a play badge + duration for videos.
struct PhotoThumbnail: View {
    let asset: PHAsset
    var size: CGFloat = 120

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }

            if asset.mediaType == .video {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                    Text(durationText)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(6)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: asset.localIdentifier) {
            PhotoMatcher.shared.requestThumbnail(
                for: asset,
                targetSize: CGSize(width: size * 2, height: size * 2)
            ) { image = $0 }
        }
    }

    private var durationText: String {
        let total = Int(asset.duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
