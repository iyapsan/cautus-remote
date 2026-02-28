# Cautus Remote -- RDP v1 Engineering PRD & Technical Architecture

Version 1.1 -- Expanded Engineering Specification

------------------------------------------------------------------------

## 1. Scope

Deliver a premium, minimalist, macOS-native enterprise RDP client
supporting RDP 10+, RD Gateway, multi-monitor, secure credential vault,
device redirection, and profile inheritance.\
SSH and other protocols are out of scope for v1.

------------------------------------------------------------------------

## 2. Functional Requirements with Acceptance Criteria

### 2.1 Protocol & Security

**Requirements** - RDP 10+ protocol via FreeRDP core\
- Network Level Authentication (NLA)\
- CredSSP authentication\
- TLS certificate validation UI\
- DOMAIN`\username `{=tex}login support\
- Secure Keychain credential storage\
- RD Gateway support

**Acceptance Criteria** - Successful connection to Windows Server
2019/2022 and Windows 10/11\
- Certificate mismatch prompts trust/reject UI\
- Domain authentication succeeds in AD environment\
- Gateway connection succeeds via HTTPS (443)\
- No plaintext credential storage

------------------------------------------------------------------------

### 2.2 Display & Multi-Monitor

**Requirements** - Fullscreen and windowed modes\
- Fit-to-window scaling\
- Native resolution option\
- Multi-monitor selection\
- Dynamic resolution update on resize

**Acceptance Criteria** - Resolution updates within 500ms of resize\
- No flicker across monitors\
- Crisp Retina rendering

------------------------------------------------------------------------

### 2.3 Device Redirection

**Requirements** - Bidirectional clipboard\
- Local folder redirection\
- Audio playback redirection\
- Microphone redirection

**Acceptance Criteria** - 10MB+ clipboard copy without corruption\
- File drag \<100MB succeeds\
- Audio latency \<250ms\
- Microphone detected in Windows settings

------------------------------------------------------------------------

### 2.4 Profile & Inheritance System

**Requirements** - Folder-level default inheritance\
- Per-connection overrides\
- Reusable credential profiles\
- Reusable gateway profiles

**Acceptance Criteria** - Parent updates propagate correctly\
- Overrides remain intact\
- Credential profile updates reflect instantly

------------------------------------------------------------------------

### 2.5 Session Handling

**Requirements** - Auto-reconnect\
- Graceful disconnect\
- Visual status indicator\
- Optional restore previous sessions

**Acceptance Criteria** - Network drop \<10s auto-recovers\
- Clean server termination on disconnect\
- Status indicator updates within 1s

------------------------------------------------------------------------

# Technical Architecture Deep-Dive

## 3. High-Level Architecture

### UI Layer (SwiftUI)

-   Connection management\
-   Profile editor\
-   Session tabs

### Session Controller Layer

-   RDP lifecycle management\
-   Reconnect logic\
-   Redirection channel management

### RDP Engine Layer

-   FreeRDP integration via C bridge\
-   Protocol handling\
-   Secure channel mapping

### Rendering Layer

-   Metal/CoreAnimation-backed renderer\
-   Frame buffer handling\
-   Multi-monitor mapping

### Persistence Layer

-   SwiftData for metadata\
-   macOS Keychain for credentials

------------------------------------------------------------------------

## 4. FreeRDP Integration Strategy

-   Embed FreeRDP as dependency\
-   Swift wrapper around `freerdp_context`\
-   Map callbacks to Swift async streams\
-   Isolate C bindings in dedicated module\
-   Ensure thread-safe lifecycle management

------------------------------------------------------------------------

## 5. Security Architecture

-   Credentials stored in Keychain\
-   TLS validation required by default\
-   Optional Touch ID gating\
-   No plaintext credential caching\
-   Sandboxed file access for folder redirection

------------------------------------------------------------------------

## 6. Performance Targets

-   8-hour sustained session stability\
-   \<500MB memory per session\
-   Clipboard latency \<200ms\
-   60fps multi-monitor rendering

------------------------------------------------------------------------

## 7. Testing Strategy

-   Unit tests for inheritance logic\
-   Integration tests with Windows lab\
-   Automated stress testing\
-   Network simulation (latency/packet loss)\
-   Enterprise UAT with AD + RD Gateway

------------------------------------------------------------------------

## 8. Future Extensibility (Post v1)

-   Printer & camera redirection\
-   Azure Virtual Desktop support\
-   Session recording\
-   VNC module (separate engine)
