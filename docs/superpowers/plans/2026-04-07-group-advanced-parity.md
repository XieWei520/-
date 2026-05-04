# Group Advanced Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining real group-advanced parity gaps so the active Flutter mainline covers truthful group settings, invite-mode member actions, member-scoped message search, and scan-based join handling instead of relying on partial UI or speculative API wrappers.

**Architecture:** Keep `lib/wukong_uikit/group/group_detail_page.dart` as the single production owner for group detail. Extend the existing `GroupInfo` and `GroupApi` contract only where Android plus local server source confirm real fields or endpoints, keep one member-search results owner under `lib/modules/search/**`, and convert internal join-group QR or H5 results into a native Flutter confirmation flow instead of a dead-end webview or placeholder detail page.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Dio, WKIM SDK, mobile_scanner, PowerShell, TangSengDaoDao Android reference, TangSengDaoDao server reference

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Progress Snapshot (2026-04-08)

This plan is no longer at the original "implementation not started" state.

- Code status:
  - `GroupInfo` and `GroupApi` truthful contract work is implemented.
  - Live `GroupDetailPage` advanced settings and invite-mode add branching are implemented.
  - `AllMembersPage(searchMessage: true)` routing and compatibility wrapper convergence are implemented.
  - Native scan-to-join flow is implemented.
- Fresh verification status:
  - `flutter analyze lib/data/models/group.dart lib/service/api/group_api.dart lib/wukong_uikit/group lib/wukong_scan lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/search_with_member_page.dart` passed on `2026-04-08`.
  - `flutter test test/data/models/group_test.dart test/service/api/group_api_test.dart test/wukong_uikit/group/group_detail_page_parity_test.dart test/wukong_uikit/group/group_detail_page_settings_test.dart test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart test/wukong_scan/scan_service_test.dart test/wukong_scan/scan_result_page_group_flow_test.dart test/wukong_uikit/group/group_scan_join_page_test.dart` passed on `2026-04-08`.
- Real runtime evidence already collected:
  - Group-detail truthful toggles were exercised against the deployed backend and persisted successfully.
  - Invite-only normal-member add flow now has composite proof:
    - live release-page affordance screenshot
    - production widget regression test
    - deployed nginx route hit for `POST /member/invite`
    - deployed MySQL invite persistence
  - Manual probe screenshots exist for:
    - active-member scan CTA visible and active-member scan transition into `ChatPage`
    - all-members search mode
    - removed-member scan state
    - internal join-group scan state
    - group scan join page
- Manual/runtime closure update:
  - the earlier active-member scan evidence gap is now closed by `docs/superpowers/artifacts/2026-04-08-scan-active-runtime-evidence.md`
  - the capture shows the CTA-visible scan result state and the resulting `ChatPage` destination reached in the Windows runtime probe

## Spec Boundary

This plan implements only `Phase 3: Finish Group Advanced Parity` from [2026-04-07-android-reference-parity-master-blueprint.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/plans/2026-04-07-android-reference-parity-master-blueprint.md).

In scope:

- truthful `GroupInfo` and `GroupApi` coverage for server-backed advanced group settings
- authoritative group-detail toggles for real invite or history or join-remind behavior
- invite-mode add-member behavior that matches Android instead of hiding the add affordance
- Android `searchMessage` member-picker parity from the all-members surface
- native handling for internal group-join QR and H5 scan results
- focused model or API or widget or routing regression tests for the above

Out of scope for this plan:

- multi-party call work from later phases
- vendor push, secure-screen, backup, or sensitive-word work from later phases
- chat-password, screenshot, or flame UI if no production Flutter entry is being wired in this phase
- speculative `need_approval`, `member_invite`, `member_edit`, `invite/info`, `invite/accept`, or `invite/decline` production UI unless the deployed backend proves those contracts exist

## Current Truth Constraints

These facts were confirmed in source and must stay true throughout implementation:

