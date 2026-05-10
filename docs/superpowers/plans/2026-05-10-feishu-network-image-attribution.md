# Feishu Network Image Attribution Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add diagnostics that correlate Feishu Web network image/blob candidates with DOM/feed-card attribution evidence before enabling any no-open image forwarding.

**Architecture:** A document-created JavaScript hook observes image blob creation and DOM image usage, posts bounded attribution messages to Flutter, and Dart stores/correlates those attributions with existing CDP network image candidates. `/status` continues to expose everything through `ShellSnapshot.probeDiagnostics`.

**Tech Stack:** Flutter/Dart, WebView2 document-created JavaScript, existing `webview_windows_wukong` CDP capture, existing `feishu_monitor_shell` snapshot/status models, Flutter tests.

---

## File Map

- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
  - Add `FeishuNetworkImageAttribution` and redacted status JSON.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
  - Store recent attribution events and expose exact-match attributed candidates.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_page_observer.dart`
  - Add `feishuNetworkImageAttributionScript`.
  - Extend `FeishuPageObserverMessage` to parse attribution payloads.
- Modify `tools/feishu_monitor_shell_app/lib/main.dart`
  - Install attribution script at document creation and after navigation.
  - Handle attribution web messages and persist diagnostics.
- Modify `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`
  - Add store and exact-match tests.
- Modify `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
  - Add observer-script and attribution-message parser tests.
- Modify `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`
  - Add runtime diagnostics-file compatibility if needed.
- Modify `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`
  - Record verification and live attribution result.

## Task 1: Attribution Model

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Write failing attribution model test**

Add a test that constructs `FeishuNetworkImageAttribution.fromJson` with:

```dart
{
  'type': 'feishu_monitor_image_attribution',
  'source_url': 'blob:https://example.feishu.cn/abc?token=secret',
  'source_kind': 'blob',
  'blob_mime_type': 'image/webp',
  'blob_size': 12345,
  'conversation_id': 'feed:abc',
  'conversation_name': '满满正能量',
  'message_id': 'msg_1',
  'sender_name': '橘生淮南',
  'display_time': '14:29',
  'message_text': '[图片]',
  'feed_card_id': 'feed_card_1',
  'feed_card_text': '满满正能量 14:29 橘生淮南: [图片]',
  'confidence': 0.92,
  'confidence_label': 'high',
  'reason': 'dom_img_src',
  'observed_at': '2026-05-10T06:29:00Z',
  'evidence': ['exact_dom_node', 'feed_card_context']
}
```

Expected assertions:

- `conversationName == '满满正能量'`
- `sourceUrl` preserves the raw blob URL internally.
- `toStatusJson()['source_url']` redacts query values.
- `toStatusJson()['stable'] == true`.

- [ ] **Step 2: Run the focused test and confirm RED**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: fails because `FeishuNetworkImageAttribution` does not exist.

- [ ] **Step 3: Implement the model**

Add the class to `feishu_network_capture.dart`:

- Fields listed in Step 1.
- `factory FeishuNetworkImageAttribution.fromJson(Map<String, dynamic> json)`.
- `bool get isStable => confidence >= 0.8 && confidenceLabel == 'high' && conversationName.trim().isNotEmpty`.
- `Map<String, Object?> toStatusJson()` using `redactUrl(sourceUrl)` and capped evidence strings.

- [ ] **Step 4: Run the test and confirm GREEN**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: attribution model test passes with existing tests.

## Task 2: Store Attribution and Exact-Match Correlation

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Add tests for:

- `network_image_attribution_count` increments separately from network candidate count.
- `network_recent_image_attributions` is bounded.
- When a candidate resource URL exactly equals an attribution source URL, `network_last_attributed_image_candidate` contains both the redacted candidate and attribution and `stable=true`.

- [ ] **Step 2: Run store tests and confirm RED**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: fails because store has no attribution support.

- [ ] **Step 3: Implement store support**

Modify `FeishuNetworkCaptureStore`:

- Add `maxAttributions` constructor parameter, clamped like the other bounds.
- Add `_attributions`, `_attributionCount`, and `addAttribution(FeishuNetworkImageAttribution attribution)`.
- Include attribution fields in `toDiagnosticsJson()`.
- Add a private exact-match helper that scans recent candidates and attributions from newest to oldest and returns the newest exact URL match.
- Append attribution diagnostics lines with a `diagnostic_type` value such as `image_attribution`.

- [ ] **Step 4: Run store tests and confirm GREEN**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: all store tests pass.

