import Foundation

/// The three top-level destinations. `rawValue` defines left→right order, which
/// drives the slide direction when switching tabs.
enum AppTab: Int, CaseIterable, Identifiable {
    case events
    case calendar
    case account

    var id: Int { rawValue }

    /// Initial tab on launch. Honors the `HL_TAB` env var (used for screenshot
    /// testing); defaults to Events.
    static var initial: AppTab {
        if let raw = ProcessInfo.processInfo.environment["HL_TAB"],
           let value = Int(raw), let tab = AppTab(rawValue: value) {
            return tab
        }
        return .events
    }

    var title: String {
        switch self {
        case .events:   return "Events"
        case .calendar: return "Calendar"
        case .account:  return "Account"
        }
    }

    var icon: String {
        switch self {
        case .events:   return "photo.stack"
        case .calendar: return "calendar"
        case .account:  return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .events:   return "photo.stack.fill"
        case .calendar: return "calendar"
        case .account:  return "person.crop.circle.fill"
        }
    }
}
