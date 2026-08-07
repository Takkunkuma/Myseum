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

    /// Photo/video counts for many events using a SINGLE library query.
    ///
    /// Fetches every asset timestamp across the events' combined span once, then
    /// binary-searches that sorted array per event — 1 query + N × O(log n) instead
    /// of N queries. Overlapping events are handled correctly because each event
    /// searches the shared array independently. Safe to call off the main actor.
    nonisolated static func photoCounts(for events: [HangoutEvent]) -> [String: Int] {
        guard let minStart = events.map(\.start).min(),
              let maxEnd = events.map(\.end).max(), maxEnd > minStart else { return [:] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            minStart as NSDate, maxEnd as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)
        var times: [TimeInterval] = []
        times.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate { times.append(date.timeIntervalSince1970) }
        }

        var counts: [String: Int] = [:]
        counts.reserveCapacity(events.count)
        for event in events {
            let lower = lowerBound(times, event.start.timeIntervalSince1970)
            let upper = upperBound(times, event.end.timeIntervalSince1970)
            counts[event.id] = max(0, upper - lower)
        }
        return counts
    }

    /// First index whose value is >= target.
    private nonisolated static func lowerBound(_ values: [TimeInterval], _ target: TimeInterval) -> Int {
        var low = 0, high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] < target { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// First index whose value is > target.
    private nonisolated static func upperBound(_ values: [TimeInterval], _ target: TimeInterval) -> Int {
        var low = 0, high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] <= target { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// Fast count of photos/videos in [start, end] without loading the assets.
    func count(from start: Date, to end: Date) -> Int {
        guard end > start else { return 0 }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate, end as NSDate
        )
        return PHAsset.fetchAssets(with: options).count
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
