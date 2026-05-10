# Feishu Monitor Shell Phase 1 Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working bootstrap for the new Feishu monitor architecture: a standalone local shell control server plus a WuKongIM monitor center page that can read and control that shell.

**Architecture:** Phase 1 does not attempt full Feishu runtime capture yet. It establishes the new boundary: `tools/feishu_monitor_shell` owns local runtime state and a loopback control API, while WuKongIM owns the operator UI and calls the shell over localhost with a shared token.

**Tech Stack:** Dart CLI (`dart:io`, `dart:convert`), Flutter desktop UI, Dio client, Flutter widget tests, Dart package tests

---

### Task 1: Standalone Shell Package Skeleton

**Files:**
- Create: `tools/feishu_monitor_shell/pubspec.yaml`
- Create: `tools/feishu_monitor_shell/bin/feishu_monitor_shell.dart`
- Create: `tools/feishu_monitor_shell/lib/src/shell_cli.dart`
- Create: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Create: `tools/feishu_monitor_shell/lib/src/shell_store.dart`
- Create: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Create: `tools/feishu_monitor_shell/test/shell_server_test.dart`
- Modify: `analysis_options.yaml`

- [ ] Define a persisted shell snapshot model with shell status, login status, hook status, queue counters, timestamps, and last error metadata.
- [ ] Write failing tests for `GET /status`, `GET /health`, and `POST /capture/start`.
- [ ] Implement a loopback-only HTTP server with bearer-token protection and JSON responses.
- [ ] Persist shell state to a runtime JSON file so the shell can resume its last known status.
- [ ] Exclude the standalone package from the root Flutter analyzer, because it has its own Dart package context.

### Task 2: Shell Launcher Convenience

**Files:**
- Create: `run_feishu_monitor_shell.bat`

- [ ] Add a Windows launcher that starts the shell server with a stable local port and token defaults suitable for development on the current machine.

### Task 3: WuKongIM Local Shell Client

**Files:**
- Create: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Create: `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
- Create: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`

- [ ] Write failing tests for shell status parsing and action endpoint calls.
- [ ] Implement a lightweight client that talks to the local shell on `127.0.0.1`.
- [ ] Parse shell status and health into Flutter-side models without depending on the deleted legacy monitor code.

### Task 4: WuKongIM Feishu Monitor Center Phase 1 Page

**Files:**
- Create: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `lib/modules/vip/vip_management_page.dart`
- Delete: `lib/modules/vip/feishu_monitor_rebuild_page.dart`
- Create: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Modify: `test/modules/vip/vip_management_page_test.dart`

- [ ] Write failing widget tests for offline shell status and refreshed shell status display.
- [ ] Implement a phase 1 center page that shows shell connectivity, login state, hook state, queue counters, and last update time.
- [ ] Add action buttons for refresh, start capture, stop capture, and runtime reload.
- [ ] Rewire the VIP management entry to open this real phase 1 center instead of the temporary rebuild placeholder.

### Task 5: Verification

**Files:**
- Verify: `tools/feishu_monitor_shell/test/shell_server_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/vip/vip_management_page_test.dart`

- [ ] Run `dart test` inside `tools/feishu_monitor_shell`.
- [ ] Run focused Flutter tests for the new shell client and monitor center page.
- [ ] Run `flutter analyze` at repo root.
