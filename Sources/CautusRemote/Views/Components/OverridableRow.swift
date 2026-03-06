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
        case .global, .folder:  return .secondary
        case .connection:       return .orange
        }
    }

    var isOverrideState: Bool {
        if case .connection = self { return true }
        return false
    }
}

// MARK: - OverridableRow

/// A form row that shows an effective value, a source line, and an Override/Reset action.
///
/// Layout: Label / Value or Editor / ● Overridden | Inherited from X · Reset
///
/// The ● dot and inline Reset make the override state instantly scannable —
/// no checkbox, no tri-state picker, no visual clutter.
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
        VStack(alignment: .leading, spacing: 5) {
            // ── Label ──────────────────────────────────────────────────────
            Text(label)
                .font(.body)

            // ── Value or inline editor ─────────────────────────────────────
            if isOverridden {
                editor()
            } else {
                Text(effectiveDisplay)
                    .foregroundStyle(.primary)
            }

            // ── Source status + action on same line ────────────────────────
            // "● Overridden  ·  Reset"   or   "Inherited from prod  ·  Override"
            HStack(spacing: 6) {
                if isOverridden {
                    // Orange dot signals overridden state — scannable at a glance
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
                Text(source.label)
                    .font(.caption)
                    .foregroundStyle(source.color)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if isOverridden {
                    Button("Reset") { onReset() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Button("Override") { onOverride() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
