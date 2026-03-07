import SwiftUI

struct EmptyInspectorView: View {
    var message: String = "No Selection.\nSelect a folder or connection to view configuration details."

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}
