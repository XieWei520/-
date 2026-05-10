# Feishu Monitor Shell Phase 2 Desktop Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the standalone shell from a localhost-only service into a real Windows desktop shell that can host Feishu Web login/runtime while still exposing the local control API for WuKongIM.

**Architecture:** Keep `tools/feishu_monitor_shell` as the shared runtime/control package. Add a separate Flutter Windows app package that embeds WebView2, starts the local control server in-process, persists runtime status, and writes richer shell state back to the shared snapshot consumed by WuKongIM.

**Tech Stack:** Flutter Windows app, `webview_windows`, shared Dart package, `path_provider`, Flutter widget tests where practical, Dart package tests

---

### Task 1: Shared Shell Runtime Enrichment

**Files:**
- Modify: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_store.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Modify: `tools/feishu_monitor_shell/test/shell_server_test.dart`

- [ ] Extend the persisted shell snapshot with runtime URL, page title, WebView availability, and shell app mode metadata.
- [ ] Add failing tests for the richer `/status` payload.
- [ ] Keep localhost control actions compatible while preserving the richer runtime fields.

### Task 2: Standalone Flutter Desktop Shell App

**Files:**
- Create: `tools/feishu_monitor_shell_app/**`
- Create: `run_feishu_monitor_shell_app.bat`
- Modify: `analysis_options.yaml`

- [ ] Scaffold a Windows-only Flutter app package for the shell.
- [ ] Add dependencies on `webview_windows`, `path_provider`, and the local `../feishu_monitor_shell` package.
- [ ] Build a shell window that loads Feishu Web and updates the shared snapshot with current page/runtime state.
- [ ] Start the localhost control server from the shell app so WuKongIM can talk to it while the window is open.

### Task 3: WuKongIM Monitor Center Phase 2 Surface

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] Add failing tests for the richer shell status fields.
- [ ] Show WebView runtime availability, current page title, and current runtime URL in the monitor center.
- [ ] Keep the current localhost control buttons working against the same shell API.

### Task 4: Verification

**Files:**
- Verify: `tools/feishu_monitor_shell/test/shell_server_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/vip/vip_management_page_test.dart`

- [ ] Run `dart test` inside `tools/feishu_monitor_shell`.
- [ ] Run focused Flutter tests for the monitor center surface.
- [ ] Run `flutter analyze` at repo root.
- [ ] Run `flutter analyze` inside `tools/feishu_monitor_shell_app`.
