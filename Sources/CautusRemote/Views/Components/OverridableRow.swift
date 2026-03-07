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
/// Uses a ghosted inline editor when inheriting, and active editor when overridden.
struct OverridableRow<Editor: View>: View {
    let label: String
    let source: OverrideSource
    let isOverridden: Bool
    let editor: () -> Editor
    let onOverride: () -> Void
    let onReset: () -> Void

    init(
        _ label: String,
        source: OverrideSource,
        isOverridden: Bool,
        @ViewBuilder editor: @escaping () -> Editor,
        onOverride: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.label = label
        self.source = source
        self.isOverridden = isOverridden
        self.editor = editor
        self.onOverride = onOverride
        self.onReset = onReset
    }

    var body: some View {
        HStack(spacing: 8) {
            // Invisible placeholder to keep text alignment identical regardless of state
            Color.clear.frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                // ── Label ──────────────────────────────────────────────────────
                Text(label)
                    .font(.body)
                
                // ── Editor ─────────────────────────────────────────────────────
                editor()
                    .disabled(!isOverridden)
                    .opacity(isOverridden ? 1.0 : 0.65)
                
                // ── Source status + action on same line ────────────────────────
                HStack(spacing: 4) {
                    if isOverridden {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                    Text(source.label)
                        .font(.caption)
                        .foregroundStyle(source.color)
                    
                    Spacer(minLength: 8)
                    
                    if isOverridden {
                        Button("Reset") { onReset() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Button("Override") { onOverride() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isOverridden ? Color.accentColor.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            if isOverridden {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 3)
            }
        }
        .padding(.horizontal, -8)
    }
}
