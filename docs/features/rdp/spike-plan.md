# RDP Feature — Strategy, Spike Plan & Product Scope

Version: 2.0 — 2026-02-27

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
| Multi-monitor | Separate `NSWindow` per monitor — but **deferred to post-v1** |
| Platform | ARM64 only for v1 (Intel later if needed) |

---

## Hidden Risks

### 1. FreeRDP Static Build — Full Dependency Tree
Not just `libfreerdp3.a`. Must build:
- `libwinpr` (utility layer)
- `libfreerdp-client`
- `libcrypto` + `libssl` (OpenSSL static)
- Possibly `libz`

**Day 1 must produce**: a standalone C binary that connects, not just `.a` files.

### 2. FreeRDP Thread Model
FreeRDP runs its own internal event loop. Callbacks cannot touch Swift UI directly.

```
RDPThread (C)
   ├── FreeRDP event loop
   ├── Framebuffer callback
   └── Input channel
        │
        V
   Thread-safe queue
        │
        V
   MainActor → MTKView
```

### 3. Framebuffer Format & Performance
- Pixel format may not match Metal's preferred texture format (BGRA vs RGBA)
- Per-frame conversion destroys FPS
- Must achieve **zero-copy or minimal-copy** texture upload

---

## CRDPBridge — Thin C API Contract

```c
rdp_create()
rdp_connect()
rdp_poll()
rdp_send_input()
rdp_disconnect()
rdp_destroy()
```

Keep C as protocol adapter. Keep logic in Swift.

---

## 5-Day Solo Spike

### Pre-requisites
- [ ] Windows Server 2022 VM with RDP enabled
- [ ] CMake installed (`brew install cmake`)
- [ ] `xfreerdp3` CLI verified connecting to VM
- [ ] FreeRDP source built via CMake with `-DBUILD_SHARED_LIBS=OFF`
- [ ] NLA + CredSSP validated manually via CLI

### Daily Goals

| Day | Goal | Deliverable |
|---|---|---|
| **1–2** | FreeRDP static + C test binary | `rdp_test` CLI connects, auths, runs 2 min, disconnects cleanly. **No Swift.** |
| **3** | CRDPBridge minimal | Swift app calls C, connects, logs desktop size + security protocol, disconnects |
| **4** | Screenshot mode | Capture first framebuffer → save PNG. Measure time-to-first-frame + memory over 2 min |
| **5** | Live render + input | MTKView at 30+ fps, keyboard/mouse works, 3-min stability test |

### Go / No-Go Criteria

| Criteria | Gate |
|---|---|
| Static lib builds on ARM64 macOS | ✅ Must |
| C test binary connects + auths to Windows VM | ✅ Must |
| Framebuffer renders in Metal view | ✅ Must |
| Keyboard + mouse input (incl. modifiers) | ✅ Must |
| 30+ fps sustained | ✅ Must |
| SPM integration clean | ✅ Must |
| Memory stable over 5 min (< 5% growth) | ✅ Must |
| No crash on 10 rapid connect/disconnect cycles | ✅ Must |
| No UI freeze during connect | ✅ Must |
| CPU < 25% during render | ✅ Must |

**If any "Must" fails** → document blocker, evaluate alternatives, do NOT proceed.

---

## Product v1 Scope — "Good + Easy to Use"

Users judge in 60 seconds: **connect friction**, **display feel**, **input correctness**, **clipboard**.

### Phase A — "It connects and feels native"
- FreeRDP bridge
- Live render via MTKView
- Keyboard/mouse input (correct modifier mapping)
- Smooth resize (dynamic resolution)

### Phase B — "It's usable daily"
- Clipboard sync (bidirectional)
- Saved connection profiles
- Auto-reconnect
- Certificate trust/deny UI

### Phase C — "Enterprise unlock"
- NLA / CredSSP in real AD environment
- RD Gateway

### Not v1
- Multi-monitor
- Audio/mic redirection
- Folder redirection
- Printer/camera
- Performance tuning toggles

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

1. **C layer must be dumb and thin** — 6 functions max
2. **Don't ask AI to debug C crashes** — use `lldb` + address sanitizer
3. **Expect week 2 pain** — it compiles, connects, then random crashes. This is normal.
4. **Scope is the enemy** — every feature must pass the "feels like a Mac app" bar
5. **License compliance** — FreeRDP (Apache 2.0) + OpenSSL notices in app bundle
