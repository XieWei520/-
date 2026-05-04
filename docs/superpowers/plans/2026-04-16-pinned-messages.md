# Pinned Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete pinned-message parity in Flutter so pin state syncs correctly, group permissions are respected, and chat exposes pin/unpin plus pinned-message browsing.

**Architecture:** Finish the pinned slice from the bottom up. First lock failures in tests, then complete the SDK and app sync chain for `isPinned`, then add pinned-message API wrappers and group permission fields, and finally wire the chat surfaces with a compact banner/list UX that reuses existing providers and jump-to-message primitives.

**Tech Stack:** Flutter, flutter_test, Riverpod, Dio, WuKongIMFlutterSDK, existing group/chat scene providers

---

**Workspace Note:** This working copy still does not expose `.git` metadata. Use the verification checkpoints below locally even though commit commands cannot run from this checkout.

### Task 1: Lock the pinned sync and permission gaps with tests

**Files:**
- Modify: `test/service/im/im_service_test.dart`
- Modify: `test/service/api/group_api_test.dart`
- Add: `test/service/api/message_api_test.dart`
- Modify: `test/modules/chat/chat_message_action_policy_test.dart`
- Modify: `test/wukong_uikit/group/group_detail_page_settings_test.dart`

- [ ] Add a failing test proving `resolveImCommandSideEffects('syncPinnedMessage')` maps to message-extra synchronization.
- [ ] Add a failing test proving `GroupApi.getGroupInfo(...)` parses `allow_member_pinned_message` into the runtime `GroupInfo`.
- [ ] Add a failing test proving message-extra parsing keeps `is_pinned` and pinned-sync parsing returns both metadata rows and resolved messages.
- [ ] Add a failing test proving the chat long-press action policy shows `置顶` for unpinned messages and `取消置顶` for pinned messages without disturbing stable action order.
- [ ] Add a failing widget test proving the group-detail settings section renders the allow-member-pinned switch from server-backed data.
- [ ] Run the focused tests and confirm they fail for the expected missing behavior.

### Task 2: Complete SDK and app-side pinned sync plumbing

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\entity\msg.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\message_manager.dart`
- Modify: `lib/service/api/im_sync_api.dart`
- Modify: `lib/service/api/message_api.dart`
- Modify: `lib/service/im/im_service.dart`

- [ ] Add `isPinned` to the SDK sync models and map it into `WKMsgExtra`.
- [ ] Update SDK remote-extra persistence so `saveRemoteExtraMsg(...)` writes the pinned flag during extra sync.
- [ ] Extend app-side sync parsing to read both top-level and nested `is_pinned` payloads.
- [ ] Map `syncPinnedMessage` onto the same side-effect path as message-extra sync so remote pin changes refresh locally.
- [ ] Re-run the Task 1 sync-focused tests until green.

### Task 3: Add pinned-message API contracts and runtime group permission state

**Files:**
- Modify: `lib/service/api/message_api.dart`
- Modify: `lib/data/models/group.dart`
- Modify: `lib/service/api/group_api.dart`
- Modify: `test/service/api/group_api_test.dart`
- Add: `test/service/api/message_api_test.dart`

- [ ] Add API methods for pin/unpin, pinned sync, and clear-all pinned using the server contracts from `TangSengDaoDaoServer-main`.
- [ ] Introduce a small pinned-message response model for the `pinned_messages` payload and keep parsing defensive against wrapped and unwrapped server bodies.
- [ ] Add `allowMemberPinnedMessage` to the runtime `GroupInfo` model and preserve it through JSON serialization and channel hydration.
- [ ] Re-run the API and group-model tests until green.

### Task 4: Expose pinned-message group settings

**Files:**
- Modify: `lib/wukong_uikit/group/group_detail_page.dart`
- Modify: `test/wukong_uikit/group/group_detail_page_settings_test.dart`

- [ ] Add `_allowMemberPinnedMessage` state to the group detail page and hydrate it from server-backed group data.
- [ ] Extend `_currentSettingValue(...)`, `_applyLocalSetting(...)`, and the existing update helpers to support `allow_member_pinned_message`.
- [ ] Add a visible switch keyed for tests in the advanced settings section, shown only for users who can manage group settings.
- [ ] Re-run the group-detail settings tests until green.

### Task 5: Add chat pin/unpin actions and pinned visual indicators

**Files:**
- Modify: `lib/modules/chat/chat_message_action_policy.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Modify: `test/modules/chat/chat_message_action_policy_test.dart`
- Modify: `test/modules/chat/message_bubble_experience_test.dart`

- [ ] Extend the action enum and descriptor builder to support `pin` and `unpin` while preserving Android-style ordering stability.
- [ ] Wire the chat shell action dispatcher to call the new pinned-message API methods and refresh pinned data after state changes.
- [ ] Render a compact pinned marker in `MessageBubble` when `wkMsgExtra.isPinned == 1`.
- [ ] Re-run action-policy and message-bubble tests until green.

### Task 6: Add pinned banner/list and jump-to-message flow

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Add: `lib/modules/chat/widgets/chat_pinned_message_banner.dart`
- Add: `lib/modules/chat/widgets/chat_pinned_message_sheet.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] Add a lightweight pinned-state load path in the chat shell that syncs pinned rows for the current channel and derives a visible banner model.
- [ ] Insert the pinned banner above the message viewport and show the top pinned entry plus a count when multiple entries exist.
- [ ] Open a bottom-sheet pinned list from the banner and let item selection jump through `messageListProvider(...).notifier.loadAroundOrderSeq(...)`.
- [ ] Show clear-all only when the current channel and member role allow it, then refresh pinned state after clearing.
- [ ] Re-run the chat scene-flow and parity tests until green.

### Task 7: Focused regression and desktop verification

**Files:**
- Modify: any files touched in Tasks 2-6 if regressions surface

- [ ] Run `flutter test test/service/im/im_service_test.dart test/service/api/group_api_test.dart test/service/api/message_api_test.dart test/modules/chat/chat_message_action_policy_test.dart test/wukong_uikit/group/group_detail_page_settings_test.dart`.
- [ ] Run `flutter test test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart`.
- [ ] Run a broader chat/group confidence pass if the focused suite uncovers adjacent regressions.
- [ ] Run `flutter build windows --debug` before claiming the pinned-messages slice is complete.
