# WuKongIM Gap Closure Design

**Date:** 2026-04-16

**Goal:** Convert the migration report from a static comparison document into an
authoritative execution baseline, then close the remaining verified parity gaps
in the Flutter app without re-implementing features that already exist.

## Design Summary

The remaining work is no longer a blind "missing-feature" sweep. The re-audit
showed that the original report mixes true gaps, stale gaps, partial closures,
and speculative contract assumptions. The design therefore splits work into two
layers:

1. `Truth maintenance`
   - Correct the backlog so every remaining item is in exactly one bucket:
     `partial`, `confirmed missing`, or `audit-first`.
   - Freeze real backend contracts from source and production evidence instead
     of trusting stale swagger/report rows.
2. `Execution closure`
   - Ship deterministic, user-visible gaps first.
   - Defer uncertain tracks until their contracts are frozen.

## Authoritative Buckets

### Already Migrated

- `Pinned Messages`
- `MailList / 鎵嬫満閫氳褰曞鍏`
- `Account destroy`
- `Customer service entry`
- `Font size`
- `Group Blacklist`
- `Group member single mute`
- `Lock screen password / 璁惧閿乣`
- `About page`
- `Error log viewer`
- `App module switch`
- `File Helper`

### Partial But Not Closed

- `Message backup / recovery`
- `Chat password / chatpwd`
- `Channel message auto-delete / message/autodelete`
- `Chat background`
- `Rich text`
- `APNs`
- `Workplace`
- `Flutter Web support`
- `Flutter Desktop support`

### Confirmed Missing

- `Domestic Android vendor push`
- `Web3 auth UI`
- `Management backend migration strategy`

### Audit-First

- `Signal / E2EE`
- `Bot stream`
- `Red Dot`
- `Workplace preferences endpoint contract`

## Verified Backend Contracts

### Frozen Now

- `GET /v1/common/chatbg`
  - Response shape verified from server source and integrated into Flutter
    settings/runtime background rendering.
- `GET /v1/user/customerservices`
  - Response shape verified from server source: array of `{ uid, name }`.
- `POST /v1/user/chatpwd`
  - Request shape verified from server source: `{ chat_pwd, login_pwd }`.
- `POST /v1/user/sms/destroy`
  - Important correction: implementation route is `POST`, not the older
    swagger-described `GET`.
- `DELETE /v1/user/destroy/{code}`
- `PUT/GET /v1/extra/user/*` settings/device routes already used by Flutter.

### Still Unfrozen

- speculative Flutter crypto routes such as `/v1/user/signal/getkey`
- robot-stream product scope on the Flutter side, even though the open-source
  server does expose `/v1/robots/:robot_id/:app_key/stream/start|end` and
  Flutter now has typed `RobotApi.startStream/endStream` methods for those
  routes
- the full workplace banner/category/app-market UI contract beyond the new
  local-device module-preference baseline and typed route coverage

## Implementation Strategy

### Phase 0: Freeze Reality

- Correct the migration report with an explicit re-audit correction block.
- Preserve the master execution plan as the task authority.
- Add a written design snapshot so later phases inherit the same bucket model.

### Phase 1: Deterministic Product Gaps

- `Account destroy`
  - Place entry in `AccountSecurityPage`.
  - Use SMS send + code confirm + logout-on-success.
- `Customer service entry`
  - Keep the current contact-header entry point.
  - Resolve the first service account from `/v1/user/customerservices`.
  - Fall back to the legacy fixed customer-service channel if the API cannot
    resolve a service account.
- `Chat password`
  - Add API-backed settings entry first.
  - Delay full conversation gating until Android parity points are frozen.
- `Channel auto-delete`
  - Place in conversation/group settings where the Android surface already
    teaches users to expect per-channel controls.
- `Message backup parity`
  - Align exported payload shape with Android/server expectations before adding
    more UX on top.

### Phase 2: Finish Existing Partial Settings Features

- continue chat background parity from the new server-backed/runtime-rendered
  baseline
- verify the new rich-text send-only path end-to-end and keep edit out of scope
  until the text-only contract changes

