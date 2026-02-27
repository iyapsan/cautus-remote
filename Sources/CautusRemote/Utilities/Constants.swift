import SwiftUI

/// Layout constants matching the UI specification.
enum Layout {
    // MARK: - Window

    static let minWindowWidth: CGFloat = 1100
    static let minWindowHeight: CGFloat = 700

    // MARK: - Sidebar

    static let sidebarDefaultWidth: CGFloat = 260
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarMaxWidth: CGFloat = 360
    static let sidebarRowHeight: CGFloat = 30

    // MARK: - Status Dot

    static let statusDotSize: CGFloat = 7
    static let cornerRadius: CGFloat = 6

    // MARK: - Spacing

    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24

    // MARK: - Animation

    static let animationDuration: Double = 0.15  // 150ms

    static var defaultAnimation: Animation {
        .easeInOut(duration: animationDuration)
    }

    // MARK: - Command Palette

    static let paletteWidth: CGFloat = 500
    static let paletteCornerRadius: CGFloat = 12
    static let paletteMaxResults: Int = 10
}
