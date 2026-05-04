# Android Reference Parity Master Blueprint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter Android client from the current source-audited `~60%` overall parity level to `100%` Android-reference parity against TangSengDaoDao Android, while collapsing duplicate Flutter implementations into one authoritative production mainline.

**Architecture:** This is a program-level master blueprint, not a one-shot coding batch. Execution must be split into child plans per subsystem, always converging onto the active mainline under `lib/app`, `lib/modules`, `lib/service`, `lib/wk_endpoint`, and `lib/wukong_uikit`, while retiring duplicate or stale paths under legacy branches. Reuse strong existing Flutter implementations, but do not keep parallel feature owners alive after each phase lands.

**Tech Stack:** Flutter, flutter_riverpod, go_router, Dio, WKIM SDK, sqflite, mobile_scanner, firebase_messaging, flutter_local_notifications, flutter_webrtc, LiveKit, flutter_test, integration_test, PowerShell, Android vendor push SDKs, TangSengDaoDao Android reference codebase

---

## Program Scope

This master blueprint covers the remaining migration gap between:

- Flutter target: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app`
- Android reference: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master`

This blueprint is intentionally split into multiple execution streams. Do not implement everything in a single branch or a single uninterrupted coding pass.

## Current Source-Audited Baseline

These numbers come from source comparison, not from README claims or older gap notes.

- `User-visible mainline parity:` about `60%` to `65%`
- `Feature coverage parity:` about `65%` to `70%`
- `Engineering/platform parity:` about `50%` to `55%`
- `Recommended single headline number:` `60%`

## Program Status Update (2026-04-08)

- The baseline percentages above remain the program-level truth model, not a claim that every phase is untouched.
- `Phase 3: Finish Group Advanced Parity` is now materially further along than this master blueprint's initial draft state:
  - the code path for advanced group settings, invite-mode member handling, member-scoped search handoff, and native scan-to-join flow is implemented and passing focused regression coverage
  - fresh `flutter analyze` and focused Phase 3 test sweeps passed on `2026-04-08`
  - real deployed-backend evidence exists for truthful group-detail toggles and the normal-member invite-only add flow
- Phase 3 runtime evidence update:
  - the previously open active-member group-scan runtime evidence gap was closed on `2026-04-08`
  - see `docs/superpowers/artifacts/2026-04-08-scan-active-runtime-evidence.md` for the direct runtime capture sequence into `ChatPage`

## Hard Truths To Preserve During Execution

- The Flutter app is already beyond the "demo port" stage. Do not restart from scratch.
- The largest risk is not missing pages. The largest risk is duplicate ownership of the same feature.
- Old and new paths coexist in multiple areas:
  - `lib/modules/settings/**` vs `lib/wukong_uikit/setting/**`
  - `lib/service/api/login_bridge_api.dart` vs `lib/wukong_login/pc_login_service.dart`
  - `lib/net/ws_manager.dart` vs `lib/wukong_base/net/ws_manager.dart`
  - `lib/modules/**` vs older `*_complete.dart` pages
- A feature is not complete merely because a page exists or an API wrapper exists.
- A feature is only complete when:
  - mainline entry is visible
  - behavior is wired
  - backend contract is real
  - state survives real navigation/runtime conditions
  - duplicate branches are retired or isolated

## Existing Plans And How To Use Them

The repository already contains execution plans that should be reused instead of discarded.

### Reuse Directly

- `docs/superpowers/plans/2026-04-03-architecture-mainline-realignment.md`
- `docs/superpowers/plans/2026-04-04-phase-3-auth-device-login-alignment.md`
- `docs/superpowers/plans/2026-04-04-phase-4-chat-mainline-rearchitecture.md`
- `docs/superpowers/plans/2026-04-04-phase-5a-chat-action-surface-parity.md`
- `docs/superpowers/plans/2026-04-04-phase-5b-chat-engagement-parity.md`
- `docs/superpowers/plans/2026-04-03-search-parity-rebuild.md`
- `docs/superpowers/plans/2026-04-05-phase-6a-date-search-locate-foundation.md`
- `docs/superpowers/plans/2026-04-05-phase-6b-chat-scoped-search-mainline-convergence.md`
- `docs/superpowers/plans/2026-04-05-phase-6c-global-search-convergence-final-regression.md`