- `lib/wukong_uikit/group/group_detail_page.dart` is already strong on member add or remove, manager promote or demote, owner transfer, group notice, group QR, save or mute or top, Feishu bot, and group reminder. Do not rebuild it from scratch.
- `lib/data/models/group.dart` does **not** currently model several Android or server-backed fields that exist in the reference stack, including `join_group_remind`, `revoke_remind`, `receipt`, `forbidden_add_friend`, `screenshot`, and `chat_pwd_on`. It also misses Android metadata such as `created_at` and `updated_at`.
- Local server source confirms that `PUT /v1/groups/:group_no/setting` accepts both personal group-setting keys and selected group-attribute keys through one route:
  - personal setting keys: `mute`, `top`, `save`, `show_nick`, `chat_pwd_on`, `screenshot`, `join_group_remind`, `revoke_remind`, `receipt`, `remark`, `flame`, `flame_second`
  - group attribute keys: `forbidden`, `forbidden_add_friend`, `invite`, `allow_view_history_msg`, `allow_member_pinned_message`
- `lib/service/api/group_api.dart` already exposes `setGroupJoinApproval`, `setGroupMemberInvitePermission`, `setGroupMemberEditPermission`, `getGroupInviteInfo`, `acceptGroupInvite`, and `declineGroupInvite`, but those contracts were **not** found in the local `TangSengDaoDaoServer-main` source. They must not be counted as real parity until the deployed backend proves them.
- The live Android-flavored settings section in Flutter currently omits `show_nick`. The `show_nick` toggle still exists only in the unused `_buildSettingsSection()` path inside `group_detail_page.dart`.
- In Flutter invite mode, normal members currently lose the add-member affordance entirely and the visible flow always calls `addGroupMembers(...)`. Android keeps the add affordance visible, then switches between direct add and invite flow depending on role and invite mode.
- Android `WKAllMembersActivity` has a `searchMessage` mode. In that mode, tapping a member opens a member-scoped message-results surface instead of `UserDetailActivity`.
- Flutter `lib/wukong_uikit/group/all_members_page.dart` only opens `UserDetailPage` today and has no `searchMessage` mode.
- Local server QR logic returns two distinct group-scan outcomes:
  - already a member: native `type=group` with `group_no`
  - not yet a member: H5 `join_group.html?group_no=...&auth_code=...`
- Flutter `lib/wukong_scan/scan_result_page.dart` currently treats `type=group` as a direct `GroupDetailPage` entry and treats generic webview results as open-link or copy-link utilities. It does not close the native join flow or the existing-member vs removed-member split.
- Android `wkscan/src/main/java/com/chat/scan/ScanUtils.java` still leaves the non-member group-join path as a `TODO`. Flutter should not copy that incomplete state forward as a parity success.

## Android And Server Reference Anchors

Use these files as the truth sources while implementing:

- Android group detail:
  - `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/group/GroupDetailActivity.java`
  - `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/group/GroupEntity.java`
  - `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/contacts/ChooseContactsActivity.java`
- Android all-members search mode:
  - `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/group/WKAllMembersActivity.java`
- Android scan handling:
  - `TangSengDaoDaoAndroid-master/wkscan/src/main/java/com/chat/scan/ScanUtils.java`
- Server group settings and scan join:
  - `TangSengDaoDaoServer-main/modules/group/api.go`
  - `TangSengDaoDaoServer-main/modules/group/api_setting_action.go`
  - `TangSengDaoDaoServer-main/modules/qrcode/api.go`

## Authority Decisions Locked Before Coding

The following owners are fixed for this phase:

- `Group detail production owner:` `lib/wukong_uikit/group/group_detail_page.dart`
- `Group detail data contract owner:` `lib/data/models/group.dart`
- `Group settings transport owner:` `lib/service/api/group_api.dart`
- `All-members production owner:` `lib/wukong_uikit/group/all_members_page.dart`
- `Member-search results owner:` `lib/modules/search/presentation/chat_search_member_page.dart`
- `Group search compatibility wrapper:` `lib/modules/search/search_with_member_page.dart`
- `Scan result contract owner:` `lib/wukong_scan/scan_service.dart`
- `Scan result routing owner:` `lib/wukong_scan/scan_result_page.dart`
- `Native join-confirm surface:` `lib/wukong_uikit/group/group_scan_join_page.dart` (new)

