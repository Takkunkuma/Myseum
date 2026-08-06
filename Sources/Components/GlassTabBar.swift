import SwiftUI

/// Floating, Liquid-Glass "island" tab bar (capsule). Uses the real glass effect
/// on iOS 26+, and falls back to a translucent material on earlier systems.
struct GlassTabBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .modifier(IslandGlass())
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Standalone circular glass "search" island shown next to the tab bar.
struct SearchIsland: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(IslandGlass())
    }
}

/// Applies the capsule glass background, gated by OS version.
private struct IslandGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
        }
    }
}
