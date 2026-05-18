# Feishu Relay Avatar Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local image upload support for the per-route Feishu relay avatar field.

**Architecture:** Inject image picking and avatar uploading callbacks into `FeishuMonitorCenterPage`, pass them into `_TargetGroupPicker`, and keep the existing `relayAvatar` model field as the stored value. The upload UI updates the existing avatar text controller with the returned media URL.

**Tech Stack:** Flutter widget tests, existing `pickSingleLocalImagePath`, existing `FileApi.uploadCommonImage`, existing Feishu monitor route settings.

---

### Task 1: Widget Test

**Files:**
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing test**

Add a widget test that injects fake `pickRelayAvatarImage` and `uploadRelayAvatarImage`, opens the Feishu group route picker, taps `ValueKey('feishu-route-relay-avatar-upload-button')`, expects the avatar field to contain the uploaded URL, selects a target group, and expects `settingsStore.saved!.routes.single.relayAvatar` to equal the uploaded URL.

- [ ] **Step 2: Verify RED**

Run:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart --plain-name "route relay avatar can be uploaded from local image"
```

Expected: fails because the upload button and injectable callbacks do not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`

- [ ] **Step 1: Add callback typedefs and defaults**

Add `FeishuMonitorRelayAvatarPicker` and `FeishuMonitorRelayAvatarUploader`. Default picker calls `pickSingleLocalImagePath(imageQuality: 85, maxWidth: 512, maxHeight: 512)`. Default uploader calls `FileApi.instance.uploadCommonImage` with `feishu-relay-avatar/<timestamp>.<ext>`.

- [ ] **Step 2: Pass callbacks to picker**

Store callbacks on `FeishuMonitorCenterPage` and pass them into `_TargetGroupPicker`.

- [ ] **Step 3: Add upload UI**

Replace the standalone avatar `TextField` with a row containing the field and a small `TextButton` keyed `feishu-route-relay-avatar-upload-button`. On tap, pick and upload the image, then write the URL to `_relayAvatarController.text`.

- [ ] **Step 4: Add upload state**

Track `_uploadingAvatar` and `_avatarUploadError`. Disable the button while uploading. Show progress text while uploading and error text on failure.

### Task 3: Verification

**Files:**
- Test: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Analyze: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`

- [ ] **Step 1: Run page test**

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

```powershell
flutter analyze lib/modules/feishu_monitor/feishu_monitor_center_page.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: no issues found.

- [ ] **Step 3: Build Windows**

```powershell
flutter build windows --release
```

Expected: release executable is built.
