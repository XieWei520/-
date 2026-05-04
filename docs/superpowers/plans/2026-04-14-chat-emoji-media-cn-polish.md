# Chat Emoji / Media / Chinese-First Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore desktop chat usability by fixing emoji insertion, attachment upload host mismatch, location/card tap navigation, and Chinese-first locale behavior.

**Architecture:** Keep the existing `ChatPageShell` composer and send chain intact. Add one narrow upload-URL normalization helper, one real emoji panel in the composer, one bubble-tap router for location/card/image, and app-root locale wiring that consumes the saved language preference.

**Tech Stack:** Flutter, flutter_test, flutter_localizations, Riverpod, Dio, existing chat/location/user pages

---

**Workspace Note:** This working copy still does not expose `.git` metadata. Use the verification checkpoints below locally even though the commit commands cannot run from this checkout.

### Task 1: Lock the failures with tests

**Files:**
- Modify: `test/core/config/api_config_test.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/app/bootstrap/app_startup_test.dart`

- [ ] Add a failing test proving backend-issued absolute upload URLs for `/v1/file/upload` are rewritten onto `ApiConfig.baseUrl` when the host differs.
- [ ] Add a failing widget test proving the emoji panel shows real emoji cells instead of a placeholder title-only panel.
- [ ] Add a failing widget test proving location and card bubbles in the active shell can trigger navigation/open behavior.
- [ ] Add a failing test proving the app root exposes Chinese locale configuration.
- [ ] Run the focused tests and capture the expected red state.

### Task 2: Fix upload URL normalization and app-root locale wiring

**Files:**
- Modify: `lib/core/config/api_config.dart`
- Modify: `lib/service/api/file_api.dart`
- Modify: `lib/app/app.dart`
- Modify: `pubspec.yaml`

- [ ] Add a focused upload-URL normalization helper in `ApiConfig` for the `/v1/file/upload` route only.
- [ ] Route `FileApi._requestUploadUrl()` through the new helper so image/file uploads stop following unreachable absolute hosts.
- [ ] Add `flutter_localizations` and wire `locale`, `supportedLocales`, and `localizationsDelegates` at `MaterialApp.router`.
- [ ] Default to Simplified Chinese unless the saved preference explicitly requests English.
- [ ] Re-run the Task 1 tests that cover these behaviors until they pass.

### Task 3: Replace the placeholder emoji panel

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`

- [ ] Replace the current title-only emoji panel branch with a real grid panel.
- [ ] Insert selected emoji into the composer text using the current cursor position and keep `ChatComposerController` state synchronized.
- [ ] Provide a delete action and keep panel layout stable on desktop widths.
- [ ] Replace the active input hint copy with Chinese.
- [ ] Re-run the emoji-focused widget tests until green.

### Task 4: Make location and card messages tappable

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/location/location_map_page.dart`
- Modify: `lib/modules/location/location_view_page.dart`

- [ ] Add a unified bubble-tap dispatcher in `ChatPageShell` for image, location, and card content.
- [ ] Open `LocationViewPage` for location messages and `UserDetailPage` for card messages.
- [ ] Resolve content from both typed message-content objects and structured payload fallback fields.
- [ ] Improve desktop location loading feedback and Chinese copy in the map pages.
- [ ] Re-run scene-flow widget tests until green.

### Task 5: Chinese polish and focused verification

**Files:**
- Modify: `lib/widgets/message_bubble.dart`
- Modify: any touched chat/location files from Tasks 2-4

- [ ] Replace the highest-frequency broken/English chat copy in touched surfaces with readable Chinese.
- [ ] Run `flutter test test/core/config/api_config_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/app/bootstrap/app_startup_test.dart`.
- [ ] Run a broader guard check: `flutter test test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart`.
- [ ] Run a Windows desktop smoke test for emoji send, image send, location open, and card open before claiming success.
