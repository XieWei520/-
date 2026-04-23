# User Center, Settings, Favorites, And Moments Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge the active Flutter personal-center mainline so `lib/modules/user/user_page.dart` and `lib/wukong_uikit/setting/setting_page.dart` become the only real production entry surfaces for settings, privacy/security, favorites, moments, and PC/Web login management.

**Architecture:** Keep the visible shells that are already wired into the app, but collapse their hidden duplicate owners. `UserPage` remains the single "Me" tab shell, `SettingPage` remains the single generic settings shell, detailed privacy/security flows move under `lib/modules/settings/**`, favorites gets a dedicated production page instead of the stub inside `chat_page.dart`, and `MomentsPage` keeps its existing UI while its data layer is converged onto the canonical `MomentsApi` contract.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Dio, WKIM SDK, slot registry assembly, existing search locate infrastructure, PowerShell

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoint commands for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Scope Boundary

This plan only implements Phase 1 from the approved master blueprint at [2026-04-07-android-reference-parity-master-blueprint.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/plans/2026-04-07-android-reference-parity-master-blueprint.md).

In scope:

- active personal-center menu ownership and entry wiring
- active settings-shell ownership and section wiring
- privacy settings, notification settings, blacklist, account security, and device list convergence
- a real favorites center backed by `CollectionApi`
- mainline moments entry wiring and moments API ownership convergence
- retirement or isolation of obsolete user/settings/device paths
- focused tests, compile coverage, and targeted backend-contract verification where source ownership is unclear

Out of scope for this plan:

- wallet, album, emoji store, and other non-Phase-1 "Me" tab features
- backup/restore, sensitive-word, or prohibit-word product work
- broader auth/password-reset redesign beyond what is needed to remove fake account-security behavior from the production path
- non-Android-first UI experimentation

## Truth Constraints

These facts were confirmed in source and must not be papered over during execution:

- `lib/modules/chat/chat_page.dart` still exposes `FavoritesPage` as a stub that only renders `"Favorites"`.
- `lib/modules/moments/moments_page.dart` is already real enough to keep, but its data ownership overlaps with `MomentsApi` in `lib/service/api/collection_api.dart`.
- `lib/modules/settings/privacy_settings_page.dart` contains real notification, privacy, blacklist, account-security, and device-list flows, but it also contains duplicate placeholder code and currently acts as a monolith.
- `AccountSecurityPage` is **not** complete today. Device listing is real, but "change login password" and "change chat password" are placeholder dialogs that only show snackbars.
- `lib/modules/settings/device_management_page.dart` is a parallel device-management implementation using `DeviceApi`; it must not remain a second production owner after this phase.
- `lib/wukong_uikit/setting/privacy_settings_page.dart` and `lib/modules/user/user_page_complete.dart` are legacy branches and must not remain production entry owners.

**Hard rule:** do not mark Phase 1 complete while placeholder account-security actions are still visible in the production path. Those actions must either be backed by real contracts or removed/hidden until a later dedicated security phase lands.

## Authority Decisions Locked Before Coding

The following owners are fixed for this phase:

- `Active Me tab shell:` `lib/modules/user/user_page.dart`
- `Personal-center menu assembly:` `lib/modules/user/user_slot_assembly.dart`
- `Active settings shell:` `lib/wukong_uikit/setting/setting_page.dart`
- `Settings section assembly:` `lib/wukong_uikit/setting/setting_slot_assembly.dart`
- `Detailed privacy/security pages:` `lib/modules/settings/**`
- `Favorites feature:` `lib/modules/favorites/**` (new authoritative path)
- `Moments feature UI:` `lib/modules/moments/**`
- `Favorites/moments/settings API authority:` `lib/service/api/collection_api.dart`

Legacy paths that may remain only as wrappers or compile shims during migration:

- `lib/modules/user/user_page_complete.dart`
- `lib/wukong_uikit/setting/privacy_settings_page.dart`
- `lib/modules/settings/device_management_page.dart`
- `FavoritesPage` inside `lib/modules/chat/chat_page.dart`
- raw direct moments HTTP code inside `lib/modules/moments/moments_service.dart`

## File Structure

### New Files

- `lib/modules/favorites/favorites_page.dart`
  - Authoritative favorites center with list, search, delete, empty, error, and refresh states.