Do **not** create a second production group-detail implementation, a second scan owner path, or a second member-results page.

## File Structure

### New Files

- `lib/wukong_uikit/group/group_scan_join_page.dart`
  - Native confirmation page for internal `join_group.html?group_no=...&auth_code=...` results.
- `test/service/api/group_api_test.dart`
  - Locks request bodies and endpoints for the new server-backed group-setting helpers and scan-join API.
- `test/wukong_uikit/group/group_detail_page_settings_test.dart`
  - Mounts the real page and catches live-section regressions that helper-only tests miss.
- `test/wukong_uikit/group/all_members_page_search_mode_test.dart`
  - Verifies `searchMessage` mode title and navigation behavior.
- `test/wukong_uikit/group/group_scan_join_page_test.dart`
  - Verifies loading, success, failure, and invite-only scan-join states.
- `test/wukong_scan/scan_result_page_group_flow_test.dart`
  - Verifies existing-member, removed-member, and non-member group scan routing.

### Existing Files To Modify

- `lib/data/models/group.dart`
  - Add missing Android or server-backed fields and keep JSON serialization symmetric.
- `lib/service/api/group_api.dart`
  - Add truthful server-backed helper methods used by the production group-detail and scan-join flows.
- `lib/wukong_uikit/group/group_detail_page.dart`
  - Surface the remaining real advanced toggles, move `show_nick` into the live Android section, and fix invite-mode add behavior.
- `lib/wukong_uikit/group/all_members_page.dart`
  - Add Android-style `searchMessage` mode while keeping current user-detail mode intact.
- `lib/modules/search/presentation/chat_search_entry_page.dart`
  - Route the group member-search entry through `AllMembersPage(searchMessage: true)` for group channels.
- `lib/modules/search/search_with_member_page.dart`
  - Keep the compatibility naming path aligned with the updated member-search owner decision.
- `lib/wukong_scan/scan_service.dart`
  - Parse internal join-group H5 URLs into structured getters instead of treating them as opaque external links.
- `lib/wukong_scan/scan_result_page.dart`
  - Route native group results by membership state and internal join-group results into the new native join-confirm page.
- `test/data/models/group_test.dart`
  - Expand coverage for the missing advanced fields and `toJson()`.
- `test/wukong_uikit/group/group_detail_page_parity_test.dart`
  - Extend helper coverage for the newly surfaced rows.
- `test/modules/search/chat_search_entry_page_test.dart`
  - Lock the member-search entry behavior for the new group-channel owner path.
- `test/modules/search/chat_search_member_page_test.dart`
  - Keep locate behavior green while the member-picker surface changes.
- `test/wukong_scan/scan_service_test.dart`
  - Extend coverage for internal join-group URL parsing.

## Local Contract Verification Commands

Run these before trusting any claimed backend support:

- `Get-ChildItem -Path 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\group' -Recurse -Include '*.go' | Select-String -Pattern 'join_group_remind|receipt|invite|allow_view_history_msg|scanjoin'`
- `Get-ChildItem -Path 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\qrcode' -Recurse -Include '*.go' | Select-String -Pattern 'ForwardH5|HandlerTypeWebView|group_no|auth_code'`
- `Get-ChildItem -Path 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\wkuikit\src\main\java\com\chat\uikit\group' -Recurse -Include '*.java','*.kt' | Select-String -Pattern 'searchMessage|show_nick|save|mute|top|invite'`

If the deployed backend at `ubuntu@42.194.218.158` differs from local source, verify the real route keys there before wiring any UI for speculative methods. Do not ship UI for `need_approval`, `member_invite`, or `member_edit` purely because the Flutter wrapper methods exist.

## Verification Commands Used Throughout

- `flutter analyze lib/data/models/group.dart lib/service/api/group_api.dart lib/wukong_uikit/group lib/wukong_scan lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/search_with_member_page.dart`
- `flutter test test/data/models/group_test.dart test/service/api/group_api_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart test/wukong_uikit/group/group_detail_page_settings_test.dart`
- `flutter test test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart`
- `flutter test test/wukong_scan/scan_service_test.dart test/wukong_scan/scan_result_page_group_flow_test.dart test/wukong_uikit/group/group_scan_join_page_test.dart`