## Task 3: Page Attribution Script and Web Message Parsing

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_page_observer.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`

- [ ] **Step 1: Write failing observer tests**

Add tests that assert:

- `feishuNetworkImageAttributionScript` contains `URL.createObjectURL`.
- It contains `MutationObserver`.
- It posts `feishu_monitor_image_attribution`.
- `FeishuPageObserverMessage.fromJson()` parses an attribution payload into a non-null `imageAttribution`.
- `isImageAttribution == true` for that payload.

- [ ] **Step 2: Run observer tests and confirm RED**

Run:

```powershell
flutter test test/feishu_page_probe_test.dart
```

Expected: fails because script/message support does not exist.

- [ ] **Step 3: Implement script and parser**

Add `feishuNetworkImageAttributionScript`:

- Idempotent state key: `__wukongFeishuNetworkImageAttribution`.
- Wrap `URL.createObjectURL` and record image blobs.
- Scan `img` nodes and `[style*="background"]` nodes.
- Use existing feed selectors:
  - `.lark_feedMainList .a11y_feed_card_item`
  - `.lark_feedMainList .a11y_feed_card_main`
  - `.scroller.feed-main-list .a11y_feed_card_item`
  - `.scroller.feed-main-list .a11y_feed_card_main`
- Parse feed text with a simple time regex and colon split.
- Post attribution messages with capped strings and evidence.

Extend `FeishuPageObserverMessage`:

- Add `final FeishuNetworkImageAttribution? imageAttribution`.
- Add `bool get isImageAttribution => imageAttribution != null`.
- For type `feishu_monitor_image_attribution`, parse the attribution model.

- [ ] **Step 4: Run observer tests and confirm GREEN**

Run:

```powershell
flutter test test/feishu_page_probe_test.dart
```

Expected: observer tests pass with existing probe tests.

## Task 4: Shell Integration

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`

- [ ] **Step 1: Write integration expectation**

Add or update a runtime test that verifies the app exposes the existing network diagnostics file path unchanged. This protects the current JSONL path while attribution events are added.

- [ ] **Step 2: Run focused tests before integration**

Run:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart test/feishu_page_probe_test.dart test/feishu_network_capture_store_test.dart
```

Expected: tests pass or only the new integration expectation fails for the intended reason.

- [ ] **Step 3: Wire the script and handler**

Modify `main.dart`:

- Import the updated observer/network model as needed.
- In `_installDocumentCreatedScripts()`, add `feishuNetworkImageAttributionScript` after keep-alive.
- In `_installPageObserver()`, execute `feishuNetworkImageAttributionScript` as a fallback after navigation.
- In `_handleWebMessage()`, before feed-change handling:
  - If `observerMessage.isImageAttribution`, call `_networkCaptureStore.addAttribution(observerMessage.imageAttribution!)`.
  - Call `_probeScheduler.request('image_attribution')`.
  - Persist network diagnostics best-effort.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart test/feishu_page_probe_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/feishu_network_capture_parser_test.dart
```

Expected: all focused tests pass.

## Task 5: Verification and Report

**Files:**
- Modify: `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`

- [ ] **Step 1: Run static analysis**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter analyze lib test
```

Expected: no issues found.

- [ ] **Step 2: Build Windows shell**

Stop the running shell first:

```powershell
Get-Process feishu_monitor_shell_app -ErrorAction SilentlyContinue | Stop-Process -Force
```

Then run:

```powershell
flutter build windows --debug
```

Expected: build succeeds, allowing the existing non-blocking CMake dev warning.

- [ ] **Step 3: Manual joint test**

Launch:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Debug\feishu_monitor_shell_app.exe' -WorkingDirectory 'C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Debug' -WindowStyle Hidden
```

Ask the user to:

- Keep Feishu on the message list page.
- Send one image to a configured source group.
- Avoid clicking into that group until status is captured.

Check:

```powershell
$h=@{Authorization='Bearer wukong-feishu-shell-dev'}
Invoke-RestMethod -Uri 'http://127.0.0.1:18766/status' -Headers $h | ConvertTo-Json -Depth 20
```

Expected evidence:

- `network_image_candidate_count` increases.
- `network_image_attribution_count` increases if the page creates/uses an image blob in DOM.
- `network_last_attributed_image_candidate` is non-null only on exact source URL match.
- If `stable=false`, production no-open image forwarding remains disabled.

- [ ] **Step 4: Update report**

Append results to `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md` under `Network Image Attribution Diagnostics`.

## Final Verification

Run these before claiming completion:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart test/feishu_page_probe_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/feishu_network_capture_parser_test.dart
```

```powershell
flutter analyze lib test
```

```powershell
flutter build windows --debug
```

Do not enable production no-open image forwarding in this plan.

