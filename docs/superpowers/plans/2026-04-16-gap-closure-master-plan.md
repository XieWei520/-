# WuKongIM Gap Closure Master Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining verified parity gaps between `wukong_im_app` and TangSengDaoDao without redoing features that are already migrated.

**Architecture:** This is a master program plan, not a single-feature implementation plan. Work is split into audited tracks: settings/security, message/data parity, push/platform, workplace/ecosystem, and end-to-end encryption. Several items in the original report are stale, and several Flutter-side API clients do not match the currently auditable backend routes, so every execution track must freeze the contract before code changes begin.

**Tech Stack:** Flutter/Dart, Riverpod, Dio, WuKongIM Flutter SDK, Android/iOS native bridges, TangSengDaoDao Go server, Windows/Web/macOS/Linux targets

---

## Scope Constraint (2026-04-16)

- [x] Defer `Domestic Android vendor push` for Huawei/Xiaomi/OPPO/VIVO by
      explicit product decision.
- [x] Defer `Web3 auth UI` by explicit product decision.
- [x] Defer `Management backend migration strategy` by explicit product
      decision.
- [ ] Continue closing every other verified gap in this master plan.

## 0. Progress Update (2026-04-16)

- [x] Implement `Account destroy` in Flutter settings with SMS-code request,
      verification entry, and logout-on-success flow.
- [x] Replace the static customer-service entry with
      `/v1/user/customerservices` loading plus legacy fallback.
- [x] Implement the `Chat password / chatpwd` settings surfaces:
      account-security set/update flow plus personal/group `chat_pwd_on`
      toggles.
- [x] Implement `Channel message auto-delete` in conversation/group settings
      with API integration and local cache sync.
- [x] Align `Message backup / recovery` export rows with Android raw-array
      expectations and complete live production restore acceptance.
- [x] Apply `Font size` globally through the app root display-preferences
      wrapper.
- [x] Integrate server-backed `Chat background` loading and chat-surface
      rendering while keeping local fallback styles.
- [x] Add targeted API/widget regression coverage for the completed Phase 1
      closures landed so far.
- [x] Land the safe `Rich text` send-only slice through the chat more-panel and
      scene gateway while keeping edit out of scope.
- [x] Verify `Rich text` renderer/parser/send parity for the current send-only
      scope, including SDK-aligned preview text for typed/raw payloads plus a
      full `test/modules/chat` regression pass.
- [x] Replace the default `Workplace` speculative `/preferences*` path with a
      server-aligned local-device module-preference mode.
- [x] Add server-aligned Flutter `WorkplaceApi` coverage for the real
      open-source workplace user routes, including raw-list payload parsing.
- [x] Keep `AppModulesPage` as the lightweight preference shell while adding a
      user-facing `WorkplaceCatalogPage` for banner browsing, category app
      discovery, add/remove actions, and recent-app replay.
- [x] Add explicit `Workplace` added-app reorder controls in
      `WorkplaceCatalogPage`, backed by the verified
      `/v1/workplace/app/reorder` route.
- [x] Upgrade `Workplace` banner/app URL openings to embedded WebView flows,
      including URL-shaped native `app_route` values, while leaving unfrozen
      non-URL native-route dispatch in audit-first scope.
- [x] Close `Open API / OAuth UI` for the active scope by adding
      `WebViewJavascriptBridge.auth` compatibility inside the shared embedded
      WebView, loading `/v1/apps/:app_id` metadata, showing a native consent
      sheet, and returning `/v1/openapi/authcode` results through the JS
      callback.
- [x] Land a push-readiness scaffold for APNs/Android permissions:
      iOS entitlements linkage, background remote-notification mode, Android
      `POST_NOTIFICATIONS`, and explicit FCM-only fallback logging.
- [x] Add Dart-side APNs registration diagnostics for the active iOS/FCM path:
      expose the normalized registration snapshot, read `getAPNSToken()`, and
      warn when iOS has an FCM token before APNs becomes available.
- [x] Re-audit the unread-clear red-dot contract mismatch and land a safe
      Flutter fallback for the legacy `/v1/coversation/clearUnread` path.
- [x] Finish Phase 0 report/spec refresh and freeze the remaining contract-risk
      items.

## 1. Corrected Audit Snapshot

### 1.1 Remove These Items From The Remaining-Gap Backlog

These items are already present in the Flutter project and should not be scheduled as new migration work:

- `Pinned Messages`
- `MailList / 鎵嬫満閫氳褰曞鍏`
- `Account destroy / 娉ㄩ攢`
- `Customer service entry`
- `Font size`
- `Group Blacklist`
- `Group member single mute`
- `Lock screen password / 璁惧閿乣`
- `About page`
- `Error log viewer`
- `App module switch`
- `File Helper`
- `Rich text message`
- `Open API / OAuth UI`

### 1.2 Keep These Items As Partial Or Not Yet Closed

These items have code, pages, or tests, but are not yet closed at parity level:

- `Chat background`
  - Flutter now loads server `chatbg` data, persists both global and
    conversation-scoped selections, supports follow-global reset, and applies
    the resolved background on chat surfaces.
  - Status: closed for the active migration scope; any remaining asset-fidelity
    tweaks are optional polish rather than a verified parity blocker.
- `APNs`
  - Flutter iOS runtime already registers remote notifications and forwards the APNs token to Firebase Messaging.
  - Flutter now also includes Runner entitlements linkage, iOS
    `remote-notification` background mode, and Android
    `POST_NOTIFICATIONS`.
  - Flutter now also exposes a Dart-side registration snapshot for the
    active FCM path, including APNs-token availability status and a warning
    log when iOS reports an FCM token before APNs is ready.
  - Missing: Apple capability/profile closure, real-device token receipt
    confirmation, and production validation.
- `Workplace`
  - Flutter now keeps `AppModulesPage` on a server-aligned local-device
    preference mode backed by `/v1/common/appmodule` plus local persistence.
  - Flutter now also has typed API coverage for `/v1/workplace/banner`, `/app`,
    `/apps/:app_id`, `/app/reorder`, `/category`,
    `/categorys/:category_no/app`, and `/app/record`, including tolerance for
    the open-source server's raw-list responses.
  - Flutter now also exposes a user-facing `WorkplaceCatalogPage` from the
    existing App Modules entry, with banner rendering, recent-app replay,
    category browsing, add/remove actions, explicit added-app reorder controls,
    backend `cover/icon` rendering, embedded WebView opening for HTTP(S)
    banner/app routes, URL-shaped `app_route` handling when `jump_type=1`, and
    usage-record sync.
  - Status: closed for the current auditable workplace scope. The stock
    reference clients do not currently expose an authoritative active
    workplace main tab, so a dedicated home-tab is no longer treated as a
    verified parity blocker. Remaining non-URL native-route dispatch is moved
    to audit-first scope until the reference map is frozen.
- `Flutter Web support`
  - The project already has `web/` scaffolding and many `kIsWeb` branches.
  - Missing: production build validation, deployment hardening, and web-specific feature QA.
- `Flutter Desktop support`
  - The project already has `windows/`, `macos/`, and `linux/` targets, and Windows debug build is already known to pass.
  - Missing: packaging, parity QA, and platform-specific bug closure.

### 1.3 Keep These Items As Confirmed Missing

- `Domestic Android vendor push` for Huawei/Xiaomi/OPPO/VIVO
  - Deferred for now by explicit product decision; do not schedule active
    implementation work in the current closure run.
- `Web3 auth UI`
  - Deferred for now by explicit product decision; do not schedule active
    implementation work in the current closure run.
- `Management backend migration strategy`
  - Deferred for now by explicit product decision; do not schedule active
    implementation work in the current closure run.

### 1.4 Audit-First Items: Do Not Estimate Implementation Until Contract Freeze

- `End-to-end encryption / Signal`
  - Flutter has `CryptoApi` and `wukong_crypto` placeholders.
  - Re-audit result (2026-04-16): neither the open-source server nor
    `/opt/wukongim-prod/src` exposes `/v1/user/signal/getkey`,
    `/v1/user/signal/uploadkeys`, `/v1/message/encrypt/send`, or
    `/v1/message/encrypt/ack`.
  - Supporting primitives do exist: `signal_identities`,
    `signal_onetime_prekeys`, message-sync `signal_payload`, and the
    `/v1/user/grant_login?encrypt=` path.
  - Flutter runtime does not currently call `CryptoApi`; active chat
    send/receive flows bypass it.
  - Decision: quarantine the speculative Flutter crypto client and do not
    schedule runtime E2EE implementation until the backend/API contract is
    frozen.