### Task 1: Freeze The Truthful Group Contract Before Touching UI

**Files:**
- Modify: `test/data/models/group_test.dart`
- Create: `test/service/api/group_api_test.dart`
- Modify: `lib/data/models/group.dart`
- Modify: `lib/service/api/group_api.dart`

- [ ] **Step 1: Write the failing model and API contract tests**

Expand `test/data/models/group_test.dart` so it expects `GroupInfo.fromJson(...)` and `toJson()` to cover at least these fields:

- `join_group_remind`
- `revoke_remind`
- `receipt`
- `forbidden_add_friend`
- `screenshot`
- `chat_pwd_on`
- `allow_view_history_msg`
- `created_at`
- `updated_at`

Create `test/service/api/group_api_test.dart` with expectations that the production helpers use:

- `PUT /v1/groups/:group_no/setting` with `{ "invite": 1 | 0 }`
- `PUT /v1/groups/:group_no/setting` with `{ "join_group_remind": 1 | 0 }`
- `PUT /v1/groups/:group_no/setting` with `{ "allow_view_history_msg": 1 | 0 }`
- `GET /v1/groups/:group_no/scanjoin?auth_code=...` for the scan-join contract

- [ ] **Step 2: Run the contract tests to verify they fail against the current model and API surface**

Run:

- `flutter test test/data/models/group_test.dart`
- `flutter test test/service/api/group_api_test.dart`

Expected: FAIL because the model does not expose all fields yet and the dedicated helpers do not exist yet.

- [ ] **Step 3: Extend `GroupInfo` to match the real server-backed field set**

Add these nullable fields to `lib/data/models/group.dart` and wire them through both `fromJson(...)` and `toJson()`:

- `int? joinGroupRemind`
- `int? revokeRemind`
- `int? receipt`
- `int? forbiddenAddFriend`
- `int? screenshot`
- `int? chatPwdOn`
- `String? createdAt`
- `String? updatedAt`

Keep the existing `allowViewHistoryMsg`, `invite`, `mute`, `top`, `save`, and `showNick` fields authoritative.

- [ ] **Step 4: Add truthful server-backed helpers to `GroupApi`**

Add explicit methods to `lib/service/api/group_api.dart`:

- `Future<void> setGroupInviteMode(String groupNo, bool inviteOnly)`
- `Future<void> setGroupJoinGroupRemind(String groupNo, bool enabled)`
- `Future<void> setGroupAllowViewHistory(String groupNo, bool enabled)`
- `Future<void> scanJoinGroup(String groupNo, String authCode)`

Each method must call the confirmed server route and payload instead of relying on page-local string literals.

- [ ] **Step 5: Mark speculative wrappers as non-authoritative in code comments**

In `lib/service/api/group_api.dart`, add short comments above these existing methods:

- `getGroupInviteInfo`
- `acceptGroupInvite`
- `declineGroupInvite`
- `setGroupJoinApproval`
- `setGroupMemberInvitePermission`
- `setGroupMemberEditPermission`

Those comments must state that local `TangSengDaoDaoServer-main` source did not confirm the contract and that the methods are not yet wired into production parity flows.

- [ ] **Step 6: Rerun the contract verification**

Run:

