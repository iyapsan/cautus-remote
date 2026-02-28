# RDP Feature — Strategy, Spike Plan & Product Scope

Version: 3.0 (Final) — 2026-02-27

**Product mantra**: *"Cautus Remote: the RDP client that feels like a Mac app."*

---

## Strategic Decisions

| Decision | Choice |
|---|---|
| SSH | Stays — RDP is additive |
| Connection model | Unified with `ProtocolType { .ssh(SSHConfig) / .rdp(RDPConfig) }` |
| SPM architecture | Multi-module: `CautusRemote` → `CautusCore` / `CautusSSH` / `CautusRDP` / `CRDPBridge` |
| FreeRDP | Vendor as static library (full dep tree) |
| Distribution | Direct first, no App Store for v1 |
| Rendering | MTKView (v1) |
| Multi-monitor | Separate `NSWindow` per monitor — **deferred to post-v1** |
| Platform | ARM64 only for v1 |
| Pixel pipeline | FreeRDP BGRA32 → `MTLPixelFormat.bgra8Unorm` (one copy max) |

---

## Hidden Risks

### 1. Static Build — Full Dependency Tree
Not just `libfreerdp3.a`. Must build: `libwinpr`, `libfreerdp-client`, `libcrypto` + `libssl` (OpenSSL), possibly `libz`. Day 1 must produce a **standalone C binary that connects**, not just `.a` files.

### 2. Thread Isolation
FreeRDP runs its own event loop. Bridge must own a dedicated thread, push framebuffer + events via thread-safe queue to MainActor → MTKView. **No FreeRDP callbacks touching Swift directly.**

### 3. Framebuffer Format
Per-frame RGBA conversion destroys FPS. Target: BGRA32 → `bgra8Unorm` with zero-copy or single-copy texture upload. Measure `bytes copied per frame` on Day 4.

---

## CRDPBridge — Thin C API (7 functions)

```c
rdp_create()
rdp_connect()
rdp_poll()
rdp_send_input()
rdp_disconnect()
rdp_destroy()
rdp_get_stats()  // → { fps, dropped_frames, bytes_copied, width, height, state }
```

---

## Spike Artifacts

- [ ] `scripts/build_freerdp_static.sh` → `out/include/**`, `out/lib/*.a`, `out/licenses/**`
- [ ] `tools/rdp_test/` C program via `scripts/build_rdp_test.sh`
- [ ] `scripts/run_rdp_test.sh` → connect → 2 min → disconnect
- [ ] `rdp_test` supports args: `--host --user --pass --domain --port --sec`
- [ ] `rdp_test` logs: negotiated security, desktop size, time-to-first-frame, avg fps
- [ ] `rdp_test` passes 10 connect/disconnect cycles without crash

---

## 5-Day Solo Spike

### Pre-requisites
- [ ] Windows Server 2022 VM with RDP enabled
- [ ] CMake installed (`brew install cmake`)
- [ ] `xfreerdp3` CLI verified connecting to VM
- [ ] NLA + CredSSP validated manually via CLI

### Day 1–2: Static Build + C Test

- [ ] `scripts/build_freerdp_static.sh` produces deterministic `out/` folder
- [ ] `rdp_test` connects, authenticates, stays alive 2 min
- [ ] `rdp_test` clean disconnect
- [ ] Run with **AddressSanitizer**: no leaks/overflows
- [ ] License files collected in `out/licenses/`

**If this fails → STOP.**

### Day 3: CRDPBridge Minimal

- [ ] `CRDPBridge` SPM target compiles with `swift build`
- [ ] Swift app calls `rdp_create` / `rdp_connect` / `rdp_disconnect` / `rdp_destroy`
- [ ] Logs: desktop size + negotiated security protocol
- [ ] Runs under ASan (or `MallocScribble` / `MallocStackLogging`)

### Day 4: Screenshot

- [ ] Captures first frame → `screenshot.png`
- [ ] Logs: time-to-first-frame
- [ ] Logs: memory at start / end of 2-minute session
- [ ] Confirms pixel format: BGRA32 → `MTLPixelFormat.bgra8Unorm`
- [ ] Measures bytes copied per frame (goal: 1 copy max)

### Day 5: Live Render + Input

- [ ] MTKView displays session at **30+ fps** (sustained 3 min)
- [ ] **CPU < 25%** average over 3 minutes
- [ ] Keyboard: letters, modifiers (⌘/⌥/⇧), function keys, arrows, tab, esc
- [ ] ⌘C/⌘V maps to Ctrl+C/V in remote session
- [ ] Mouse: click, right-click, drag
- [ ] No UI freeze during connect
- [ ] 10 rapid connect/disconnect cycles without crash
- [ ] Memory growth < 5% over 5 minutes
- [ ] **Spike report written** with go/no-go verdict

---

## Go / No-Go Gate

| # | Criteria | Gate |
|---|---|---|
| 1 | Static lib builds on ARM64 macOS | ✅ Must |
| 2 | C test binary connects + auths | ✅ Must |
| 3 | Framebuffer renders in MTKView | ✅ Must |
| 4 | Keyboard + mouse input works | ✅ Must |
| 5 | 30+ fps sustained | ✅ Must |
| 6 | SPM integration clean | ✅ Must |
| 7 | Memory stable over 5 min (< 5%) | ✅ Must |
| 8 | No crash on 10 connect/disconnect cycles | ✅ Must |
| 9 | No UI freeze during connect | ✅ Must |
| 10 | CPU < 25% during render | ✅ Must |

**If any fails** → document blocker, evaluate alternatives, do NOT proceed.

---

## Product v1 Scope

### Phase A — "It connects and feels native"
- FreeRDP bridge
- Live render via MTKView
- Keyboard/mouse input (correct ⌘ → Ctrl mapping)
- Smooth resize (dynamic resolution, fallback to client-side scaling)
- **Certificate trust/deny UI** (enterprise users hit this immediately)

### Phase B — "It's usable daily"
- Clipboard sync (bidirectional)
- Saved connection profiles
- Auto-reconnect
- Session tabs integration

### Phase C — "Enterprise unlock"
- NLA / CredSSP in real AD environment
- RD Gateway

### Not v1
- Multi-monitor, audio/mic, folder redirection, printer/camera, perf toggles

### Timeline (After Spike)

| Phase | Duration |
|---|---|
| FreeRDP bridge + build | 3–4 weeks |
| Rendering + lifecycle | 2–3 weeks |
| Clipboard + profiles | 1–2 weeks |
| NLA + RD Gateway | 2 weeks |
| Polish + QA | 2 weeks |
| **Total** | **12–16 weeks** |

---

## Solo Engineering Rules

1. **C layer is dumb and thin** — 7 functions, no abstractions
2. **ASan from Day 1** — don't wait for mysterious crashes
3. **Build scripts are repeatable** — not "works on my machine"
4. **Expect week 2 pain** — compiles, connects, random crashes. Normal.
5. **Scope is the enemy** — every feature passes "feels like a Mac app"
6. **License compliance** — FreeRDP (Apache 2.0) + OpenSSL notices in app bundle
7. **Resize strategy** — dynamic resolution preferred, client-side scaling fallback