- `Bot stream`
  - The open-source server does expose
    `/v1/robots/:robot_id/:app_key/stream/start|end`.
  - Flutter now has typed `RobotApi.startStream/endStream` coverage for those
    routes, but no runtime/UI consumer has been wired yet.
  - Re-audit result (2026-04-16): Android/iOS/Web reference client sources do
    not expose a direct runtime consumer for these start/end routes; only the
    lower-level message `streamNo` model is present in the SDK/message layer.
  - Re-scope as a backend/robot-integration concern unless product explicitly
    decides to surface a streaming bot UX in Flutter.
- `Red Dot`
  - Existing reminder and red-dot behavior already exists in Flutter.
  - A real route mismatch was confirmed on unread clear:
    `/v1/conversation/clearUnread` vs `/v1/coversation/clearUnread`.
  - Flutter now includes a 404-only fallback to the legacy typo path.
  - Re-audit result (2026-04-16): the open-source server still registers only
    the typo route, and the Android/iOS reference clients still call that typo
    path directly, so no additional Flutter-side parity work remains beyond
    the current fallback.
  - Remaining contract cleanup is backend-side canonical route unification.
- `Workplace preferences endpoints`
  - The auditable open-source server exposes `/v1/workplace/banner`, `/app`,
    `/apps/:app_id`, `/app/reorder`, `/category`,
    `/categorys/:category_no/app`, and `/app/record`, not
    `/v1/workplace/preferences*`.
  - Flutter no longer defaults to the speculative `/v1/workplace/preferences*`
    path in the open-source build.
  - Flutter now has additive typed route coverage for the real server
    endpoints, but the legacy preference snapshot contract remains
    non-authoritative.
  - Do not build new workplace UI on top of the speculative preference
    snapshot contract.
- `Workplace native route mapping`
  - The auditable server schema distinguishes `jump_type=1` native entries
    with `app_route`, but the Android/iOS/Web reference clients do not expose
    a frozen cross-client native route map.
  - Flutter now treats URL-shaped `app_route` values as embedded web content.
  - Do not implement non-URL native-route dispatch until the reference map is
    frozen.

---

## 2. Recommended Execution Order

### Phase 0: Freeze Reality Before Writing More Code

- [ ] Update the migration truth table from source audit, not from the original report alone.
- [ ] Freeze backend contracts for:
  - `chatbg`
  - `user/destroy`
  - `user/chatpwd`
  - `user/customerservices`
  - `channels/:channel_id/:channel_type/message/autodelete`
  - workplace routes
  - crypto routes
  - robot stream requirements
- [ ] Record one acceptance target per item:
  - API path
  - request body
  - response shape
  - target Flutter page or runtime
  - required regression tests
- [ ] Re-run build smoke checks for:
  - Android
  - iOS shell
  - Windows
  - Web
  - Note: current evidence already includes successful `flutter build web
    --debug`, successful `flutter build windows --debug`, `flutter doctor -v`
    confirmation of a valid Android toolchain, an Android APK build timeout on
    this host without an emitted artifact, and no available `flutter build ios`
    subcommand from this Windows Flutter installation.

**Exit criteria**

- One corrected backlog document exists.
- Every remaining item is in exactly one bucket: `confirmed missing`, `partial`, or `audit-first`.
- No execution task depends on an unverified route name.

### Phase 1: Close The Fast, High-Value Product Gaps

- [x] Implement `Account destroy` with confirmation and verification flow.
- [x] Implement `Chat password` settings UI:
  - account-security set/update flow
  - personal `chat_pwd_on` toggle
  - group `chat_pwd_on` toggle
- [x] Close runtime `Chat password` parity:
  - conversation-preview masking
  - chat-open password gating
  - wrong-attempt countdown and exhausted-state local clear
  - same-session chat-password hash refresh after settings update
- [x] Implement `Channel message auto-delete` in conversation/group settings.
  - Closed on 2026-04-16: deployed/open-source backend semantics were re-audited
    (`msg_auto_delete` persistence plus per-message `expire`/`expire_at`
    propagation), and the Flutter SDK now performs scheduled
    `expire_timestamp` cleanup with regression coverage.
- [x] Replace the static customer-service entry with `/user/customerservices` data loading while preserving the current entry point.
- [x] Align `Message backup / recovery` archive shape with Android/server expectations and verify cross-device restore.
  - Completed on 2026-04-16: live production acceptance passed with a
    disposable authenticated account, and the backend now auto-normalizes
    legacy bare object keys during save/load.

**Why first**

- These items are user-visible.
- They depend on already known server routes.
- They materially improve parity without waiting on the crypto track.

### Phase 2: Finish The Existing Partial Settings Features