- `flutter test test/data/models/group_test.dart`
- `flutter test test/service/api/group_api_test.dart`
- `flutter analyze lib/data/models/group.dart lib/service/api/group_api.dart`

Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/data/models/group.dart lib/service/api/group_api.dart test/data/models/group_test.dart test/service/api/group_api_test.dart
git commit -m "feat: lock truthful group settings contract"
```

### Task 2: Fix The Live Group Settings Surface And Invite-Mode Add Flow

**Files:**
- Create: `test/wukong_uikit/group/group_detail_page_settings_test.dart`
- Modify: `lib/wukong_uikit/group/group_detail_page.dart`
- Modify: `test/wukong_uikit/group/group_detail_page_parity_test.dart`

- [ ] **Step 1: Write the failing live-page tests for the real Android section**

Create `test/wukong_uikit/group/group_detail_page_settings_test.dart` so it mounts the real page and catches these live-surface requirements:

- the rendered Android settings section shows `show_nick` in the live path, not only in dead code
- the rendered Android settings section also shows `Invite-only mode`, `New members can view history`, and `Join-group reminder`
- in invite mode, a normal member still sees the add-member affordance
- in invite mode, a normal member uses `inviteMembers(...)` instead of `addGroupMembers(...)`
- in non-invite mode or manager-owner mode, the add flow still uses `addGroupMembers(...)`

Keep `test/wukong_uikit/group/group_detail_page_parity_test.dart` focused on helper row order.

- [ ] **Step 2: Run the group-detail tests to confirm the live gaps**

Run:

- `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_page_settings_test.dart`

Expected: FAIL because the live Android settings section currently omits `show_nick` and the invite-mode add flow is wrong.

- [ ] **Step 3: Extend the live page state with the missing truthful settings**

In `lib/wukong_uikit/group/group_detail_page.dart`:

- add local state for `_inviteOnly`, `_joinGroupRemind`, and `_allowViewHistory`
- sync those values from `GroupInfo` inside `_syncSettingsFromGroup(...)`
- update `_currentSettingValue(...)` and `_applyLocalSetting(...)` so optimistic updates and rollback work for the new keys
- move `show_nick` into the live `_buildAndroidSettingsSection()` path

- [ ] **Step 4: Render the real advanced switches from the live Android section**

Add a built-in advanced-settings section to the live Android layout:

- `Show member nicknames`
  - visible in the live Android section
  - uses the existing `show_nick` contract
- `Invite-only mode`
  - visible to users who can manage the group
  - uses `GroupApi.instance.setGroupInviteMode(...)`
- `New members can view history`
  - visible to users who can manage the group
  - uses `GroupApi.instance.setGroupAllowViewHistory(...)`
- `Join-group reminder`
  - visible to all current members
  - uses `GroupApi.instance.setGroupJoinGroupRemind(...)`

Do **not** wait for slot registrations here. No production `groupDetailExtensionSlot` registrations were found in `lib/`, so the live page must render the truthful rows itself.

- [ ] **Step 5: Fix invite-mode member addition without hiding the add entry**

Update the add-member flow so:

- the add affordance stays visible when the user is in the group
- owner or admin paths keep using `addGroupMembers(...)`
- normal members in invite mode use `inviteMembers(...)`
- success and failure messages distinguish direct add from invite request

Do **not** regress member remove, manager promote or demote, owner transfer, or search-history entry behavior.

- [ ] **Step 6: Rerun group-detail verification**

Run:

- `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_page_settings_test.dart`
- `flutter analyze lib/wukong_uikit/group/group_detail_page.dart`

Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/wukong_uikit/group/group_detail_page.dart test/wukong_uikit/group/group_detail_page_parity_test.dart test/wukong_uikit/group/group_detail_page_settings_test.dart
git commit -m "feat: align live group settings and invite mode add flow"
```

### Task 3: Add Android `searchMessage` Mode Without Forking The Results Owner

**Files:**
- Create: `test/wukong_uikit/group/all_members_page_search_mode_test.dart`
- Modify: `lib/wukong_uikit/group/all_members_page.dart`
- Modify: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Modify: `lib/modules/search/search_with_member_page.dart`
- Modify: `test/wukong_uikit/group/all_members_page_parity_test.dart`
- Modify: `test/modules/search/chat_search_entry_page_test.dart`
- Modify: `test/modules/search/chat_search_member_page_test.dart`

- [ ] **Step 1: Write the failing tests for `searchMessage` mode**

Create `test/wukong_uikit/group/all_members_page_search_mode_test.dart` so it expects:

- `AllMembersPage(searchMessage: true, ...)` uses the Android-style title behavior
- tapping a member in `searchMessage` mode does **not** open `UserDetailPage`
- tapping a member in `searchMessage` mode opens the existing group member-search results flow
- default mode still opens `UserDetailPage`

Extend `test/modules/search/chat_search_entry_page_test.dart` so the group member-search tile reaches the new member-picker flow.

- [ ] **Step 2: Run the member-search tests to confirm the current mode is missing**

