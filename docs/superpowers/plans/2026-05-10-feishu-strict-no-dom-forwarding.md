# Feishu Strict No-DOM Forwarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Disable Feishu DOM fallback for production forwarding so the shell does not automatically open conversations and the WuKongIM forwarding service does not send DOM-derived images.

**Architecture:** Keep the existing message-list/feed-card probe and network diagnostics running. Add a strict no-DOM shell policy that reports media opening as intentionally disabled, and add forwarding-service guards that treat `dom_probe` and `body_text_probe` image attachments as non-forwardable production media.

**Tech Stack:** Flutter/Dart, existing Feishu shell WebView2 app, existing WuKongIM Flutter forwarding service, Flutter tests.

---

## File Map

- Modify `tools/feishu_monitor_shell_app/lib/main.dart`
  - Add a strict no-DOM media-opening policy constant.
  - Replace automatic `_openPendingMediaFeedIfNeeded` / `_openLatestFeedIfNeeded` calls with diagnostic recording.
- Modify `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`
  - Add runtime policy tests for the no-DOM diagnostic shape.
- Modify `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
  - Reject DOM-derived image attachments before media send, media defer, media retry, and media dedupe.
- Modify `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
  - Update legacy DOM-image expectations to the strict no-DOM behavior.
  - Add coverage that normal non-DOM images still forward.

## Task 1: Add Shell Strict No-DOM Diagnostics

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`

- [ ] **Step 1: Write failing shell policy tests**

Add these tests to `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`:

```dart
  test('shell exposes strict no-DOM forwarding policy', () {
    expect(feishuStrictNoDomForwardingEnabled, isTrue);
    expect(feishuStrictNoDomForwardingReason, 'strict_no_dom_forwarding');
  });

  test('shell reports media opening disabled by strict no-DOM policy', () {
    final diagnostic = feishuStrictNoDomOpenResult();

    expect(diagnostic['attempted'], isFalse);
    expect(diagnostic['opened'], isFalse);
    expect(diagnostic['reason'], 'strict_no_dom_forwarding');
  });
```

- [ ] **Step 2: Run focused runtime test and confirm RED**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart
```

Expected: fails because `feishuStrictNoDomForwardingEnabled`, `feishuStrictNoDomForwardingReason`, and `feishuStrictNoDomOpenResult` do not exist.

- [ ] **Step 3: Implement shell policy helpers**

In `tools/feishu_monitor_shell_app/lib/main.dart`, near the existing top-level constants, add:

```dart
const bool feishuStrictNoDomForwardingEnabled = true;
const String feishuStrictNoDomForwardingReason = 'strict_no_dom_forwarding';

Map<String, dynamic> feishuStrictNoDomOpenResult() {
  return <String, dynamic>{
    'attempted': false,
    'opened': false,
    'reason': feishuStrictNoDomForwardingReason,
  };
}
```

- [ ] **Step 4: Run focused runtime test and confirm GREEN**

Run:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart
```

Expected: all runtime tests pass.

## Task 2: Stop Shell Auto-Opening Feishu Conversations

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`

- [ ] **Step 1: Write failing policy-use test**

Add this test to `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`:

```dart
  test('strict no-DOM open result is safe for status diagnostics', () {
    final diagnostic = feishuStrictNoDomOpenResult();

    expect(diagnostic.keys, containsAll(<String>[
      'attempted',
      'opened',
      'reason',
    ]));
    expect(diagnostic, isNot(containsPair('key', anything)));
    expect(diagnostic, isNot(containsPair('text_preview', anything)));
  });
```

- [ ] **Step 2: Run focused runtime test and confirm RED if helper still includes event-specific fields**

Run:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart
```

Expected: passes if Task 1 already made the helper strict; if it fails, fix only the helper shape before continuing.

- [ ] **Step 3: Disable automatic feed opening in `_refreshPageProbe`**

In `tools/feishu_monitor_shell_app/lib/main.dart`, replace this block inside `_refreshPageProbe`:

```dart
      final feedChanged = _isFeedContentChanged(probe);
      await _openPendingMediaFeedIfNeeded(probe);
      if (!probeHasPendingMediaFeedCard(probe) && feedChanged) {
        await _openLatestFeedIfNeeded();
      }
