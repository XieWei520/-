# Feishu Local Agent One-Click Bind Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Windows desktop one-click action that generates or reuses a pairing code, runs the local Feishu Monitor Agent pair command, sends one heartbeat, and refreshes the page.

**Architecture:** Keep the UI testable by injecting a `LocalAgentBinder` callback into `FeishuMonitorCenterPage`. The default desktop implementation lives in a focused service that invokes the bundled Dart Agent CLI with `Process.run`, sanitizes output, and never exposes the Agent token. Web and non-Windows platforms fail gracefully with a user-facing message.

**Tech Stack:** Flutter/Dart desktop, widget tests, Dart `Process.run`, existing `tools/feishu_monitor_agent` CLI.

---

### Task 1: Add local Agent binder service

**Files:**
- Create: `lib/modules/monitor/monitor_local_agent_binder.dart`
- Test: `test/modules/monitor/monitor_local_agent_binder_test.dart`

- [ ] Write failing unit tests for unsupported platform behavior and sanitized command failure.
- [ ] Implement `LocalAgentBindRequest`, `LocalAgentBindResult`, `LocalAgentBindException`, and `MonitorLocalAgentBinder`.
- [ ] Use an injectable process runner and platform detector so tests do not run real commands.
- [ ] Run: `flutter test test/modules/monitor/monitor_local_agent_binder_test.dart`.

### Task 2: Wire one-click button into Feishu monitor page

**Files:**
- Modify: `lib/modules/monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/monitor/feishu_monitor_center_page_test.dart`

- [ ] Write failing widget test: tapping one-click bind auto-generates a pairing code, calls the injected binder, and reloads the snapshot.
- [ ] Add `LocalAgentBinder? onBindLocalAgent` to the page.
- [ ] Add loading state and a button labeled `一键绑定并上线` in the Agent onboarding card.
- [ ] On success, show snackbar and call `_refresh()`.
- [ ] On failure, show sanitized error and keep current pairing code visible.
- [ ] Run: `flutter test test/modules/monitor/feishu_monitor_center_page_test.dart test/modules/monitor/monitor_local_agent_binder_test.dart`.

### Task 3: Verify and run desktop app

**Files:**
- No new source files beyond tasks above.

- [ ] Run: `flutter analyze lib/modules/monitor/feishu_monitor_center_page.dart lib/modules/monitor/monitor_local_agent_binder.dart`.
- [ ] Re-run existing monitor API tests.
- [ ] Start `flutter run -d windows` from the feature worktree and confirm the app connects to production.
- [ ] Commit with message `feat: add feishu one-click local agent bind`.