Run:

- `flutter test test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart`

Expected: FAIL because `AllMembersPage` has no `searchMessage` mode and always opens `UserDetailPage`.

- [ ] **Step 3: Add `searchMessage` mode to `AllMembersPage`**

In `lib/wukong_uikit/group/all_members_page.dart`:

- add `bool searchMessage = false`
- add `String? channelName`
- when `searchMessage` is false, keep the current `UserDetailPage` navigation
- when `searchMessage` is true, build a `SearchMemberHit` from the selected `GroupMember` and open the existing member-search results owner

Do not create a second member-results page.

- [ ] **Step 4: Make `AllMembersPage(searchMessage: true)` the active group member-picker**

In `lib/modules/search/presentation/chat_search_entry_page.dart`:

- route the group-channel member-search tile to `AllMembersPage(searchMessage: true, ...)`
- keep `ChatSearchMemberResultsPage` as the only member-results owner
- keep `SearchWithMemberPage` as a compatibility wrapper over the same owner path

Add a short comment near the route decision so later cleanup knows that the group member-picker authority now lives in `AllMembersPage`.

- [ ] **Step 5: Preserve locate-to-chat behavior**

Rerun and fix any breakage so member-scoped results still:

- use the existing locate resolver source tags
- open `ChatPageShell` correctly
- keep the result list and retry behavior already covered by `chat_search_member_page_test.dart`

- [ ] **Step 6: Rerun the member-search verification**

Run:

- `flutter test test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart`
- `flutter analyze lib/wukong_uikit/group/all_members_page.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/search_with_member_page.dart`

Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/wukong_uikit/group/all_members_page.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/search_with_member_page.dart test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart
git commit -m "feat: add android-style member search mode for groups"
```

### Task 4: Close The Native Scan-To-Join Group Flow

**Files:**
- Create: `lib/wukong_uikit/group/group_scan_join_page.dart`
- Create: `test/wukong_uikit/group/group_scan_join_page_test.dart`
- Create: `test/wukong_scan/scan_result_page_group_flow_test.dart`
- Modify: `lib/wukong_scan/scan_service.dart`
- Modify: `lib/wukong_scan/scan_result_page.dart`
- Modify: `test/wukong_scan/scan_service_test.dart`

- [ ] **Step 1: Write the failing scan parsing and routing tests**

Extend `test/wukong_scan/scan_service_test.dart` so it expects `ScanServiceResult` to recognize an internal join-group H5 URL such as:

- `https://<internal-host>/join_group.html?group_no=g_1001&auth_code=auth_123`

The result object must expose structured getters for:

- `joinGroupNo`
- `joinGroupAuthCode`
- `isInternalJoinGroupUrl`

Create `test/wukong_scan/scan_result_page_group_flow_test.dart` with expectations that:

- native `type=group` routes active members into `ChatPage`
- removed members see an error or disabled state instead of `GroupDetailPage`
- internal join-group URLs route to a native join-confirm page instead of a generic link utility

- [ ] **Step 2: Run the scan tests to verify they fail**

Run:

- `flutter test test/wukong_scan/scan_service_test.dart`
- `flutter test test/wukong_scan/scan_result_page_group_flow_test.dart`

Expected: FAIL because `ScanServiceResult` currently only exposes generic `url` and `groupId` helpers and `ScanResultPage` hardwires group scans to `GroupDetailPage`.

- [ ] **Step 3: Teach `ScanServiceResult` about internal join-group H5 URLs**

In `lib/wukong_scan/scan_service.dart`:

- parse `result.url` when `type == 'webview'`
- detect the internal `join_group.html` path
- expose:
  - `String? get joinGroupNo`
  - `String? get joinGroupAuthCode`
  - `bool get isInternalJoinGroupUrl`

Do not break existing `loginConfirm`, `userInfo`, `group`, or plain external URL behavior.

- [ ] **Step 4: Build the native join-confirm surface**

Create `lib/wukong_uikit/group/group_scan_join_page.dart` with these states:

- loading group info from `GroupApi.instance.getGroupInfo(groupNo)`
- success state with group avatar or name plus a primary join action
- join action calling `GroupApi.instance.scanJoinGroup(groupNo, authCode)`
- disabled or explanatory state when the group is invite-only or the server rejects direct scan join
- post-success navigation into `ChatPage(channelId: groupNo, channelType: WKChannelType.group)` instead of returning to a dead-end result page

Reuse current design tokens and `WKSubPageScaffold`. Do not create a second generic scan shell.

- [ ] **Step 5: Route native group results by membership state**

In `lib/wukong_scan/scan_result_page.dart`:

- keep login-confirm handling unchanged
- keep user-info handling unchanged
- keep generic external URLs unchanged
- for native `type=group`, resolve current membership state before choosing the CTA:
  - active member -> open `ChatPage`
  - removed member -> show an error or disabled state
  - non-member with an internal join-group URL -> open `GroupScanJoinPage`
- when `result.isInternalJoinGroupUrl` is true, push `GroupScanJoinPage`

Do not count a generic "open link" button as parity for internal group join.

- [ ] **Step 6: Rerun the scan and join verification**

Run:

- `flutter test test/wukong_scan/scan_service_test.dart test/wukong_scan/scan_result_page_group_flow_test.dart test/wukong_uikit/group/group_scan_join_page_test.dart`
- `flutter analyze lib/wukong_scan lib/wukong_uikit/group/group_scan_join_page.dart`

Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/wukong_scan/scan_service.dart lib/wukong_scan/scan_result_page.dart lib/wukong_uikit/group/group_scan_join_page.dart test/wukong_scan/scan_service_test.dart test/wukong_scan/scan_result_page_group_flow_test.dart test/wukong_uikit/group/group_scan_join_page_test.dart
git commit -m "feat: add native group scan join flow"
```

## Final Verification Sweep

- [ ] Run `flutter analyze lib/data/models/group.dart lib/service/api/group_api.dart lib/wukong_uikit/group lib/wukong_scan lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/search_with_member_page.dart`
- [ ] Run `flutter test test/data/models/group_test.dart test/service/api/group_api_test.dart`
- [ ] Run `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart test/wukong_uikit/group/group_detail_page_settings_test.dart`
- [ ] Run `flutter test test/wukong_uikit/group/all_members_page_parity_test.dart test/wukong_uikit/group/all_members_page_search_mode_test.dart`
- [ ] Run `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_member_page_test.dart`
- [ ] Run `flutter test test/wukong_scan/scan_service_test.dart test/wukong_scan/scan_result_page_group_flow_test.dart test/wukong_uikit/group/group_scan_join_page_test.dart`
- [ ] Manually verify these user journeys:
  - group detail can toggle the new truthful switches and refreshes correctly
  - the live Android section now shows `show_nick`
  - invite-mode normal-member add uses invite flow while manager-owner add still uses direct add
  - all-members normal mode still opens user details
  - all-members `searchMessage` mode reaches member-scoped message results
  - scanning an internal group QR as an active member reaches `ChatPage`
  - scanning an internal group QR as a removed member no longer falls into `GroupDetailPage`
  - scanning an internal group QR as a non-member no longer dead-ends on a generic web link

## Exit Gate

This child plan is only complete when all of the following are true:

- `GroupInfo` models the real advanced fields that exist in Android or local server source for this phase
- the live `GroupDetailPage` surface, not just helper methods, exposes truthful production toggles and does not pretend speculative backend wrappers are complete
- invite-mode add behavior matches Android instead of hiding the add affordance
- `AllMembersPage` has Android-style `searchMessage` behavior without forking the message-results owner
- internal join-group QR or H5 results land on a native Flutter confirmation flow instead of a dead-end external-link result
- the production parity claim does **not** depend on unverified `need_approval`, `member_invite`, `member_edit`, `invite/info`, `invite/accept`, or `invite/decline` contracts

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-07-group-advanced-parity.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, and keep each write scope small. Per your instruction, every subagent will use `gpt-5.3-codex` with `xhigh` reasoning.

**2. Inline Execution** - Execute tasks in this session using the same task order, with checkpoints after each task.

If we continue immediately, the recommended next move is Task 1 with subagent-driven execution.