```

with:

```dart
      final feedChanged = _isFeedContentChanged(probe);
      _recordStrictNoDomOpenResults();
      if (!feishuStrictNoDomForwardingEnabled) {
        await _openPendingMediaFeedIfNeeded(probe);
        if (!probeHasPendingMediaFeedCard(probe) && feedChanged) {
          await _openLatestFeedIfNeeded();
        }
      }
```

Then add this private method near `_openPendingMediaFeedIfNeeded`:

```dart
  void _recordStrictNoDomOpenResults() {
    if (!feishuStrictNoDomForwardingEnabled) {
      return;
    }
    _lastMediaOpenResult = feishuStrictNoDomOpenResult();
    _lastFeedOpenResult = feishuStrictNoDomOpenResult();
  }
```

This keeps the old methods in the file for now but makes them unreachable while the strict policy constant is true.

- [ ] **Step 4: Run shell tests and confirm GREEN**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart test/feishu_page_probe_test.dart
```

Expected: all selected shell tests pass.

## Task 3: Block DOM-Derived Image Attachments in Forwarding Service

**Files:**
- Modify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`

- [ ] **Step 1: Write failing forwarding tests for strict no-DOM media**

In `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`, add these tests near the existing media forwarding tests:

```dart
  test(
    'forwardRoutedRecentEvents does not send dom_probe image attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'dom:image_alpha',
            dedupeKey: 'feed:alpha:dom:image_alpha',
            conversationId: 'feed:alpha',
            text: '[图片]',
            captureSource: 'dom_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/webp;base64,SAME',
                localPath: '',
                width: 750,
                height: 338,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents does not send body_text_probe image attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'body:image_alpha',
            dedupeKey: 'feed:alpha:body:image_alpha',
            conversationId: 'feed:alpha',
            text: '[图片]',
            captureSource: 'body_text_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'https://internal.feishu.cn/body-image.png',
                localPath: '',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
    },
  );
```

- [ ] **Step 2: Run focused forwarding test and confirm RED**

Run from repo root:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: the new tests fail because DOM image attachments are still treated as sendable or text-fallback-capable.

- [ ] **Step 3: Implement DOM media rejection helpers**

In `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`, add:

```dart
bool _isDomFallbackCaptureSource(String captureSource) {
  final normalized = captureSource.trim();
  return normalized == 'dom_probe' || normalized == 'body_text_probe';
}

bool _eventHasDomFallbackMedia(FeishuMonitorMessageEvent event) {
  return _isDomFallbackCaptureSource(event.captureSource) &&
      _rawFirstUsableImageAttachmentForEvent(event) != null;
}
```

Rename the current `_firstUsableImageAttachmentForEvent` implementation to `_rawFirstUsableImageAttachmentForEvent`, then add a filtered wrapper:

```dart
FeishuMonitorImageAttachment? _firstUsableImageAttachmentForEvent(
  FeishuMonitorMessageEvent event,
) {
  if (_isDomFallbackCaptureSource(event.captureSource)) {
    return null;
  }
  return _rawFirstUsableImageAttachmentForEvent(event);
}
```

Keep `_firstUsableImageAttachment(event)` using the filtered helper.

- [ ] **Step 4: Make DOM media events skip without placeholder forwarding**

In `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`, update `_shouldSkipProbeTextEvent` so DOM fallback media is skipped:

```dart
bool _shouldSkipProbeTextEvent(FeishuMonitorMessageEvent event) {
  final captureSource = event.captureSource.trim();
  if (captureSource == 'feed_card_probe' &&
      _isFeishuMonitorMediaPlaceholderText(event.text)) {
    return _firstUsableImageAttachmentForEvent(event) == null;
  }
  if (_eventHasDomFallbackMedia(event)) {
    return true;
  }
  if (!_isDomFallbackCaptureSource(captureSource)) {
    return false;
  }
  return _firstUsableImageAttachmentForEvent(event) == null;
}
```

- [ ] **Step 5: Run focused forwarding test and confirm GREEN for new behavior**

Run:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: new tests pass, but older tests that expected DOM image forwarding may now fail. Update those older expectations in Task 4.

## Task 4: Update Legacy Media Tests to Strict No-DOM Policy

**Files:**
- Modify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart` only if tests reveal a missed strict no-DOM branch.

