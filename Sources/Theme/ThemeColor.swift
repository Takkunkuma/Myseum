import SwiftUI

/// User-selectable accent color, persisted in `@AppStorage("themeColorRaw")`
/// and applied as the app's `.tint` at the root.
enum ThemeColor: String, CaseIterable, Identifiable {
    case indigo
    case blue
    case teal
    case green
    case terracotta
    case orange
    case pink
    case purple

    var id: String { rawValue }

    static let storageKey = "themeColorRaw"
    static let `default` = ThemeColor.indigo

    static func current(from raw: String) -> ThemeColor {
        ThemeColor(rawValue: raw) ?? .default
    }

    var title: String {
        switch self {
        case .terracotta: return "Terracotta"
        default:          return rawValue.capitalized
        }
    }

    var color: Color {
        switch self {
        case .indigo:     return .indigo
        case .blue:       return .blue
        case .teal:       return .teal
        case .green:      return Color(red: 0.20, green: 0.65, blue: 0.40)
        case .terracotta: return Color(red: 0.80, green: 0.36, blue: 0.27)
        case .orange:     return .orange
        case .pink:       return .pink
        case .purple:     return .purple
        }
    }
}