### Phase 3: Workplace Realignment

Keep `AppModulesPage` on a server-aligned local-device preference mode first,
then expand workplace against auditable server routes instead of speculative
preference endpoints. The Flutter API layer should accept both wrapped payloads
and the open-source server's raw JSON array responses. The preferred user-facing
closure slice keeps `AppModulesPage` as the preference shell and opens a
dedicated `WorkplaceCatalogPage` for banner/category/app browsing.

### Phase 4: Push And Platform

Land the non-secret push-readiness scaffold first, then finish APNs release
closure, vendor Android push, and a real platform matrix.

### Phase 5-6: High-Risk Or Long-Pole Programs

Do not implement crypto/runtime E2EE or bot-stream UI until contract freeze is
complete.

## Current 2026-04-16 Progress Snapshot

- `Account destroy` implemented in Flutter and covered by targeted widget/API
  tests.
- `Customer service entry` upgraded from static-only to API-backed discovery and
  covered by targeted widget/API tests.
- `Chat password` settings surfaces and `Channel message auto-delete` settings
  surfaces are implemented, but both remain parity-partial until runtime
  behavior is re-audited.
- `Message backup / recovery` export shape now matches Android-style raw rows;
  live end-to-end restore acceptance is still pending.
- `Chat background` now loads `/v1/common/chatbg`, persists server selections,
  and renders the chosen background on chat surfaces.
- `Font size` is now globally applied through the app root display-preferences
  wrapper.
- `Rich text` send-only closure is now implemented through the chat more-panel;
  end-to-end verification remains open and edit stays out of scope for now.
- `Workplace` now defaults to a server-aligned local-device module-preference
  mode using `/v1/common/appmodule` plus on-device persistence, while the full
  banner/category/app-market route expansion remains Phase 3 work.
- `WorkplaceApi` now includes typed coverage for the real open-source workplace
  user routes (`/banner`, `/app`, `/category`, `/categorys/:category_no/app`,
  `/app/reorder`, `/app/record`) and tolerates both wrapped and raw-list
  payload shapes.
- `Workplace` now also has a user-facing `WorkplaceCatalogPage` reachable from
  `AppModulesPage`, with banner rendering, recent-app replay, category
  browsing, add/remove actions, explicit added-app reorder controls, backend
  `cover/icon` rendering, and external-link launch that syncs
  `/v1/workplace/apps/:app_id/record`.
- `Push / platform` now includes Android `POST_NOTIFICATIONS`, iOS
  remote-notification background mode, Runner entitlements linkage, and an
  explicit FCM-only fallback log path.
- `Red Dot` unread clear now falls back to the open-source typo path
  `/v1/coversation/clearUnread` only when the canonical
  `/v1/conversation/clearUnread` returns 404, preventing false-positive
  masking of real server failures.
- `Bot stream` now has typed Flutter client coverage for
  `/v1/robots/:robot_id/:app_key/stream/start|end`, but runtime/UI integration
  remains unfrozen and is still treated as an audit-first/product-scope track.
- `Open API / OAuth UI` is now closed for the active migration scope: Flutter
  now injects a `WebViewJavascriptBridge`-compatible JS shim into the shared
  embedded WebView, handles the audited `auth` bridge call, fetches
  `/v1/apps/:app_id` app metadata plus `/v1/openapi/authcode`, and returns the
  approved authcode to the page callback after a native consent sheet.
- Fresh platform evidence now includes successful `flutter build web --debug`
  and `flutter build windows --debug`, Android toolchain confirmation from
  `flutter doctor -v`, an Android APK build timeout without artifact on this
  host, and no available `flutter build ios` subcommand from this Windows
  Flutter installation.

## Verification Requirements

Every phase child task must include:

- API/service test coverage for route and payload handling
- widget-level regression coverage for new settings/entry surfaces
- re-validation against the master plan before marking a phase item complete

## Non-Goals

- Do not rebuild already migrated features just because the original report says
  they are missing.
- Do not expand workplace, crypto, or robot streaming on top of unverified
  route assumptions.