- [x] Continue `Chat background` parity from the new server-backed list loading
      and real chat-surface rendering baseline, including conversation-scoped
      overrides and follow-global reset.
- [x] Apply `Font size` globally, not only inside the settings preview page.
- [x] Wire the `Rich text` send-only path through the chat more-panel and scene
      gateway.
- [x] Verify `Rich text` renderer/parser/send parity end-to-end for the current
      send-only scope and keep edit out of scope until the text-only contract
      changes.

**Why second**

- The pages already exist, so these are closure tasks rather than greenfield features.
- They improve the daily UX immediately.

### Phase 3: Repair The Workplace Track With The Correct Server Contract

- [x] Replace the default Flutter `workplace/preferences*` client assumption
      with a server-aligned local-device module-preference mode.
- [x] Land typed Flutter API coverage for workplace banner/category/app/record
      routes that are actually present.
- [x] Implement workplace banner loading in user-facing UI.
- [x] Implement workplace category browsing in user-facing UI.
- [x] Implement add/remove/reorder flows against server routes that are
      actually present in user-facing UI.
- [x] Implement usage-record sync and replay in user-facing UI/runtime.
- [x] Implement embedded WebView opening for auditable URL-based workplace
      routes, including URL-shaped native `app_route` values.
- [x] Decide whether `AppModulesPage` remains a lightweight local/prefs surface or becomes a subset of the full workplace feature set.
  - Decision: keep `AppModulesPage` as the preference shell and open a
    dedicated `WorkplaceCatalogPage` for the broader workplace experience.

**Why separate**

- The current Flutter workplace client contract does not line up cleanly with the auditable open-source server.
- This track needs a dedicated design pass before code expansion.

### Phase 4: Push And Platform Closure

- [ ] Finish APNs release closure:
  - entitlements
  - Apple capabilities
  - real-device Firebase/APNs token verification
  - real-device notification receipt
- [ ] Implement native Android push handlers for:
  - Huawei
  - Xiaomi
  - OPPO
  - VIVO
- [ ] Run a platform matrix for:
  - Android
  - iOS
  - Windows
  - Web
  - macOS
  - Linux
- [ ] Fix the desktop/web issues discovered in the matrix.

**Why not first**

- The app already works on the core mobile path.
- Vendor push and cross-platform packaging are important, but they do not unblock the main feature parity path.

### Phase 5: Contract-Risk Tracks

- [x] Re-audit the crypto backend contract end-to-end.
  - Result: neither the open-source server nor `/opt/wukongim-prod/src`
    exposes the speculative Flutter `CryptoApi` routes; only Signal-related
    storage/payload primitives were confirmed.
- [x] Decide whether the target is:
  - full Signal parity
  - partial secure-session parity
  - deferred removal of speculative Flutter crypto client code
  - Decision (2026-04-16): keep E2EE blocked behind contract freeze and
    quarantine the speculative Flutter crypto client/runtime until a real
    backend contract is restored or frozen.
- [x] Re-audit robot streaming product requirements and backend capability.
  - Result: backend capability is real, but no authoritative Android/iOS/Web
    client runtime consumer was found for `/stream/start|end`; keep it out of
    the active Flutter parity backlog until product scope changes.
- [x] Re-audit red-dot behavior and only schedule code changes if a real parity gap remains.
  - Result: no additional Flutter-side parity gap remains after confirming the
    open-source server and Android/iOS reference clients still use the legacy
    typo route; keep backend canonical-route unification as a separate
    contract-cleanup item.

**Why late**

- These tracks carry the highest uncertainty.
- Shipping smaller confirmed gaps first reduces overall risk and gives a cleaner base for large work.

### Phase 6: Long-Pole Programs

- [ ] Implement E2EE runtime only after contract freeze:
  - key generation and upload
  - session establishment
  - local key persistence
  - send encryption
  - receive decrypt
  - failure states and fallback UI
- [ ] Decide the long-term approach for `Web3 auth` and `Bot stream`.
- [ ] Treat `Management backend` as a separate project:
  - recommended default: reuse or re-theme `TangSengDaoDaoManager-main`
  - avoid forcing this track into `wukong_im_app`

---

## 3. Track Breakdown

### Track A: Settings And Security Closure

**Primary Flutter files**