- [ ] **Step 1: Update old DOM image tests**

In `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`, update tests whose input events use `captureSource: 'dom_probe'` and currently expect `sentImages`.

For the duplicate-media tests, change expectations to:

```dart
      expect(result.sent, 0);
      expect(result.skippedDuplicate, 2);
      expect(sender.sentImages, isEmpty);
      expect(sender.sentTexts, isEmpty);
```

For persisted duplicate media across routes, change the first result expectations to:

```dart
      expect(first.sent, 0);
      expect(first.skippedDuplicate, 1);
      expect(firstSender.sentImages, isEmpty);
```

Keep non-DOM image tests unchanged.

- [ ] **Step 2: Ensure non-DOM images still forward**

If no existing test covers this exact path after edits, add:

```dart
  test(
    'forwardRoutedRecentEvents still sends feed-card image attachments',
    () async {
      final sender = _RecordingSender();
      final service = FeishuMonitorForwardingService(sender: sender);
      final settings = FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <FeishuMonitorMessageEvent>[
          _event(
            messageId: 'feed:image_alpha',
            dedupeKey: 'feed:alpha:feed:image_alpha',
            conversationId: 'feed:alpha',
            text: '[图片]',
            captureSource: 'feed_card_probe',
            imageAttachments: const <FeishuMonitorImageAttachment>[
              FeishuMonitorImageAttachment(
                sourceUrl: 'data:image/webp;base64,SAME',
                localPath: '',
                width: 750,
                height: 338,
              ),
            ],
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 0);
      expect(sender.sentImages, hasLength(1));
      expect(sender.sentTexts, isEmpty);
    },
  );
```

- [ ] **Step 3: Run focused forwarding test**

Run:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: all forwarding service tests pass.

## Task 5: Verification and Manual-Test Notes

**Files:**
- Modify: `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`

- [ ] **Step 1: Run shell test suite**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_runtime_test.dart test/feishu_page_probe_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/feishu_network_capture_parser_test.dart test/runtime_snapshot_mapper_test.dart
```

Expected: all selected shell tests pass.

- [ ] **Step 2: Run main forwarding tests**

Run from repo root:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart
```

Expected: all selected forwarding tests pass.

- [ ] **Step 3: Run analyzer for touched packages**

Run from repo root:

```powershell
flutter analyze lib test
```

Expected: no new analyzer issues in `lib/modules/feishu_monitor` or related tests.

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter analyze lib test
```

Expected: no analyzer issues in the shell app.

- [ ] **Step 4: Build shell debug Windows app**

Run in `tools/feishu_monitor_shell_app`:

```powershell
flutter build windows --debug
```

Expected: build exits 0. Existing CMake developer warnings are acceptable if they are unchanged.

- [ ] **Step 5: Update test report**

Append a section to `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`:

```markdown
## 2026-05-10 Strict No-DOM Update

- Shell policy: strict no-DOM forwarding enabled.
- Automatic Feishu conversation opening for media placeholders: disabled.
- DOM-derived image forwarding (`dom_probe`, `body_text_probe`): disabled.
- Text forwarding from feed-card/message-list events: unchanged.
- Network image attribution: diagnostics only; not used for production image forwarding.
- Verification:
  - `<paste shell test summary>`
  - `<paste forwarding test summary>`
  - `<paste analyzer/build summary>`
- Manual follow-up:
  1. Launch shell and WuKongIM.
  2. Keep Feishu shell on the message list.
  3. Send text to a configured Feishu group and verify forwarding.
  4. Send an image to a configured Feishu group and verify the shell does not enter the group.
  5. Confirm WuKongIM receives no wrong image.
  6. Inspect `/status` for `strict_no_dom_forwarding`.
```

Replace each `<paste ...>` placeholder with the actual command outcome before saving.