- `lib/modules/favorites/favorite_record.dart`
  - Normalizes `CollectionApi` payloads into a UI-safe model and records optional locate metadata without assuming every payload can jump back into chat.
- `lib/modules/settings/notification_settings_page.dart`
  - Owns the production notification-settings page moved out of the monolithic settings file.
- `lib/modules/settings/blacklist_page.dart`
  - Owns the production blacklist page.
- `lib/modules/settings/account_security_page.dart`
  - Owns the production account-security shell and becomes the only place allowed to expose device and password-related actions.
- `lib/modules/settings/device_list_page.dart`
  - Owns the production device-list page.
- `lib/modules/settings/settings_surface_widgets.dart`
  - Holds shared settings hero, scaffold, section, action tile, and switch tile widgets extracted from the current monolith.
- `test/modules/favorites/favorites_page_test.dart`
  - Verifies favorites loading, searching, deletion, and empty/error states.
- `test/modules/moments/moments_service_test.dart`
  - Verifies `MomentsService` delegates to `MomentsApi`-compatible payloads.
- `test/modules/settings/settings_pages_compile_test.dart`
  - Verifies the authoritative `modules/settings` pages compile and the old wrapper paths are no longer the production owner.

### Existing Files To Modify

- `lib/modules/user/user_page.dart`
  - Add real entry wiring for favorites, moments, privacy settings, and account security.
- `lib/modules/user/user_slot_assembly.dart`
  - Register and resolve the expanded Android-aligned menu set from one slot owner.
- `lib/wk_endpoint/slots/settings_slots.dart`
  - Extend `SettingsSlotContext` with callbacks for notification, privacy, and account-security navigation.
- `lib/wukong_uikit/setting/setting_slot_assembly.dart`
  - Add stable ordered sections for notification and privacy/security entries.
- `lib/wukong_uikit/setting/setting_page.dart`
  - Pass the new callbacks and open the authoritative `modules/settings` detail pages.
- `lib/modules/settings/privacy_settings_page.dart`
  - Reduce to the privacy-settings page only, after shared widgets and sibling pages are extracted.
- `lib/modules/settings/device_management_page.dart`
  - Convert to a deprecated wrapper, or remove from production routing if nothing imports it.
- `lib/wukong_uikit/setting/privacy_settings_page.dart`
  - Convert to a deprecated wrapper over `modules/settings/privacy_settings_page.dart`.
- `lib/modules/chat/chat_page.dart`
  - Stop owning the favorites implementation; keep only a compatibility export or wrapper.
- `lib/modules/moments/moments_service.dart`
  - Delegate to `MomentsApi` instead of remaining a parallel raw-HTTP owner.
- `lib/service/api/collection_api.dart`
  - Extend tests and normalization helpers only where Phase 1 requires them; this remains the API authority.
- `test/modules/user/user_page_parity_test.dart`
  - Expand expectations to cover the new personal-center entries.
- `test/modules/user/user_page_slot_assembly_test.dart`
  - Expand slot-order and callback tests for the new menu entries.
- `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
  - Expand section-order and callback expectations for notification/privacy/security convergence.
- `test/service/api/collection_api_test.dart`
  - Add coverage for favorites list/delete normalization if the new page depends on it.
- `test/modules/shell/main_pages_compile_test.dart`
  - Include `FavoritesPage` and `MomentsPage` compile coverage through the production import paths.

## Remote Contract Verification

Only use remote debugging if local source cannot settle a contract question. This phase allows server-assisted verification through `ssh root@103.207.68.33`.

Use remote inspection when:

- favorites list/search/delete payloads differ from the assumptions needed by `FavoriteRecord`
- moments list/detail payloads differ between `MomentsService` and `MomentsApi`
- `SettingsApi` endpoints for user settings, device lock, blacklist, or device list do not behave like the Flutter client expects
- password-related actions appear in Android but no matching client/server contract is obvious locally

Minimum remote checks:

- `ssh root@103.207.68.33 "grep -n '/v1/extra/favorites' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`
- `ssh root@103.207.68.33 "grep -n '/v1/extra/moments' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`
- `ssh root@103.207.68.33 "grep -n '/v1/extra/user/setting' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`
- `ssh root@103.207.68.33 "grep -n '/v1/extra/user/devices' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`

## Verification Commands Used Throughout

