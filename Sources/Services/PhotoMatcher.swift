import Foundation
import Photos
import UIKit

/// Wraps PhotoKit: requests access and finds the photos/videos captured within
/// an event's time window (matched purely by `creationDate`).
@MainActor
final class PhotoMatcher {
    static let shared = PhotoMatcher()

    private let imageManager = PHCachingImageManager()

    func requestAccess() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// All photo + video assets with a creationDate inside [start, end], oldest first.
    func assets(from start: Date, to end: Date) -> [PHAsset] {
        guard end > start else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate, end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func requestThumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    func requestFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }
}
