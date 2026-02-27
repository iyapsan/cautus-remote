import SwiftUI
import SwiftTerm

/// Terminal color theme and font configuration.
///
/// Defines the visual appearance for terminal views.
/// v1 ships with a dark theme matching the app's aesthetic.
struct TerminalTheme: Equatable {
    let name: String
    let fontName: String
    let fontSize: CGFloat
    let foreground: NSColor
    let background: NSColor
    let cursor: NSColor
    let selectionBackground: NSColor
    let ansiColors: [NSColor]  // 16 ANSI colors (0-15)

    /// Apply this theme to a SwiftTerm `TerminalView`.
    func apply(to terminal: TerminalView) {
        // Font
        if let font = NSFont(name: fontName, size: fontSize) {
            terminal.font = font
        }

        // Colors
        terminal.nativeForegroundColor = foreground
        terminal.nativeBackgroundColor = background
        terminal.caretColor = cursor
        terminal.selectedTextBackgroundColor = selectionBackground
    }
}

// MARK: - Built-in Themes

extension TerminalTheme {
    /// Default dark theme — matches the app's dark aesthetic.
    static let midnight = TerminalTheme(
        name: "Midnight",
        fontName: "SF Mono",
        fontSize: 13,
        foreground: NSColor(red: 0.85, green: 0.87, blue: 0.91, alpha: 1.0),   // #D9DEE8
        background: NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1.0),   // #12121A
        cursor: NSColor(red: 0.40, green: 0.60, blue: 1.00, alpha: 1.0),       // #6699FF
        selectionBackground: NSColor(red: 0.20, green: 0.25, blue: 0.40, alpha: 0.5),
        ansiColors: [
            // Standard (0-7)
            NSColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0),  // Black
            NSColor(red: 0.87, green: 0.32, blue: 0.36, alpha: 1.0),  // Red
            NSColor(red: 0.35, green: 0.76, blue: 0.50, alpha: 1.0),  // Green
            NSColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 1.0),  // Yellow
            NSColor(red: 0.40, green: 0.60, blue: 1.00, alpha: 1.0),  // Blue
            NSColor(red: 0.75, green: 0.45, blue: 0.90, alpha: 1.0),  // Magenta
            NSColor(red: 0.35, green: 0.80, blue: 0.85, alpha: 1.0),  // Cyan
            NSColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1.0),  // White
            // Bright (8-15)
            NSColor(red: 0.35, green: 0.37, blue: 0.42, alpha: 1.0),  // Bright Black
            NSColor(red: 0.95, green: 0.45, blue: 0.48, alpha: 1.0),  // Bright Red
            NSColor(red: 0.50, green: 0.87, blue: 0.62, alpha: 1.0),  // Bright Green
            NSColor(red: 0.95, green: 0.85, blue: 0.50, alpha: 1.0),  // Bright Yellow
            NSColor(red: 0.55, green: 0.72, blue: 1.00, alpha: 1.0),  // Bright Blue
            NSColor(red: 0.85, green: 0.60, blue: 0.95, alpha: 1.0),  // Bright Magenta
            NSColor(red: 0.50, green: 0.90, blue: 0.92, alpha: 1.0),  // Bright Cyan
            NSColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0),  // Bright White
        ]
    )

    /// Light theme for daytime use.
    static let daylight = TerminalTheme(
        name: "Daylight",
        fontName: "SF Mono",
        fontSize: 13,
        foreground: NSColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0),
        background: NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0),
        cursor: NSColor(red: 0.20, green: 0.40, blue: 0.90, alpha: 1.0),
        selectionBackground: NSColor(red: 0.70, green: 0.82, blue: 1.00, alpha: 0.4),
        ansiColors: [
            NSColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0),
            NSColor(red: 0.75, green: 0.15, blue: 0.20, alpha: 1.0),
            NSColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0),
            NSColor(red: 0.70, green: 0.55, blue: 0.10, alpha: 1.0),
            NSColor(red: 0.20, green: 0.40, blue: 0.90, alpha: 1.0),
            NSColor(red: 0.55, green: 0.25, blue: 0.70, alpha: 1.0),
            NSColor(red: 0.15, green: 0.60, blue: 0.65, alpha: 1.0),
            NSColor(red: 0.55, green: 0.57, blue: 0.60, alpha: 1.0),
            NSColor(red: 0.40, green: 0.42, blue: 0.45, alpha: 1.0),
            NSColor(red: 0.85, green: 0.25, blue: 0.30, alpha: 1.0),
            NSColor(red: 0.25, green: 0.65, blue: 0.35, alpha: 1.0),
            NSColor(red: 0.80, green: 0.65, blue: 0.20, alpha: 1.0),
            NSColor(red: 0.30, green: 0.50, blue: 0.95, alpha: 1.0),
            NSColor(red: 0.65, green: 0.35, blue: 0.80, alpha: 1.0),
            NSColor(red: 0.25, green: 0.70, blue: 0.75, alpha: 1.0),
            NSColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 1.0),
        ]
    )
}