- `flutter analyze lib/modules/user lib/modules/settings lib/modules/favorites lib/modules/moments lib/modules/chat/chat_page.dart lib/wukong_uikit/setting lib/wk_endpoint/slots/settings_slots.dart lib/service/api/collection_api.dart`
- `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart`
- `flutter test test/wukong_uikit/setting/setting_page_slot_assembly_test.dart test/modules/settings/settings_pages_compile_test.dart`
- `flutter test test/modules/favorites/favorites_page_test.dart test/service/api/collection_api_test.dart`
- `flutter test test/modules/moments/moments_service_test.dart test/modules/shell/main_pages_compile_test.dart`

### Task 1: Split The Settings Detail Stack Into One Authoritative `modules/settings` Owner

**Files:**
- Create: `lib/modules/settings/settings_surface_widgets.dart`
- Create: `lib/modules/settings/notification_settings_page.dart`
- Create: `lib/modules/settings/blacklist_page.dart`
- Create: `lib/modules/settings/account_security_page.dart`
- Create: `lib/modules/settings/device_list_page.dart`
- Modify: `lib/modules/settings/privacy_settings_page.dart`
- Modify: `lib/modules/settings/device_management_page.dart`
- Modify: `lib/wukong_uikit/setting/privacy_settings_page.dart`
- Test: `test/modules/settings/settings_pages_compile_test.dart`

- [ ] **Step 1: Write the failing compile test that locks the new settings ownership**

Create `test/modules/settings/settings_pages_compile_test.dart` with compile expectations for:

- `PrivacySettingsPage`
- `NotificationSettingsPage`
- `BlacklistPage`
- `AccountSecurityPage`
- `DeviceListPage`

The test must import these classes from `lib/modules/settings/**`, not from `lib/wukong_uikit/setting/**`.

- [ ] **Step 2: Run the compile test to verify the new files do not exist yet**

Run: `flutter test test/modules/settings/settings_pages_compile_test.dart`
Expected: FAIL with missing imports or missing symbols from `lib/modules/settings/**`

- [ ] **Step 3: Extract the shared widgets and move the real page classes out of the monolith**

Perform these exact moves:

- move `_SettingsScaffold`, `_SettingsHero`, `_SettingsSection`, `_SwitchSettingTile`, and `_ActionSettingTile` out of `lib/modules/settings/privacy_settings_page.dart` into `lib/modules/settings/settings_surface_widgets.dart`
- move `NotificationSettingsPage` out of `lib/modules/settings/privacy_settings_page.dart` into `lib/modules/settings/notification_settings_page.dart`
- move `BlacklistPage` into `lib/modules/settings/blacklist_page.dart`
- move `AccountSecurityPage` into `lib/modules/settings/account_security_page.dart`
- move `_DeviceListPage` into `lib/modules/settings/device_list_page.dart` and rename it to public `DeviceListPage`
- leave `PrivacySettingsPage` in `lib/modules/settings/privacy_settings_page.dart` as the only production page in that file

- [ ] **Step 4: Convert duplicate legacy pages into wrappers instead of parallel production owners**

Apply these constraints:

- `lib/wukong_uikit/setting/privacy_settings_page.dart` becomes a thin deprecated wrapper around `modules/settings/privacy_settings_page.dart`
- `lib/modules/settings/device_management_page.dart` becomes a thin deprecated wrapper to `AccountSecurityPage` or `DeviceListPage`
- remove `_LegacyNotificationSettingsPagePlaceholder` from the production path entirely

- [ ] **Step 5: Remove fake account-security actions from the production path unless a real contract is proven**

Before this task is considered done:

- inspect Android and server contracts for change-password and chat-password actions
- if real contracts exist, record the owning client API in this plan's execution notes and wire them later in Task 5
- if real contracts do **not** exist yet, remove those two rows from the production `AccountSecurityPage` and leave device-list management as the only visible real account-security action

- [ ] **Step 6: Run the compile test again**

