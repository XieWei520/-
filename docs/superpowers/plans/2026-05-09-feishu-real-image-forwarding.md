# Feishu Real Image Forwarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Forward real Feishu image media to WuKongIM groups when the Web shell can extract an image resource, while preserving text fallback for unresolved image placeholders.

**Architecture:** Extend the shell event model with optional image attachments, propagate them through the page probe and snapshot mapper, then let the WuKong forwarding service prefer `WKImageContent` sends over text. Existing text forwarding and dedupe semantics remain unchanged.

**Tech Stack:** Flutter/Dart, `feishu_monitor_shell` models, WebView JavaScript DOM probe, `WKImageContent`, existing `ChatSceneGateway`.

---

### Task 1: Event Model Carries Image Attachments

**Files:**
- Modify: `tools/feishu_monitor_shell/lib/src/shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Test: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`

- [ ] Add a `FeishuImageAttachment`/`MessageImageAttachment` JSON model with `sourceUrl`, `localPath`, `width`, and `height`.
- [ ] Add `imageAttachments` to observed and normalized message models.
- [ ] Preserve attachments through snapshot JSON round trips.

### Task 2: Probe Extracts Image Resources

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`

- [ ] Extend the Web probe to collect image URLs from feed/message nodes.
- [ ] Parse `image_attachments` from script results.
- [ ] Include attachments in feed-card derived message candidates when text is an image placeholder.

### Task 3: Forwarding Service Sends Images First

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] Extend `FeishuMonitorTextSender` into a media-capable sender.
- [ ] Implement image send via `WKImageContent`.
- [ ] If image send fails or no usable image exists, send the formatted text fallback.

### Task 4: Verify and Rebuild

**Files:**
- No source changes expected.

- [ ] Run targeted root tests for the forwarding service.
- [ ] Run targeted shell app tests.
- [ ] Run analyzer on touched files.
- [ ] Rebuild Windows apps and restart for joint testing.
