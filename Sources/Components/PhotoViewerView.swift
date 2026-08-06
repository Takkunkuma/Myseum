import SwiftUI
import Photos
import AVKit

/// Identifiable payload so an event card can present a full-screen viewer.
struct AssetCollection: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    let startIndex: Int
    let eventID: String
}

/// Full-screen, swipeable photo/video viewer with swipe-down-to-dismiss and a
/// "remove from this event" action.
struct PhotoViewerView: View {
    let collection: AssetCollection
    var onRemoved: (PHAsset) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset]
    @State private var index: Int
    @State private var dragY: CGFloat = 0
    @State private var showRemoveConfirm = false

    init(collection: AssetCollection, onRemoved: @escaping (PHAsset) -> Void = { _ in }) {
        self.collection = collection
        self.onRemoved = onRemoved
        _assets = State(initialValue: collection.assets)
        _index = State(initialValue: collection.startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(assets.enumerated()), id: \.offset) { offset, asset in
                    FullImageView(asset: asset).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .offset(y: dragY)

            HStack {
                Button { showRemoveConfirm = true } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding()
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding()
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    if value.translation.height > 0 && value.translation.height > abs(value.translation.width) {
                        dragY = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 140 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3)) { dragY = 0 }
                    }
                }
        )
        .confirmationDialog("Remove this photo from the event?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove from event", role: .destructive) { removeCurrent() }
        } message: {
            Text("It stays in your photo library — it just won't show under this event.")
        }
    }

    private var backgroundOpacity: Double {
        max(0.4, 1 - Double(dragY) / 600)
    }

    private func removeCurrent() {
        guard assets.indices.contains(index) else { return }
        let asset = assets[index]
        ExcludedPhotosStore.shared.exclude(eventID: collection.eventID, assetID: asset.localIdentifier)
        onRemoved(asset)

        var updated = assets
        updated.remove(at: index)
        if updated.isEmpty { dismiss(); return }
        assets = updated
        if index >= assets.count { index = assets.count - 1 }
    }
}

private struct FullImageView: View {
    let asset: PHAsset

    var body: some View {
        if asset.mediaType == .video {
            VideoAssetView(asset: asset)
        } else {
            PhotoAssetView(asset: asset)
        }
    }
}

private struct PhotoAssetView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: asset.localIdentifier) {
            PhotoMatcher.shared.requestFullImage(for: asset) { image = $0 }
        }
    }
}

private struct VideoAssetView: View {
    let asset: PHAsset
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: asset.localIdentifier) {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                guard let item else { return }
                DispatchQueue.main.async { player = AVPlayer(playerItem: item) }
            }
        }
    }
}