Run: `flutter test test/modules/settings/settings_pages_compile_test.dart`
Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/settings lib/wukong_uikit/setting/privacy_settings_page.dart test/modules/settings/settings_pages_compile_test.dart
git commit -m "refactor: converge settings detail pages under modules settings"
```

**Execution Notes**

- 2026-04-07 audit: this checkout already contains the authoritative `modules/settings` split (`settings_surface_widgets.dart`, `notification_settings_page.dart`, `blacklist_page.dart`, `account_security_page.dart`, `device_list_page.dart`) and the compile lock at `test/modules/settings/settings_pages_compile_test.dart`.
- 2026-04-07 verification: `flutter test test/modules/settings/settings_pages_compile_test.dart` passed and `flutter analyze lib/modules/settings lib/wukong_uikit/setting/privacy_settings_page.dart` passed in the controller session.
- 2026-04-07 contract note: Flutter already exposes a real login-password contract through `lib/service/api/auth_api.dart` via `AuthApi.changePassword(...)` and reset-password flows in the auth module, so any future account-security password row must wire to that authority instead of a placeholder snackbar.
- 2026-04-07 contract note: Android still contains chat-password flows (`WKConversationPassword`, `show_set_chat_pwd`, `chat_pwd` / `lock_screen_pwd` fields), but no matching Flutter `lib/service/api/**` contract was found for chat-password management in this phase. Production `AccountSecurityPage` therefore remains device-list-only until a later dedicated security task lands.

### Task 2: Expand The Settings Shell So One `SettingPage` Reaches Every Real Detail Flow

**Files:**
- Modify: `lib/wk_endpoint/slots/settings_slots.dart`
- Modify: `lib/wukong_uikit/setting/setting_slot_assembly.dart`
- Modify: `lib/wukong_uikit/setting/setting_page.dart`
- Test: `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing slot-assembly expectations for notification/privacy/security**

Extend `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart` so it expects:

- a stable ordered section list containing `settings.notification` and `settings.privacy_security`
- cells for `settings.notification`, `settings.privacy`, and `settings.account_security`
- `SettingsSlotContext` callbacks for those three cells

- [ ] **Step 2: Run the slot-assembly test to verify the current shell does not expose those sections**

Run: `flutter test test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
Expected: FAIL because `SettingsSlotContext` and `setting_slot_assembly.dart` do not yet expose the new entries

- [ ] **Step 3: Extend `SettingsSlotContext` with the new navigation callbacks**

Add these callbacks to `lib/wk_endpoint/slots/settings_slots.dart`:

- `openNotificationSettings`
- `openPrivacySettings`
- `openAccountSecurity`

Do not create a second settings context object. Extend the existing one so the slot assembly remains authoritative.

- [ ] **Step 4: Rebuild the settings section map in `setting_slot_assembly.dart`**

Make the authoritative order:

1. `settings.appearance`
2. `settings.notification`
3. `settings.privacy_security`
4. `settings.cache`
5. `settings.modules`
6. `settings.about`
7. `settings.account`

Use this stable cell layout:

- `settings.notification` section:
  - `settings.notification`
- `settings.privacy_security` section:
  - `settings.privacy`
  - `settings.account_security`

- [ ] **Step 5: Wire the callbacks in `setting_page.dart`**

`SettingPage` must push:

- `NotificationSettingsPage` from `lib/modules/settings/notification_settings_page.dart`
- `PrivacySettingsPage` from `lib/modules/settings/privacy_settings_page.dart`
- `AccountSecurityPage` from `lib/modules/settings/account_security_page.dart`

Do not push the legacy `wukong_uikit/setting/privacy_settings_page.dart` path from the production shell.

- [ ] **Step 6: Rerun the settings-shell tests**

Run: `flutter test test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/wk_endpoint/slots/settings_slots.dart lib/wukong_uikit/setting test/wukong_uikit/setting/setting_page_slot_assembly_test.dart
git commit -m "feat: wire settings shell to authoritative privacy and security pages"
```

### Task 3: Rebuild The Active User-Center Menu Around Real Production Entries

**Files:**
- Modify: `lib/modules/user/user_page.dart`
- Modify: `lib/modules/user/user_slot_assembly.dart`
- Test: `test/modules/user/user_page_parity_test.dart`
- Test: `test/modules/user/user_page_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing tests for the expanded personal-center menu**

Extend `test/modules/user/user_page_slot_assembly_test.dart` and `test/modules/user/user_page_parity_test.dart` so they expect:

- `personal_center_currency`
- `personal_center_new_msg_notice`
- `personal_center_favorites`
- `personal_center_moments`
- `personal_center_privacy`
- `personal_center_account_security`
- `personal_center_web_login`

Also assert that the new slot callbacks map to the correct page openers instead of falling through to no-op handlers.

- [ ] **Step 2: Run the user-center tests to confirm the new entries are missing**

Run: `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart`
Expected: FAIL because only settings, notifications, and web-login are currently registered

- [ ] **Step 3: Expand `user_slot_assembly.dart` into the single menu owner**

Register the new rows with stable priority ordering:

- `personal_center_currency`
- `personal_center_new_msg_notice`
- `personal_center_favorites`
- `personal_center_moments`
- `personal_center_privacy`
- `personal_center_account_security`
- `personal_center_web_login`

Map them to these page callbacks:

- settings -> `SettingPage`
- notifications -> `NotificationSettingsPage`
- favorites -> `FavoritesPage` from `lib/modules/favorites/favorites_page.dart`
- moments -> `MomentsPage`
- privacy -> `PrivacySettingsPage`
- account security -> `AccountSecurityPage`
- web login -> `PCLoginManagementPage`

- [ ] **Step 4: Update `user_page.dart` to push the new authoritative pages**

Keep `UserPage` as the active shell, but:

- pass the new callbacks into `resolvePersonalCenterMenus(...)`
- stop treating the user center as a three-row surface
- keep the version badge only on the settings/general row

- [ ] **Step 5: Restore meaningful visual grouping without creating another owner path**

Implement a simple stable grouping rule inside `user_page.dart`, similar to the existing settings gap logic, so the personal center reads as:

- settings + notifications
- favorites + moments
- privacy + account security + web login

Do this inside the active `UserPage` rendering path. Do not reintroduce `user_page_complete.dart` as the production owner.

- [ ] **Step 6: Rerun the user-center tests**

Run: `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart`
Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/user test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart
git commit -m "feat: expand personal center to real favorites moments and security entries"
```

### Task 4: Replace The Favorites Stub With A Real Collection Center

**Files:**
- Create: `lib/modules/favorites/favorite_record.dart`
- Create: `lib/modules/favorites/favorites_page.dart`
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `test/service/api/collection_api_test.dart`
- Test: `test/modules/favorites/favorites_page_test.dart`
- Test: `test/modules/shell/main_pages_compile_test.dart`

- [ ] **Step 1: Write the failing favorites page tests**

Create `test/modules/favorites/favorites_page_test.dart` with coverage for:

- first page loads from `CollectionApi.getList(...)`
- keyword search uses `CollectionApi.search(...)`
- deleting an item calls `CollectionApi.delete(...)` and removes the row from UI
- empty state renders when the list is empty
- load failure renders a retry state

- [ ] **Step 2: Run the favorites tests to confirm the current implementation is only a stub**

Run: `flutter test test/modules/favorites/favorites_page_test.dart`
Expected: FAIL because the current `FavoritesPage` contains no loading, search, or delete logic

- [ ] **Step 3: Normalize the favorites payload**

Create `FavoriteRecord` with at least these fields:

- `id`
- `title`
- `subtitle`
- `content`
- `contentType`
- `createdAt`
- optional locate fields if present in payload:
  - `channelId`
  - `channelType`
  - `messageSeq`
  - `orderSeq`

The normalization rule must be conservative:

- if the payload does not contain enough locate information, the UI may show a preview/detail view
- do **not** fake "jump back to chat" unless the payload actually provides a trustworthy route key

- [ ] **Step 4: Implement the authoritative favorites page in `lib/modules/favorites/favorites_page.dart`**

The production page must support:

- list load on entry
- pull-to-refresh
- inline search
- delete with confirmation
- empty state
- error state with retry
- stable keys for rows and search box so tests can target them

Use `CollectionApi` directly or through a tiny page-local repository. Do not keep the implementation inside `lib/modules/chat/chat_page.dart`.

- [ ] **Step 5: Convert `chat_page.dart` into a compatibility bridge**

Keep existing imports working by making `FavoritesPage` in `lib/modules/chat/chat_page.dart` either:

- a thin wrapper around `lib/modules/favorites/favorites_page.dart`, or
- a re-export-only bridge if no call sites require a concrete class in that file

The stub text-only implementation must disappear from the production codebase.

- [ ] **Step 6: Rerun favorites and collection tests**

Run:

- `flutter test test/modules/favorites/favorites_page_test.dart`
- `flutter test test/service/api/collection_api_test.dart`
- `flutter test test/modules/shell/main_pages_compile_test.dart`

Expected: PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/favorites lib/modules/chat/chat_page.dart test/modules/favorites/favorites_page_test.dart test/service/api/collection_api_test.dart test/modules/shell/main_pages_compile_test.dart
git commit -m "feat: replace favorites stub with real collection center"
```

### Task 5: Converge Moments Onto The Mainline And Close The Legacy Leaks

**Files:**
- Modify: `lib/modules/moments/moments_service.dart`
- Modify: `lib/modules/user/user_page.dart`
- Modify: `lib/modules/user/user_page_complete.dart`
- Modify: `lib/modules/settings/device_management_page.dart`
- Modify: `lib/wukong_uikit/setting/privacy_settings_page.dart`
- Test: `test/modules/moments/moments_service_test.dart`
- Test: `test/modules/shell/main_pages_compile_test.dart`

- [ ] **Step 1: Write the failing moments-service test**

Create `test/modules/moments/moments_service_test.dart` that proves:

- list mapping accepts the `MomentsApi`-style payload shape
- detail, like/unlike, delete, and publish operations are delegated through one authority path
- no production code path still depends on the old direct raw-response assumptions

- [ ] **Step 2: Run the moments-service test to confirm the duplicate ownership still exists**

Run: `flutter test test/modules/moments/moments_service_test.dart`
Expected: FAIL or require code changes because `MomentsService` still owns raw API behavior directly

- [ ] **Step 3: Refactor `MomentsService` so it becomes a thin adapter over `MomentsApi`**

Keep the public `MomentsPage` surface intact, but:

- route list/detail/publish/delete/comment/like/unlike through `MomentsApi`
- keep `MomentsService` only as the page-facing mapper and image-picking helper if needed
- remove any direct duplicate HTTP contract knowledge that `MomentsApi` already owns

- [ ] **Step 4: Seal the legacy production leaks**

Perform the following cleanup:

- `lib/modules/user/user_page_complete.dart` becomes a deprecated wrapper or is removed from any production routing/import path
- `lib/modules/settings/device_management_page.dart` remains only as a shim, not a second production route
- `lib/wukong_uikit/setting/privacy_settings_page.dart` remains only as a shim, not a production route

- [ ] **Step 5: Rerun moments and compile tests**

Run:

- `flutter test test/modules/moments/moments_service_test.dart`
- `flutter test test/modules/shell/main_pages_compile_test.dart`

Expected: PASS

- [ ] **Step 6: Final Phase-1 analyze and focused regression run**

Run:

- `flutter analyze lib/modules/user lib/modules/settings lib/modules/favorites lib/modules/moments lib/modules/chat/chat_page.dart lib/wukong_uikit/setting lib/wk_endpoint/slots/settings_slots.dart lib/service/api/collection_api.dart`
- `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart`
- `flutter test test/wukong_uikit/setting/setting_page_slot_assembly_test.dart test/modules/settings/settings_pages_compile_test.dart`
- `flutter test test/modules/favorites/favorites_page_test.dart test/service/api/collection_api_test.dart`
- `flutter test test/modules/moments/moments_service_test.dart test/modules/shell/main_pages_compile_test.dart`

Expected: all PASS

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/moments lib/modules/user/user_page_complete.dart lib/modules/settings/device_management_page.dart lib/wukong_uikit/setting/privacy_settings_page.dart test/modules/moments/moments_service_test.dart test/modules/shell/main_pages_compile_test.dart
git commit -m "refactor: converge moments and retire phase1 legacy entry paths"
```

## Phase 1 Exit Gate

This child plan is only complete when all of the following are true:

- the active `UserPage` exposes real entries for settings, notifications, favorites, moments, privacy, account security, and PC/Web login
- the active `SettingPage` can open the authoritative notification, privacy, and account-security flows
- `FavoritesPage` is no longer a stub and supports list, search, delete, refresh, empty, and error states
- `MomentsPage` is reachable from the active user center and its service no longer competes with a second API owner
- only one settings/privacy/security stack is authoritative
- `user_page_complete.dart`, `wukong_uikit/setting/privacy_settings_page.dart`, and `device_management_page.dart` are no longer production entry owners
- placeholder account-security actions are either backed by real contracts or removed from the production path

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-07-user-center-settings-convergence.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, and keep each write scope small. Per your instruction, every subagent will use `gpt-5.3-codex` with `xhigh` reasoning.

**2. Inline Execution** - Execute tasks in this session using the same task order, with checkpoints after each task.

If we continue immediately, the recommended next move is Task 1 with subagent-driven execution.
