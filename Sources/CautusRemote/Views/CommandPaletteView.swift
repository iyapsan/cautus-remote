import SwiftUI

/// Command palette overlay — floating search bar for quick navigation.
///
/// Triggered by ⌘K. Shows filtered results from CommandDispatcher
/// with keyboard navigation (↑/↓, Enter, Escape).
struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState

    @State private var results: [PaletteResult] = []

    private var dispatcher: CommandDispatcher {
        CommandDispatcher(appState: appState)
    }

    var body: some View {
        @Bindable var palette = appState.palette

        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField("Type a command or connection name...", text: $palette.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        executeSelected()
                    }

                if !palette.query.isEmpty {
                    Button {
                        palette.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                // Keyboard shortcut hint
                Text("esc")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !results.isEmpty {
                Divider()

                // Results list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.prefix(Layout.paletteMaxResults).enumerated()), id: \.element.id) { index, result in
                                PaletteResultRow(
                                    result: result,
                                    isSelected: index == palette.selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    palette.selectedIndex = index
                                    executeSelected()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: palette.selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else if !palette.query.isEmpty {
                Divider()

                // No results
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.quaternary)
                    Text("No results for \"\(palette.query)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
            }
        }
        .frame(width: Layout.paletteWidth)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Layout.paletteCornerRadius))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        .padding(.top, 50)
        .onExitCommand {
            appState.palette.hide()
        }
        .onKeyPress(.upArrow) {
            palette.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            palette.selectNext()
            return .handled
        }
        .onChange(of: palette.query) { _, _ in
            updateResults()
        }
        .onAppear {
            updateResults()
        }
    }

    // MARK: - Actions

    private func updateResults() {
        results = dispatcher.search(query: appState.palette.query)
        appState.palette.results = results
        appState.palette.selectedIndex = 0
    }

    private func executeSelected() {
        guard let result = results.indices.contains(appState.palette.selectedIndex)
            ? results[appState.palette.selectedIndex] : results.first else { return }

        Task {
            await dispatcher.dispatch(result.action)
        }
    }
}

// MARK: - Result Row

/// Single result row in the command palette.
struct PaletteResultRow: View {
    let result: PaletteResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: result.icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action hint for selected
            if isSelected {
                Text("↵")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }
}
