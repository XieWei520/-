# Feishu Monitor Center Console UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current single-column Feishu monitor diagnostics page with the approved console layout: top status overview, quick actions, and tabs for logs, forwarding rules, Feishu groups, image processing, and system settings.

**Architecture:** Keep existing shell client and forwarding service contracts. Refactor `FeishuMonitorCenterPage` into a page shell plus focused private widgets for overview metrics, quick actions, tab navigation, runtime logs, rules, groups, image settings, and system settings. Use current in-memory shell data for logs/rules/groups now, leaving backend rule persistence and real image processing for later phases.

**Tech Stack:** Flutter, existing WuKongIM design tokens, widget tests, existing Feishu shell client and forwarding service

---

### Task 1: Console Structure And Chinese Copy

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Update `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart` to assert the new first-screen structure:

```dart
expect(find.text('飞书信息监控中心'), findsOneWidget);
expect(find.text('状态总览'), findsOneWidget);
expect(find.text('壳程序'), findsOneWidget);
expect(find.text('飞书账号'), findsOneWidget);
expect(find.text('监听状态'), findsOneWidget);
expect(find.text('今日捕获'), findsOneWidget);
expect(find.text('今日成功'), findsOneWidget);
expect(find.text('今日失败'), findsOneWidget);
expect(find.text('快捷操作'), findsOneWidget);
expect(find.text('运行日志'), findsOneWidget);
expect(find.text('转发规则'), findsOneWidget);
expect(find.text('飞书群组'), findsOneWidget);
expect(find.text('图片处理'), findsOneWidget);
expect(find.text('系统设置'), findsOneWidget);
expect(find.textContaining('椋炰功'), findsNothing);
expect(find.textContaining('杞彂'), findsNothing);
```

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: FAIL because the page still uses the old card layout and contains garbled Chinese.

- [ ] **Step 2: Refactor the page shell**

In `feishu_monitor_center_page.dart`:

- Fix the import order to put `dart:async` before Flutter imports.
- Keep the existing injected `client`, `forwardingService`, and `forwardingSettingsStore`.
- Add `_selectedTab` state with values:
  - `logs`
  - `rules`
  - `groups`
  - `images`
  - `settings`
- Build the page body as:

```dart
ListView(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
  children: [
    _StatusOverview(status: status, loading: _loading, error: _error),
    const SizedBox(height: WKSpace.sm),
    _QuickActions(...),
    const SizedBox(height: WKSpace.sm),
    _ConsoleTabs(selected: _selectedTab, onChanged: ...),
    const SizedBox(height: WKSpace.sm),
    _ConsoleTabBody(...)
  ],
)
```

Use normal Chinese display text throughout.

- [ ] **Step 3: Verify structure test**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS for the new structure test; older assertions should be updated to the new UI.

### Task 2: Runtime Logs Tab

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing log tab tests**

Add a widget test that:

- verifies `运行日志` is selected by default
- expects a terminal-style log section with:
  - `全部`
  - `成功`
  - `错误`
  - `捕获`
  - `转发`
  - `feed_card_probe`
  - the first recent event text
- taps `转发规则` and verifies log-only text is no longer visible

Run the page test and confirm it fails before implementation.

- [ ] **Step 2: Implement log tab**

Create `_RuntimeLogsTab` that renders:

- a filter row
- action buttons `清空日志`, `导出日志`
- a dark terminal container
- rows derived from `status.recentEvents.take(12)`
- fallback rows when no events exist

The dark terminal container should use stable dimensions and text overflow handling.

- [ ] **Step 3: Verify log tab**

Run the page test and confirm PASS.

### Task 3: Forwarding Rules And Feishu Groups Tabs

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing rules/groups tests**

Add tests that:

- tap `转发规则`
- expect `新增规则`, `批量导入`, `下载模板`, `规则名称`, `来源飞书群`, `目标悟空IM群`
- expect the currently configured target group id to be shown
- tap `飞书群组`
- expect `刷新列表`, `聊天类型`, `群名称`, `飞书群 ID`, `最近消息`, `转发状态`
- expect observed conversation names from the fake status

Run the page test and confirm FAIL.

- [ ] **Step 2: Implement rules tab**

Create `_ForwardingRulesTab`:

- top toolbar with search placeholder, batch import, template download, add rule
- table-style rows
- MVP row sourced from the current target group id and recent event conversation names
- show `本地 SDK` as the current delivery mode

- [ ] **Step 3: Implement groups tab**

Create `_FeishuGroupsTab`:

- top toolbar with search placeholder and refresh button
- table-style rows from `status.observedConversations` and `status.recentEvents`
- show type, name, id, member count placeholder, recent preview, update time, forwarding status

- [ ] **Step 4: Verify rules/groups tests**

Run the page test and confirm PASS.

### Task 4: Image Processing And System Settings Tabs

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing settings tests**

Add tests that:

- tap `图片处理`
- expect `文字转图片`, `图片水印`, `触发几率`, `水印文字`, `保存设置`
- tap `系统设置`
- expect `Shell 地址`, `Token`, `刷新间隔`, `自动转发`, `去重窗口`, `投递通道`

Run the page test and confirm FAIL.

- [ ] **Step 2: Implement image processing tab**

Create `_ImageProcessingTab` with two settings panels:

- `文字转图片`
- `图片水印`

Use form controls only; do not implement image processing behavior in this phase.

- [ ] **Step 3: Implement system settings tab**

Create `_SystemSettingsTab` with fields:

- Shell 地址
- Token
- 刷新间隔
- 自动转发
- 去重窗口
- 失败重试
- 投递通道

Values can be current defaults/static display for now, except auto forwarding and target group id should reflect existing state.

- [ ] **Step 4: Verify settings tests**

Run the page test and confirm PASS.

### Task 5: Forwarding Controls Preservation

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Preserve existing manual forwarding tests**

Keep and update the existing tests:

- manual forwarding sends recent events to configured group
- auto forwarding toggle persists setting
- refresh button reloads latest shell status

The target group input should live in the quick action row with key:

```dart
const ValueKey('feishu-monitor-target-group-field')
```

The manual button should keep key:

```dart
const ValueKey('feishu-monitor-forward-recent-button')
```

- [ ] **Step 2: Implement compatibility**

Ensure `_QuickActions` wires:

- start capture
- stop capture
- reload runtime
- target group text field
- auto forwarding switch
- forward recent events button
- result text

- [ ] **Step 3: Verify forwarding tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

### Task 6: Focused Verification And Manual Preview

**Files:**
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
- Verify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`

- [ ] **Step 1: Run focused tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze lib/modules/feishu_monitor test/modules/feishu_monitor
```

Expected: PASS.

- [ ] **Step 3: Restart WuKongIM desktop**

Run:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\run_desktop_latest.bat' -WorkingDirectory 'C:\Users\COLORFUL\Desktop\WuKong'
```

Expected: the Feishu Monitor Center shows the approved console layout in the desktop app.
