# Phase 1 Chat Media, Audio, Permissions, and Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the highest-leverage Flutter parity gaps by wiring the active chat shell to real media actions, replacing placeholder permission/audio infrastructure, and removing redundant dead-end utility files so the project stays clean.

**Architecture:** Keep the authoritative user path on `chat_page_shell.dart` and move media behavior into focused helper services instead of reviving legacy `*_complete.dart` pages. Consolidate duplicate permission utilities into one implementation, add test-backed media content builders, and only delete redundant files after imports/exports are redirected.

**Tech Stack:** Flutter, Riverpod, WKIM SDK, `image_picker`, `file_picker`, `permission_handler`, Flutter widget/unit tests, targeted cleanup with `apply_patch`.

---

### Task 1: Lock the authoritative Phase 1 boundaries with tests

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_media_action_service_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_toolbar_slot_assembly_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_page_scene_flow_test.dart`

- [ ] Add failing tests that define the Phase 1 target behavior:
  - media action service can build image/file/location message contents from real payloads
  - toolbar/function items expose the expected authoritative media actions
  - chat shell can surface and invoke active media actions without touching legacy `chat_page_complete.dart`

- [ ] Run the focused chat tests and verify they fail for the intended reason.

- [ ] Commit the red test baseline only after the failing expectations are correct.

### Task 2: Introduce an authoritative chat media action service

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_media_action_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_toolbar_slot_assembly.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\wk_custom_content.dart`

- [ ] Implement a focused service that owns:
  - image selection payload normalization
  - file selection payload normalization
  - location result normalization
  - WKIM message content construction for image/file/location/card where applicable

- [ ] Extend the active chat composer pane so:
  - album toolbar button performs image selection and sends image content
  - “more” panel items can dispatch image, file, and location actions
  - panel visibility and send completion behave consistently with the existing scene model

- [ ] Keep the authority in the routed `ChatPageShell`; do not reintroduce logic from `chat_page_complete.dart`.

- [ ] Run the media-related tests and update them to green with minimal behavior.

- [ ] Commit once the active chat shell can send image/file/location content through the real gateway path.

### Task 3: Consolidate permission handling and remove duplicate WKPermissions implementations

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\utils\permission_utils.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\utils\wk_permissions.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\utils\utils.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\wukong_base.dart`
- Delete: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\utils\wk_permissions.dart`

- [ ] Replace duplicate placeholder permission files with one authoritative implementation.

- [ ] Redirect legacy exports/import paths so downstream code still resolves cleanly.

- [ ] Verify no active import path still depends on the deleted duplicate file.

- [ ] Run focused tests or analyzer-equivalent compile tests to ensure permission utilities remain build-safe.

- [ ] Commit after duplicate permission helpers are fully collapsed.

### Task 4: Replace placeholder audio manager internals with real runtime behavior

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\pubspec.yaml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\utils\audio_record_manager.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_base\utils\audio_record_manager_test.dart`

- [ ] Add the minimal package/runtime support needed for real recording/playback instead of timer-only placeholders.

- [ ] Keep the public manager API stable where possible, but back it with real permission checks, file output, playback state, and progress updates.

- [ ] Add tests around state transitions and failure handling that do not require microphone hardware in CI.

- [ ] Run the new audio tests plus affected chat tests.

- [ ] Commit after the placeholder TODO behavior is gone from the active audio manager implementation.

### Task 5: Clean legacy dead ends after the authoritative path is green

**Files:**
- Delete or archive only after verification:
  - `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\utils\wk_permissions.dart`
  - any newly confirmed unused placeholder helper introduced only by old paths
- Review for retention:
  - `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_complete.dart`
  - `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page_complete.dart`

- [ ] Remove only files that are provably redundant after the new authoritative path is working.

- [ ] Do not delete legacy pages that are still referenced by tests or parity notes until all imports are dead.

- [ ] Run a targeted search for imports/usages before every deletion.

- [ ] Commit the cleanup separately from feature logic so rollback stays easy.

### Task 6: Final verification for the Phase 1 batch

**Files:**
- Modify if needed: test files touched above

- [ ] Run the focused verification suite:
  - `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart`
  - `flutter test test/modules/chat/chat_page_scene_flow_test.dart`
  - `flutter test test/modules/chat/chat_media_action_service_test.dart`
  - `flutter test test/wukong_base/utils/audio_record_manager_test.dart`

- [ ] Run an additional broader safety sweep for chat/settings/base compile coverage:
  - `flutter test test/modules/chat`
  - `flutter test test/modules/settings/settings_pages_compile_test.dart`
  - `flutter test test/modules/shell/main_pages_compile_test.dart`

- [ ] If any verification fails, fix before declaring the batch complete.

- [ ] Document remaining known Phase 1 gaps, if any, for the next batch.
