# Cautus Remote — UI Specification

**Version:** 1.0
**Date:** 2026-02-21
**Platform:** macOS 14+
**Design Intent:** Premium productivity vibe, clutter-free, macOS-native, follows system appearance.

---

## 1. UI North Star

A calm infrastructure cockpit:
- **One window**
- **Minimal chrome**
- **Keyboard-first**
- **Progressive disclosure**
- **Subtle status indicators**
- **System light/dark mode** only (v1)

Non-goals (v1):
- No custom themes
- No always-visible "power toolbars"
- No floating session windows
- No dense table-heavy admin UI

---

## 2. Global Layout Rules

### 2.1 Windowing

- **Single main window** only.
- Sessions must open as **tabs** within main window.
- Splits are **inside** the main window content area.

### 2.2 Visual Density

- Default density is **comfortable**, not compact.
- Prefer whitespace over dividers.
- Use separators sparingly and with low contrast.

### 2.3 Typography

- UI: SF Pro (system)
- Terminal: SF Mono (default)
- Sidebar row height: **28–32pt** (system-appropriate)
- Section headers: small, subdued (no large banners)

### 2.4 Color & Appearance

- Follow system appearance (Light/Dark).
- Use system accent for selection.
- Status colors allowed only for **small indicators** and only when meaningful.

### 2.5 Spacing System

- Base spacing unit: **8pt**
- Common paddings:
  - Small: 8pt
  - Medium: 16pt
  - Large: 24pt

### 2.6 Animation

- Duration target: **120–180ms**
- Use subtle easing; no bouncy animations.

---

## 3. Main Window Anatomy

### 3.1 Structure

```
MainWindow
 ├── Toolbar (minimal)
 ├── Sidebar (collapsible)
 └── ContentArea
      ├── TabBar
      └── Workspace
```

### 3.2 Minimum Sizes

- Minimum window width: **1100pt**
- Minimum window height: **700pt**
- Sidebar default width: **260pt**
- Sidebar min width: **220pt**
- Sidebar max width: **360pt**

### 3.3 Toolbar (Minimal)

**Visible controls are intentionally limited.**

Layout:
- Left:
  - Sidebar toggle button
- Right:
  - Command palette button (⌘K)
  - New connection button (+)

Rules:
- No additional persistent toolbar buttons in v1.
- Any extra actions must be accessible via:
  - Context menus
  - Command palette
  - Tab dropdown menus

---

## 4. Sidebar Specification

### 4.1 Sidebar Sections (Order)

1. Search Field (top, sticky)
2. Favorites (collapsible)
3. All Connections (collapsible; hierarchical folders)
4. Tags (collapsible)
5. Recents (collapsible)

### 4.2 Sidebar Row Content

Row structure:

```
[StatusDot] [Icon(optional)] [Name]                [Disclosure(optional)]
```

Rules:
- Icons are optional and must be **subtle** (SF Symbols, monochrome).
- Prefer text and hierarchy over icons.
- Disclosure indicators only for folders.

### 4.3 Subtle Status Indicators

Dot size: **6–8px**, vertically centered.

States:
- Connected: green dot
- Reconnecting: yellow dot (may pulse subtly)
- Failed: red dot
- Inactive: no dot (preferred) or neutral gray

Display rules:
- Show dot **only** for active sessions and recently failed.
- Do **not** show dots for every stored connection by default.
- Failure dots should clear automatically when user reconnects or dismisses.

### 4.4 Sidebar Interactions

- Single click selects.
- Double click opens a session (or Enter).
- Context menu (right click):
  - Open
  - Open in New Tab
  - Open in Split (Left/Right/Down)
  - Edit
  - Duplicate
  - Move to Folder
  - Add/Remove Favorite
  - Delete

Drag & drop:
- Reorder within folder
- Move between folders
- Drag to Favorites adds shortcut (not duplicate)

---

## 5. Tab Bar Specification

### 5.1 Tab Behavior

- Native macOS tab styling.
- Close button visible on hover.
- Drag to reorder.
- Drag a tab to edge of workspace to create split.

### 5.2 Tab Context Menu / Dropdown

Required actions:
- Reconnect
- Duplicate Session
- Reveal in Sidebar
- Edit Connection
- Close Tab

### 5.3 Tab State Indicators

- When connecting: subtle spinner or dimmed title (not both).
- When failed: small warning glyph in tab (subtle), not a big banner.
- When reconnecting: spinner only.

---

## 6. Workspace Modes

### 6.1 Mode A: Empty State (No Active Sessions)

