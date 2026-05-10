# Feishu Monitor Shell Phase 6 Feed Card Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the desktop shell from coarse full-page `body_text_probe` fallback to a focused Feishu message-list `feed_card_probe`, so the shell can observe multiple recent conversations without opening each group.

**Architecture:** Keep forwarding out of scope. The WebView script collects Feishu feed-card nodes from the message home page and returns raw feed card text plus diagnostics. Dart normalization converts those cards into `ObservedConversation` and `ObservedMessageCandidate` objects with stable IDs and `capture_source = feed_card_probe`; existing event normalization then feeds WuKongIM diagnostics.

**Tech Stack:** Dart shared shell package, Flutter Windows shell app, `webview_windows.executeScript`, Flutter widget tests, Dart package tests

---

### Task 1: Feed Card Normalization

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`
- Modify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`

- [ ] **Step 1: Write failing tests**

Add a test where `FeishuPageProbe.fromScriptResult` receives raw `feed_cards` from the Feishu message list:

```dart
<String, dynamic>{
  'page_kind': 'messenger',
  'observed_at': '2026-05-09T12:00:00Z',
  'feed_cards': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'feed_card_1',
      'text': '1 账号安全中心 机器人 09:24 安全登录通知',
    },
    <String, dynamic>{
      'id': 'feed_card_2',
      'text': '听M玛的话交流12群C-GH 外部 4月27日 MM12机器人: 1 今天盘中、 多空-来回拉锯强烈',
    },
    <String, dynamic>{
      'id': 'shortcut_1',
      'text': '知识问答',
    },
  ],
}
```

Assert that two observed messages remain, shortcut/no-time cards are skipped, conversation names are extracted, sender text after `:` is handled, and `capture_source` is `feed_card_probe`.

Run: `D:\Apps\flutter\bin\flutter.bat test test/feishu_page_probe_test.dart`

Expected: FAIL because raw `feed_cards` are not normalized yet.

- [ ] **Step 2: Implement Dart feed-card parser**

In `feishu_page_probe.dart`, add a private parser that:

- reads `feed_cards` only when `observed_messages` is empty
- normalizes whitespace
- skips cards without a message time marker such as `09:24`, `昨天`, or `4月27日`
- removes leading unread counts and trailing conversation tags such as `外部`, `官方`, and `机器人`
- maps `sender: preview` into `senderName` and `text`
- creates stable `feed:` IDs using deterministic hashing
- creates matching `ObservedConversation` entries when the script did not provide explicit conversations

- [ ] **Step 3: Verify parser tests**

Run: `D:\Apps\flutter\bin\flutter.bat test test/feishu_page_probe_test.dart`

Expected: PASS.

### Task 2: WebView Feed Card Collection

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`

- [ ] **Step 1: Add feed selectors to the probe script**

Update `feishuPageProbeScript` to query real classes found in diagnostics:

```javascript
[
  '.lark_feedMainList .a11y_feed_card_item',
  '.lark_feedMainList .a11y_feed_card_main',
  '.scroller.feed-main-list .a11y_feed_card_item',
  '.scroller.feed-main-list .a11y_feed_card_main'
]
```

Return `feed_cards` and diagnostics:

- `feed_card_selector_hits`
- `feed_card_samples`

- [ ] **Step 2: Prefer feed cards over body fallback**

Ensure `FeishuPageProbe.fromScriptResult` derives feed-card messages before falling back to full `body_text_probe`.

- [ ] **Step 3: Verify shell app tests**

Run: `D:\Apps\flutter\bin\flutter.bat test test/feishu_page_probe_test.dart test/runtime_snapshot_mapper_test.dart`

Expected: PASS.

### Task 3: Local Runtime Verification

**Files:**
- Verify: `.runtime/feishu_status_with_diagnostics.json`

- [ ] **Step 1: Restart the standalone shell**

Run:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\run_feishu_monitor_shell_app.bat' -WorkingDirectory 'C:\Users\COLORFUL\Desktop\WuKong'
```

- [ ] **Step 2: Fetch status**

Run:

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:18766/status' -Headers @{Authorization='Bearer wukong-feishu-shell-dev'} -UseBasicParsing | Select-Object -ExpandProperty Content
```

Expected: status contains multiple `observed_messages` or `recent_events` with `capture_source = feed_card_probe`.

- [ ] **Step 3: Restart WuKongIM desktop if needed**

Run:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\run_desktop_latest.bat' -WorkingDirectory 'C:\Users\COLORFUL\Desktop\WuKong'
```

Expected: Feishu Monitor Center shows the feed-card derived event timeline.