### Reuse Partially, Then Extend

- `docs/superpowers/plans/2026-04-03-endpoint-uikit-rebuild.md`
  - Extend it with current user-center, settings, and contacts entry convergence.
- `docs/superpowers/plans/2026-04-05-contacts-strings-resource-layer.md`
  - Keep resource alignment work, but layer contacts parity and saved-groups behavior on top.

### Replace Or Supersede With New Child Plans

- Any old plan or analysis that claims the app is only `24%` complete should be treated as obsolete.
- Any plan that assumes README checklist status equals real source status should be replaced.

## Phase Ordering

The correct order is:

1. `Authoritative mainline convergence`
2. `User-visible parity blockers`
3. `Chat and group advanced closure`
4. `Cross-device / PC-Web / RTC parity`
5. `Platform capabilities and security`
6. `Architecture cleanup and regression gate`

## Phase 0: Freeze The Truth Model

**Purpose:** Prevent future rework caused by conflicting definitions of "done".

**Files:**
- Modify: `docs/migration_truth_matrix.md`
- Modify: `docs/MIGRATION_SUMMARY.md`
- Reference: `docs/superpowers/specs/2026-04-03-complete-feature-alignment-design.md`
- Reference: this file

- [ ] Create a single feature ledger with one row per Android feature family:
  - auth
  - conversation list
  - contacts
  - chat actions
  - favorites
  - moments
  - scan
  - groups
  - push
  - calls
  - privacy/security
  - backup/restore
  - sensitive/prohibit words
- [ ] For each row, mark only one of:
  - `aligned`
  - `partial`
  - `implemented but not wired`
  - `missing`
- [ ] Add a "Flutter authority path" column so every feature has one owner path.
- [ ] Add a "legacy path to retire" column for duplicate implementations.
- [ ] Refuse to mark any feature as complete until mainline entry, runtime behavior, and backend contract are all validated.

**Exit Gate:**

- The team can point to one truth matrix and one authority path per feature.

## Phase 1: Converge User Center, Settings, Favorites, And Moments

**Why first:** The source audit shows these areas are already partially implemented, but entry wiring and duplication are blocking visible parity.

**Target Result:** The current user center becomes the one real home for:

- settings
- notification settings
- privacy settings
- blacklist
- account security
- PC/Web login management
- favorites center
- moments entry

**Primary Files:**
- `lib/modules/user/user_page.dart`
- `lib/modules/user/user_slot_assembly.dart`
- `lib/modules/settings/privacy_settings_page.dart`
- `lib/wukong_uikit/setting/setting_page.dart`
- `lib/wukong_uikit/setting/setting_slot_assembly.dart`
- `lib/modules/chat/chat_page.dart`
- `lib/modules/moments/moments_page.dart`
- `lib/modules/chat/chat_scene_gateway.dart`
- `lib/service/api/collection_api.dart`
- legacy references to retire:
  - `lib/wukong_uikit/setting/privacy_settings_page.dart`
  - `lib/modules/user/user_page_complete.dart`

- [ ] Make a child plan named `2026-04-07-user-center-settings-convergence.md`.
- [ ] Choose one production owner for privacy, notification, blacklist, device, and account-security pages.
- [ ] Rewire `user_page.dart` so the current user center can reach all production settings flows without hidden or old pages.
- [ ] Replace the stub `FavoritesPage` with a real collection center built on `CollectionApi`.
- [ ] Add a mainline moments entry from the active user center.
- [ ] Remove or isolate any old `*_complete.dart` route that still exposes outdated behavior.
- [ ] Verify that every visible user-center tile opens a real production page.

**Verification Commands:**

```powershell
flutter analyze lib/modules/user lib/modules/settings lib/wukong_uikit/setting lib/modules/chat lib/modules/moments
flutter test
```