- `lib/modules/settings/privacy_settings_page.dart`
- `lib/modules/settings/account_security_page.dart`
- `lib/wukong_uikit/setting/setting_page.dart`
- `lib/wukong_uikit/setting/chat_background_settings_page.dart`
- `lib/wukong_uikit/setting/font_size_settings_page.dart`
- `lib/wukong_uikit/setting/setting_preferences.dart`
- `lib/service/api/user_api.dart`
- `lib/service/api/collection_api.dart`

**Child plans required**

- account destroy
- chat password
- chat background closure
- font size global application
- customer service API-backed entry

### Track B: Message And Data Parity

**Primary Flutter files**

- `lib/modules/settings/message_backup/backup_restore_message_page.dart`
- `lib/modules/settings/message_backup/backup_restore_message_service.dart`
- `lib/widgets/message_bubble.dart`
- `lib/modules/chat/message_content_preview.dart`
- `lib/wukong_base/msg/message_content_parser.dart`
- `lib/modules/chat/chat_composer_controller.dart`
- `lib/modules/chat/chat_page_shell.dart`

**Child plans required**

- backup/recovery parity closure
- rich text send-path closure

### Track C: Workplace And Ecosystem

**Primary Flutter files**

- `lib/service/api/workplace_api.dart`
- `lib/modules/workplace/workplace_catalog_models.dart`
- `lib/modules/workplace/workplace_catalog_page.dart`
- `lib/modules/workplace/workplace_catalog_service.dart`
- `lib/modules/workplace/workplace_preferences_models.dart`
- `lib/modules/workplace/workplace_preferences_service.dart`
- `lib/wukong_uikit/setting/app_modules_page.dart`
- `lib/service/api/robot_api.dart`

**Primary server reference**

- `TangSengDaoDaoServer-main/modules/workplace/api.go`
- `TangSengDaoDaoServer-main/modules/workplace/swagger/api.yaml`
- `TangSengDaoDaoServer-main/modules/robot/swagger/api.yaml`

**Child plans required**

- workplace server-contract realignment
- workplace UI completion
- robot-stream product/contract audit

### Track D: Push And Platform

**Primary Flutter files**

- `lib/wukong_push/push_service.dart`
- `lib/wukong_push/handlers/push_handler.dart`
- `lib/wukong_push/handlers/fcm_handler.dart`
- `ios/Runner/AppDelegate.swift`
- `web/index.html`
- `windows/`
- `macos/`
- `linux/`

**Child plans required**

- APNs release closure
- Android vendor push adapters
- platform build and packaging matrix

### Track E: E2EE / Signal

**Primary Flutter files**

- `lib/service/api/crypto_api.dart`
- `lib/wukong_crypto/crypto_exports.dart`
- `lib/wukong_crypto/models/signal_data.dart`
- chat send/receive pipeline files to be identified after contract freeze

**Constraint**

- Do not implement this track until the real backend contract is frozen.

---

## 4. Validation Matrix

Every child plan derived from this master plan must include:

- route-contract verification against source or production backend
- widget tests for new pages and flows
- service/API tests for payload and response handling
- parity tests when replacing an existing Android-equivalent screen
- at least one end-to-end smoke scenario for the new feature path

### Mandatory regression clusters

- `message backup / recovery`
- `group moderation`
- `settings shell / navigation`
- `push registration`
- `chat message rendering`
- `web / desktop build smoke`

---

## 5. Suggested Child Plan Creation Order

- [ ] Child plan 1: `account-destroy-chatpwd-autodelete`
- [ ] Child plan 2: `message-backup-parity`
- [ ] Child plan 3: `chat-background-font-size-richtext`
- [ ] Child plan 4: `customer-service-entry`
- [ ] Child plan 5: `workplace-contract-alignment`
- [ ] Child plan 6: `push-platform-closure`
- [ ] Child plan 7: `crypto-contract-audit`
- [ ] Child plan 8: `e2ee-runtime`

---

## 6. Final Prioritization

### Do Next

- APNs release closure and platform matrix validation
- contract-freeze preparation for the remaining audit-first tracks

### Keep In Partial Closure

### Keep As Separate Programs

- E2EE / Signal
- bot stream
- management backend
- Web3 auth

---

## 7. Decision Notes

- Do not spend more time rebuilding features that are already in Flutter just because the original report marked them missing.
- Do not treat `AppModulesPage` as proof that the full workplace track is done.
- Do not treat the existence of `CryptoApi` as proof that end-to-end encryption is close to done.
- Do not treat Web/Desktop scaffolding as proof of parity closure.
- Do not fold the management backend into the Flutter client unless there is an explicit product decision to do so.