Centered content, premium feel.

Content:
- Title: "No Active Sessions"
- Primary button: "New Connection"
- Secondary: "Quick Connect" field (host/user optional)
- Below: "Recent Connections" as **cards** or a clean list (not a dense table)

Rules:
- No cluttered onboarding checklists.
- Keep calm and sparse.

### 6.2 Mode B: Active SSH Session

- Terminal is **full-bleed** (SwiftTerm `TerminalView` via `NSViewRepresentable`).
- No persistent action toolbar.
- Optional collapsible status strip at bottom (off by default).

Terminal header:
- Minimal: just session title in tab.
- Any extra session actions are in tab dropdown/context menu or ⌘K.

### 6.3 Mode C: Split Sessions

- Split container supports:
  - Vertical split (side-by-side)
  - Horizontal split (stacked)
- Max panes: **4** (2×2 grid max).
- Backed by `NSSplitView` for native resize behavior.

Divider:
- 1px line
- Hover highlight while resizing
- Drag handles should feel like native NSSplitView

Focus:
- Active pane has subtle focus ring or brightness emphasis.
- Keyboard shortcuts switch focus between panes.

---

## 7. Command Palette (⌘K)

### 7.1 Invocation

- Shortcut: ⌘K
- Toolbar button triggers same UI.

### 7.2 Visual

- Centered overlay sheet/panel.
- Rounded corners, subtle shadow.
- Background dim: subtle (avoid heavy blackout).

### 7.3 Capabilities (v1 Required)

- Search/open connections
- Switch tabs
- Reconnect current session
- Duplicate session
- Split pane commands
- Edit selected connection
- New connection

### 7.4 Result Ordering

- Exact match > prefix > fuzzy
- Favorites boosted
- Recents boosted

---

## 8. Connection Sheet (Create/Edit)

### 8.1 Presentation

- Use macOS **sheet** modal (attached to window).
- No separate settings window for connection editing.

### 8.2 Information Architecture

**Basic (always visible):**
- Name
- Host
- Port (default 22)
- Username
- Auth Method (Password / Key)
- Key selection (if applicable)
- Jump Host (dropdown)

**Advanced (collapsible "Advanced ▸"):**
- Keepalive interval
- Connection timeout
- Terminal overrides (font size, scrollback)
- Env vars (optional)

Rules:
- No multi-tab "monster" dialog.
- Advanced is collapsed by default.

---

## 9. Notifications & Errors

### 9.1 Error Presentation

- Non-blocking banners/toasts preferred.
- No modal alerts unless data loss or security-critical.
- Errors should provide:
  - What happened
  - Suggested action (Reconnect / Edit / Copy error)

### 9.2 Reconnect UX

- Offer single-click reconnect.
- Avoid repeated popups.
- Failed status appears via:
  - Sidebar dot (red)
  - Subtle tab indicator

---

## 10. Keyboard Shortcuts (Minimum Set)

| Shortcut | Action |
|----------|--------|
| ⌘K | Command palette |
| ⌘N | New connection (or new session if a connection selected) |
| ⌘W | Close tab |
| ⌘T | New tab (optional: quick connect) |
| ⌘1..⌘9 | Switch tab (optional, macOS convention) |
| ⌘⌥← / ⌘⌥→ | Switch focus between split panes |
| ⌘⌥S | Split (prompt orientation) (optional) |
| Enter | Open selected connection |
| ⌘F | Search within sidebar/library (optional) |

---

## 11. Accessibility Requirements

- Full keyboard navigation
- VoiceOver labels for:
  - Sidebar rows
  - Status dots (state conveyed via accessibility label)
  - Tabs and split panes
  - Command palette results
- Respect system text size settings where applicable

---

## 12. Anti-Clutter Guardrails (Hard Constraints)

1. No more than **3** persistent toolbar controls (sidebar toggle, ⌘K, +).
2. No "always-visible" session action bar.
3. No floating session windows.
4. No dense tables as the primary library UI.
5. No exposing advanced settings by default.
6. Any extra actions must be discoverable via ⌘K or context menus.

---

## 13. UI Acceptance Criteria

The UI spec is met when:
- App is single-window with tabs and split panes.
- Toolbar remains minimal and unchanged in v1.
- Sidebar shows hierarchy with subtle status dots only for active/failed sessions.
- Command palette reliably handles core navigation and actions.
- Connection editing uses a sheet with "Advanced ▸" collapsed by default.
- Empty state is calm, minimal, and premium.
- No visual clutter emerges in normal workflows (10+ connections, 5+ sessions).