**Exit Gate:**

- No user-center entry opens a stub page.
- Favorites and moments are reachable from the active mainline.
- Only one settings/privacy stack is authoritative.

## Phase 2: Close Conversation List And Chat Mainline Parity

**Why second:** This is the largest user-facing gap after settings convergence.

**Target Result:** Flutter chat mainline reaches Android parity for:

- conversation pin
- complete long-press actions
- reliable forward
- reliable favorite
- reply flow
- message record search entry
- chat-scoped search consistency

**Primary Files:**
- `lib/modules/conversation/conversation_list_page.dart`
- `lib/modules/chat/chat_page_shell.dart`
- `lib/modules/chat/chat_message_action_controller.dart`
- `lib/modules/chat/chat_scene_gateway.dart`
- `lib/modules/chat/message_forwarding.dart`
- `lib/modules/search/presentation/chat_search_entry_page.dart`
- `lib/modules/search/presentation/chat_search_date_page.dart`
- `lib/modules/search/presentation/chat_search_member_page.dart`
- `lib/modules/search/presentation/chat_search_collection_page.dart`
- `lib/wukong_uikit/chat/input_function_menu.dart`
- Android references:
  - `wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java`
  - `wkuikit/src/main/java/com/chat/uikit/chat/search/MessageRecordActivity.kt`

- [ ] Make a child plan named `2026-04-07-conversation-chat-closure.md`.
- [ ] Implement real conversation pin behavior in `conversation_list_page.dart`.
- [ ] Audit every chat long-press action and classify it as:
  - done
  - partial
  - hidden
  - missing
- [ ] Build the missing production actions in the active chat page instead of old shell pages.
- [ ] Add a real message-record search surface matching Android behavior.
- [ ] Ensure favorites and forwards operate from the active chat mainline, not only from partial helper pages.
- [ ] Retire or isolate unused placeholder chat implementations once replacements are verified.

**Verification Commands:**

```powershell
flutter analyze lib/modules/conversation lib/modules/chat lib/modules/search
flutter test
```

**Exit Gate:**

- Conversation pin is real.
- Chat actions are wired from the active mainline.
- Message-record search has a production entry.

## Phase 3: Finish Group Advanced Parity

**Why third:** Group detail is already strong, so this is a leverage phase rather than a from-scratch phase.

**Target Result:** Group parity becomes fully credible, including:

- member add/remove
- manager promote/demote
- owner transfer
- notices
- QR
- group-wide search/records
- invite acceptance flow
- permission toggles

**Primary Files:**
- `lib/wukong_uikit/group/group_detail_page.dart`
- `lib/service/api/group_api.dart`
- `lib/wukong_uikit/group/saved_groups_page.dart`
- `lib/wukong_uikit/group/all_members_page.dart`
- Android references:
  - `wkuikit/src/main/java/com/chat/uikit/group/GroupDetailActivity.java`
  - `wkuikit/src/main/java/com/chat/uikit/group/WKAllMembersActivity.java`

- [ ] Make a child plan named `2026-04-07-group-advanced-parity.md`.
- [ ] Audit every Android group-detail section against the active Flutter group-detail page.
- [ ] Fill any remaining permission gaps around invite/edit/manage authority.
- [ ] Add or align message-record/search entry points from group detail and all-members flows.
- [ ] Verify all group actions mutate state through real APIs and refresh correctly.
- [ ] Remove hidden fallback actions or dead-end group detail branches.

**Verification Commands:**

```powershell
flutter analyze lib/wukong_uikit/group lib/service/api/group_api.dart
flutter test
```

**Exit Gate:**

- Group-detail parity is product-complete, not just API-complete.

## Phase 4: Unify Auth, Device Sessions, Scan, And PC-Web Login

**Why fourth:** The source audit shows this area is split between newer bridge APIs and older placeholders.

**Target Result:** Auth/session parity is owned by one real chain:

