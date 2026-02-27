import SwiftUI
import SwiftTerm

/// SwiftUI wrapper around SwiftTerm's AppKit `TerminalView`.
///
/// Bridges the NSView-based terminal into SwiftUI, handling:
/// - SSH output → terminal display (via `feed`)
/// - Keyboard input → SSH write (via `TerminalViewDelegate.send`)
/// - PTY resize events
struct TerminalHostView: NSViewRepresentable {
    let session: SSHSession
    let theme: TerminalTheme

    /// Whether this pane currently has focus
    let isFocused: Bool

    func makeNSView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator

        // Apply theme
        theme.apply(to: terminalView)

        // Start reading SSH output
        context.coordinator.startOutputTask(session: session, terminalView: terminalView)

        return terminalView
    }

    func updateNSView(_ terminalView: TerminalView, context: Context) {
        // Update focus
        if isFocused, let window = terminalView.window {
            window.makeFirstResponder(terminalView)
        }

        // Re-apply theme if changed
        theme.apply(to: terminalView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    // MARK: - Coordinator

    /// Bridges TerminalViewDelegate callbacks to the SSH session.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate {
        private let session: SSHSession
        private var outputTask: Task<Void, Never>?

        init(session: SSHSession) {
            self.session = session
            super.init()
        }

        deinit {
            outputTask?.cancel()
        }

        /// Start an async task that reads from the SSH output stream
        /// and feeds data to the terminal view.
        func startOutputTask(session: SSHSession, terminalView: TerminalView) {
            outputTask = Task { [weak self] in
                for await data in session.outputStream {
                    guard !Task.isCancelled, self != nil else { break }
                    let bytes = Array(data)
                    terminalView.feed(byteArray: bytes[...])
                }
            }
        }

        // MARK: - TerminalViewDelegate

        /// Called when the user types — forward to SSH session.
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            Task {
                try? await session.write(Data(data))
            }
        }

        /// Terminal wants to resize.
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            Task {
                try? await session.resize(cols: newCols, rows: newRows)
            }
        }

        func setTerminalTitle(source: TerminalView, title: String) {
            // TODO: Phase 4 — update tab title
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Optional: track CWD for smart features
        }

        func scrolled(source: TerminalView, position: Double) {
            // No action needed
        }

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
            }
        }

        func bell(source: TerminalView) {
            NSSound.beep()
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
            // Not supported in v1
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            // Not used in v1
        }
    }
}
