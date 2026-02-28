# Cautus Remote -- RDP v1 Product Requirements Document

Version: 1.0\
Positioning: Premium Minimalist macOS-Native Enterprise RDP Client

------------------------------------------------------------------------

## 1. Executive Summary

Cautus Remote RDP v1 aims to deliver a premium, minimalist, macOS-native
Remote Desktop (RDP) client tailored for enterprise professionals.\
The goal is parity with enterprise-grade usability standards while
maintaining a clean, modern macOS experience.\
SSH support is not part of this release scope.

## 2. Target Users

-   Enterprise IT administrators\
-   DevOps engineers\
-   Infrastructure and cloud engineers\
-   Security-conscious professionals accessing Windows environments

## 3. Core Principles

-   macOS-native experience (no Windows-style UI metaphors)\
-   Security-first architecture\
-   Minimalist UI with progressive disclosure\
-   Enterprise-ready feature set without feature bloat

## 4. Tier 1 -- Enterprise Core Requirements

### Protocol & Security

-   RDP 10+ protocol support\
-   Network Level Authentication (NLA)\
-   CredSSP\
-   TLS certificate validation with UI prompt\
-   Domain login support (DOMAIN`\username`{=tex})\
-   Secure credential storage via macOS Keychain\
-   RD Gateway support

### Display & Multi-Monitor

-   Fullscreen and windowed modes\
-   Fit-to-window scaling\
-   Native resolution mode\
-   Multi-monitor selection\
-   Dynamic resolution update on window resize

### Device Redirection (Minimal Set)

-   Clipboard sync (bidirectional)\
-   Local folder redirection\
-   Audio playback redirection\
-   Microphone redirection

### Profile System

-   Per-connection settings\
-   Folder-level default inheritance\
-   Gateway profile reuse\
-   Credential profile reuse

### Session Handling

-   Auto-reconnect\
-   Graceful disconnect\
-   Visual connection status indicator\
-   Optional restore last sessions on app relaunch

## 5. Tier 2 -- Premium macOS Polish

-   Touch ID unlock for credential vault\
-   Native macOS fullscreen (Spaces support)\
-   Retina-optimized rendering\
-   Smooth resizing with no flicker\
-   Dark mode support\
-   Trackpad gesture support\
-   Progressive disclosure for advanced settings

## 6. Non-Goals (Out of Scope for v1)

-   VNC support\
-   SSH integration\
-   Kubernetes/Docker integration\
-   Serial connections\
-   Printer and camera redirection\
-   Advanced performance tuning toggles beyond basic presets

## 7. Technical Architecture Overview

-   Core RDP engine via FreeRDP integration\
-   Swift wrapper abstraction layer\
-   Metal/CoreAnimation rendering pipeline\
-   Secure channel mapping for redirection\
-   Separate RDP session engine

## 8. Success Metrics

-   Stable multi-monitor support\
-   Reliable clipboard sync\
-   RD Gateway compatibility\
-   Under 30 seconds average connection setup time\
-   Zero critical crashes during 8-hour sessions

## 9. Launch Scope Summary

RDP-only application delivering:

-   Secure enterprise authentication\
-   Multi-monitor capability\
-   Clipboard and folder redirection\
-   Profile inheritance system\
-   Credential vault with Touch ID\
-   Premium macOS-native interface
