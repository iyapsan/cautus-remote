import SwiftUI

// MARK: - Source Badge

enum OverrideSource {
    case global
    case folder(name: String)
    case connection

    var label: String {
        switch self {
        case .global:           return "Inherited from Global"
        case .folder(let n):    return "Inherited from \(n)"
        case .connection:       return "Overridden"
        }
    }

    var color: Color {
        switch self {
        case .global:           return .secondary
        case .folder:           return .secondary
        case .connection:       return .orange
        }
    }
}

// MARK: - OverridableRow

/// A form row that shows an effective value, a source badge, and an Override/Reset button.
/// The architecture (blobs, resolver) is unchanged. This is purely a display layer.
///
/// Usage:
///   OverridableRow("Clipboard", effectiveDisplay: "Enabled", source: .folder("prod")) {
///       // shown when override is active
///       Toggle("Clipboard", isOn: $someBinding)
///   } onOverride: {
///       // set the override to the current effective value when user taps Override
///   } onReset: {
///       // clear the override
///   }
struct OverridableRow<Editor: View>: View {
    let label: String
    let effectiveDisplay: String
    let source: OverrideSource
    let isOverridden: Bool
    let editor: () -> Editor
    let onOverride: () -> Void
    let onReset: () -> Void

    init(
        _ label: String,
        effectiveDisplay: String,
        source: OverrideSource,
        isOverridden: Bool,
        @ViewBuilder editor: @escaping () -> Editor,
        onOverride: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.label = label
        self.effectiveDisplay = effectiveDisplay
        self.source = source
        self.isOverridden = isOverridden
        self.editor = editor
        self.onOverride = onOverride
        self.onReset = onReset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body)
                    if isOverridden {
                        // Show the live editor inline
                        editor()
                            .padding(.top, 2)
                    } else {
                        Text(effectiveDisplay)
                            .foregroundStyle(.primary)
                    }
                    Text(source.label)
                        .font(.caption)
                        .foregroundStyle(source.color)
                }

                Spacer()

                if isOverridden {
                    Button("Reset") { onReset() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                } else {
                    Button("Override") { onOverride() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
