import Foundation
import Observation

/// Photos the user removed from a specific event's log. Photos are matched to
/// events by timestamp, so "removing" one just excludes that asset from that
/// event — it stays in the photo library. Keyed by "<eventID>|<assetID>".
@MainActor
@Observable
final class ExcludedPhotosStore {
    static let shared = ExcludedPhotosStore()

    private let key = "excludedEventPhotos"
    private(set) var excluded: Set<String>

    init() {
        excluded = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func composite(_ eventID: String, _ assetID: String) -> String { "\(eventID)|\(assetID)" }

    func isExcluded(eventID: String, assetID: String) -> Bool {
        excluded.contains(composite(eventID, assetID))
    }

    func exclude(eventID: String, assetID: String) {
        excluded.insert(composite(eventID, assetID))
        persist()
    }

    func include(eventID: String, assetID: String) {
        excluded.remove(composite(eventID, assetID))
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(excluded), forKey: key)
    }
}
