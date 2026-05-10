# Feishu Monitor Shell Phase 3 Probing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first real runtime probing slice for the new Feishu desktop shell: page probe metadata, conversation observation contract, and localhost endpoints that WuKongIM can read.

**Architecture:** Keep message capture out of scope for this slice. Instead, phase 3 establishes the observation contract the later capture pipeline will depend on: the shell can probe the current page via WebView script execution, persist structured probe results and discovered conversation candidates, expose them via localhost endpoints, and WuKongIM can display the observation results.

**Tech Stack:** Shared Dart runtime package, Flutter Windows shell app, `webview_windows` script execution, Flutter widget tests, Dart package tests

---

### Task 1: Shared Probe Models And Endpoints

**Files:**
- Modify: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Modify: `tools/feishu_monitor_shell/test/shell_server_test.dart`

- [ ] Add probe result fields for current page kind, probe timestamp, and observed conversations.
- [ ] Add failing tests for `GET /conversations` and richer `GET /status`.
- [ ] Expose the observed conversation list over localhost without breaking existing endpoints.

### Task 2: Desktop Shell Page Probe

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Create: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`

- [ ] Write failing tests for page kind detection and lightweight conversation extraction from probed JSON payloads.
- [ ] Implement a small probing helper that runs JavaScript in the WebView and normalizes the result.
- [ ] Persist page probe metadata and discovered conversation candidates into the shared shell snapshot.

### Task 3: WuKongIM Observation Surface

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] Add failing tests for probe metadata and observed conversation parsing.
- [ ] Show current page kind, last probe time, and a short observed-conversation list in the monitor center.
- [ ] Keep the phase 2 shell runtime surface intact while adding the new probe information.

### Task 4: Verification

**Files:**
- Verify: `tools/feishu_monitor_shell/test/shell_server_test.dart`
- Verify: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
- Verify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/vip/vip_management_page_test.dart`

- [ ] Run `dart test` inside `tools/feishu_monitor_shell`.
- [ ] Run focused Flutter tests inside `tools/feishu_monitor_shell_app`.
- [ ] Run focused Flutter tests for WuKongIM monitor center pages.
- [ ] Run `flutter analyze` at repo root.
- [ ] Run `flutter analyze` inside `tools/feishu_monitor_shell_app`.