- login/register/reset
- device sessions
- scan-based login confirm
- PC/Web session list and removal
- no stale placeholder owner paths

**Primary Files:**
- `lib/service/api/login_bridge_api.dart`
- `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
- `lib/modules/auth/data/auth_repository_impl.dart`
- `lib/wukong_login/pc_login_service.dart`
- `lib/wukong_scan/scan_page.dart`
- `lib/wukong_scan/scan_service.dart`
- `lib/wukong_scan/scan_result_page.dart`
- Android references:
  - `wklogin/src/main/java/com/chat/login/ui/WKLoginActivity.java`
  - `wkscan/src/main/java/com/chat/scan/WKScanActivity.java`

- [ ] Reuse and update `2026-04-04-phase-3-auth-device-login-alignment.md`.
- [ ] Decide whether `pc_login_service.dart` is:
  - deleted
  - bridged
  - kept only as a compatibility wrapper
- [ ] Make `login_bridge_api.dart` the real owner for device and PC/Web session operations if backend coverage is sufficient.
- [ ] Align scan result behavior with Android for user, group, login-confirm, and external URL cases.
- [ ] Ensure user-center PC/Web entry and scan-confirm flow point to the same production backend chain.

**Verification Commands:**

```powershell
flutter analyze lib/modules/auth lib/wukong_login lib/wukong_scan lib/service/api/login_bridge_api.dart
flutter test
```

**Exit Gate:**

- There is one production owner for PC/Web login.
- Scan-confirm and device-session management are consistent.

## Phase 5: Close Multi-Party Call Parity

**Why now:** Flutter already has substantial 1v1 call groundwork, but Android supports group call member selection and richer RTC entry patterns.

**Target Result:** Call parity includes:

- 1v1 audio/video
- group multi-person entry
- call member selection
- room/session bootstrap parity
- history and pending recovery continuity

**Primary Files:**
- `lib/modules/video_call/call_coordinator.dart`
- `lib/modules/video_call/video_call_service.dart`
- `lib/modules/video_call/video_call_page.dart`
- `lib/modules/video_call/infrastructure/call_bootstrap_api.dart`
- Android references:
  - `wkuikit/src/main/java/com/chat/uikit/group/ChooseVideoCallMembersActivity.java`
  - `wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java`

- [ ] Make a child plan named `2026-04-07-call-parity-phase.md`.
- [ ] Expand bootstrap APIs beyond single `callee_uid` flow when backend supports multi-party rooms.
- [ ] Create a production member-selection surface matching Android group-call entry.
- [ ] Keep existing 1v1 stability while layering group call support.
- [ ] Verify call history remains correct for both 1v1 and future group rooms.

**Verification Commands:**

```powershell
flutter analyze lib/modules/video_call
flutter test
```

**Exit Gate:**

- Flutter supports Android-reference call entry patterns, not just isolated 1v1 calls.

## Phase 6: Finish Push, Security, Backup/Restore, And Sensitive-Word Parity

**Why now:** These are the clearest platform and lifecycle gaps.

**Target Result:** Flutter closes the most serious engineering-parity deficits:

- Huawei/Xiaomi/OPPO/VIVO push parity on Android
- notification badge/update parity
- anti-screenshot / secure-mode behavior
- backup/restore UI and service flow
- sensitive-word and prohibit-word sync/application

**Primary Files:**
- `lib/wukong_push/push_service.dart`
- `lib/wukong_push/handlers/fcm_handler.dart`
- new vendor handlers to add under `lib/wukong_push/handlers/`
- `lib/modules/settings/privacy_settings_page.dart`
- `lib/wukong_base/db/db_helper.dart`
- Android references:
  - `wkpush/src/main/java/com/chat/push/WKPushApplication.java`
  - `wkbase/src/main/java/com/chat/base/base/WKBaseActivity.java`
  - `wkuikit/src/main/java/com/chat/uikit/message/BackupRestoreMessageActivity.kt`
  - `wkuikit/src/main/java/com/chat/uikit/message/ProhibitWordModel.kt`
  - `wkuikit/src/main/java/com/chat/uikit/message/MsgModel.java`

- [ ] Make a child plan named `2026-04-07-platform-security-parity.md`.
- [ ] Add vendor-specific push handlers and runtime selection on Android.
- [ ] Mirror Android device-token registration semantics, including vendor type reporting.
- [ ] Add secure-screen support for pages and flows that Android protects with `FLAG_SECURE`.
- [ ] Create a real backup/restore flow instead of only low-level DB utilities.
- [ ] Add sensitive-word/prohibit-word sync and local runtime enforcement parity.

**Verification Commands:**

```powershell
flutter analyze lib/wukong_push lib/modules/settings lib/wukong_base
flutter test
```

**Exit Gate:**

- Push is not FCM-only anymore.
- Security and backup features have real production surfaces.

## Phase 7: Retire Duplicate Paths And Set The Final Gate

**Why last:** Cleanup must follow successful convergence, not precede it.

**Target Result:** One mainline, minimal ambiguity, credible 100% parity claim.

**Primary Files/Areas:**
- duplicate or legacy owners discovered during prior phases
- likely candidates:
  - `lib/wukong_login/pc_login_service.dart`
  - `lib/wukong_uikit/setting/privacy_settings_page.dart`
  - `lib/net/ws_manager.dart`
  - `lib/wukong_base/net/ws_manager.dart`
  - any obsolete `*_complete.dart`

- [ ] Make a child plan named `2026-04-07-legacy-retirement-and-final-gate.md`.
- [ ] Mark every duplicate file as one of:
  - keep as authority
  - keep as wrapper
  - delete
  - isolate from production routing
- [ ] Remove dead routes and dead imports.
- [ ] Update docs so the active architecture matches the actual runtime.
- [ ] Run a parity regression pass across all major user journeys.

**Verification Commands:**

```powershell
flutter analyze
flutter test
```

**Final Exit Gate:**

- Every Android-reference core feature has one Flutter authority path.
- No mainline entry opens a stub or placeholder.
- No major parity claim depends on hidden old pages.
- Push, calls, security, backup, and scan all work through production paths.

## Definition Of 100% Done

You may only claim `100% Android parity` when all of the following are true:

- `Functional parity:` every core Android user flow exists and completes
- `Entry parity:` the active Flutter app exposes the flow from current production routes
- `Behavior parity:` menus, sequence, and outcomes match Android closely enough that a user does not notice missing capability
- `Platform parity:` push, security, backup/restore, and session/device behavior are real
- `Ownership parity:` duplicate Flutter implementations no longer compete for the same job

## Recommended Child Plans To Create Next

Create these in order:

1. `docs/superpowers/plans/2026-04-07-user-center-settings-convergence.md`
2. `docs/superpowers/plans/2026-04-07-conversation-chat-closure.md`
3. `docs/superpowers/plans/2026-04-07-group-advanced-parity.md`
4. `docs/superpowers/plans/2026-04-07-call-parity-phase.md`
5. `docs/superpowers/plans/2026-04-07-platform-security-parity.md`
6. `docs/superpowers/plans/2026-04-07-legacy-retirement-and-final-gate.md`

## Self-Review

### Spec Coverage

Covered:

- mainline convergence
- user center and settings convergence
- favorites and moments closure
- conversation/chat parity
- group parity
- auth/scan/device/PC-Web convergence
- call parity
- push/security/backup/sensitive-word parity
- legacy retirement and final acceptance

Known intentional choice:

- This file is a master blueprint, so implementation must still be split into child plans. That split is required, not optional.

### Placeholder Scan

No feature is marked complete without an exit gate.
No percentage is presented as exact science.
No child plan is implied to be already implemented.

### Type Consistency

All file references use current source-audited paths in the Flutter and Android workspaces.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-07-android-reference-parity-master-blueprint.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per child plan, review between tasks, fast iteration

**2. Inline Execution** - Execute child plans in this session using executing-plans, batch execution with checkpoints

**Which approach?**
