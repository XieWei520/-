# Phase 4 Web CORS And PC-Quit Strong Semantics Design

**Date:** 2026-04-08
**Scope:** Close the remaining truthful Phase 4 runtime gaps by making normal-browser Web startup pass CORS, and by redefining `/v1/user/pc/quit` to remove other PC/Web device records in addition to ending their online sessions.
**Phase Boundary:** This spec extends [2026-04-08-phase-4-auth-device-scan-pcweb-convergence-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-08-phase-4-auth-device-scan-pcweb-convergence-design.md) and resolves the last blocked runtime exit-gate behaviors discovered during live verification.
**Approved Strategy:** `B` - strengthen `/v1/user/pc/quit` so it becomes a true "quit and remove other PC/Web logins" action, instead of only clearing online state.
**User Decisions Locked:** fix production CORS for normal Web browsers, preserve the current device during quit-all, remove only other PC/Web device records, and keep the Flutter action aligned with the stronger product meaning.
**Git Status Note:** This workspace is not currently backed by a Git repository, so this spec can be written locally but cannot be committed yet.

## 1. Why This Spec Exists

The base Phase 4 auth/device convergence work is functionally close, but two truthful runtime blockers remain:

- normal Web browsers still fail during authenticated startup because production `OPTIONS` responses do not allow `X-Device-ID` and `X-Device-Session-ID`
- `/v1/user/pc/quit` returns success, but the device-management page still shows the same PC/Web entries because the backend only clears online state and never removes device records

These are no longer speculative findings. They were observed directly during live runtime verification against `42.194.218.158` on 2026-04-08.

This spec therefore exists to define the final Phase 4 behavior precisely enough that implementation can close the remaining honesty gaps without inventing new product semantics mid-flight.

## 2. Runtime Truth Captured From Live Verification

### 2.1 Web CORS Is Blocked At The Production Edge

The Flutter Web authenticated startup flow reads stored auth state, loads the current user, and sends authenticated requests with `X-Device-ID` and optionally `X-Device-Session-ID` from [wk_http_client.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wk_foundation/net/wk_http_client.dart).

The live `OPTIONS http://42.194.218.158/v1/user/device/bind` response observed on 2026-04-08 was:

- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Headers: Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, token, accept, origin, Cache-Control, X-Requested-With, appid, noncestr, sign, timestamp`

It did **not** include:

- `X-Device-ID`
- `X-Device-Session-ID`

That means a normal browser blocks the real startup chain before Flutter can complete authenticated restore.

At the same time, the backend codebase itself already expects those headers and the Go CORS helper in [http.go](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/pkg/wkhttp/http.go) already includes them. The mismatch is therefore at the production nginx edge, not in the intended application logic.

### 2.2 `/v1/user/pc/quit` Does Not Currently Match The Flutter Product Meaning

The live Flutter page at [auth_device_sessions_page.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/presentation/pages/auth_device_sessions_page.dart) currently presents the action as a quit-all PC/Web login action, not as a pure online-status toggle.

Live verification showed:

- the Flutter button truly hits `POST /v1/user/pc/quit`
- the endpoint truly returns `200`
- the subsequent `GET /v1/user/devices` response still contains the same PC/Web device records

Production code explains why:

- [api_online.go](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_online.go) only calls `QuitUserDevice(Web)` and `QuitUserDevice(PC)`
- [db_device.go](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/db_device.go) stores only `uid`, `device_id`, `device_name`, `device_model`, `last_login`
- there is no persisted `device_flag` on the `device` table, so the backend cannot currently distinguish historical APP/Web/PC records well enough to remove only the intended ones

So the current runtime mismatch is real:

- Flutter presents a removal-like device-management action
- backend implements an online-session action only

## 3. Product Decision Locked By This Spec

The stronger product meaning is now official:

`/v1/user/pc/quit` must become a "quit and remove other PC/Web logins" action.

More specifically:

- the endpoint must terminate active PC/Web online sessions for the logged-in user
- the endpoint must also remove the corresponding persisted PC/Web device records from the device-management list
- the endpoint must **not** remove the current device record
- the endpoint must **not** remove APP device records

This design intentionally diverges from the current Android-era backend behavior because the user explicitly selected the stronger product meaning and rejected keeping the old semantics.

## 4. Goals And Non-Goals

### 4.1 Goals

- allow normal-browser Flutter Web startup without disabling browser web security
- make the device-management page behavior match its user-visible promise
- preserve truthful device-history boundaries so only other PC/Web records are removed
- keep the current device safe during the quit-all action
- keep scan-confirm and grant-login behavior unchanged except where needed for verification coverage

### 4.2 Non-Goals

- no broad backend rewrite beyond CORS and PC/Web session/device semantics
- no redesign of Android legacy flows beyond preserving compatibility where possible
- no speculative encryption/public-key product work in the Web login flow
- no changes to unrelated chat, contacts, or settings modules

## 5. Approved Design

### 5.1 Fix CORS At Production Nginx, Not By Browser Workarounds

The accepted production fix is to update the nginx edge configuration used by `wukongim_prod-nginx-1`, not to rely on:

- disabled browser web security
- localStorage tricks as a permanent solution
- same-origin-only development smoke paths

The nginx template at [default.conf.template](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/nginx/default.conf.template) must explicitly allow:

- `X-Device-ID`
- `X-Device-Session-ID`

for preflight requests on the API routes served through nginx.

After this change, a normal browser must be able to complete:

1. stored-session restore
2. current-user fetch
3. device bind or device-session-authenticated requests
4. entry into authenticated Flutter routes

without `--disable-web-security`.

### 5.2 Persist Device Type On Device Records

The current `device` table is too weak for strong quit semantics because it stores no device class. This spec therefore requires a small schema and persistence upgrade:

- add `device_flag` to the `device` table
- populate it on:
  - normal login in [api.go](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api.go)
  - auth-code login in the same file
- preserve existing values for old rows by backfilling a safe default

Expected mapping stays aligned to existing config usage:

- `0` = APP
- `1` = Web
- `2` = PC

This is the minimum data-model change that makes the stronger product behavior implementable without guessing from `device_model` strings.

### 5.3 Redefine `/v1/user/pc/quit` To Be A Compound Action

After this spec, `POST /v1/user/pc/quit` must do all of the following for the logged-in user:

1. quit Web online session state
2. quit PC online session state
3. remove persisted `device` rows whose `device_flag` is `Web` or `PC`
4. preserve the current device row, identified from request device identity/session context
5. preserve all APP device rows

The endpoint remains one logical user action. Flutter should not have to emulate batch deletion on the client.

### 5.4 Preserve The Current Device

The current device must survive the quit-all action even if it is itself a Web or PC session. This preserves:

- consistent current-device expectations in Flutter
- safer recovery if the user triggers the action from Web/Desktop
- alignment with the page rule that self cannot be removed via the per-device button

Current-device preservation should be determined from request context, using the same device identity/session headers already used by Flutter.

### 5.5 Flutter Must Speak The Stronger Meaning Clearly

Once the backend semantics are upgraded, Flutter copy must stop being ambiguous.

The device-management page should make the action read as a removal-oriented cleanup action, not merely an online-state toggle. The exact wording can be finalized in implementation, but it must communicate all of these truths:

- it affects other PC/Web logins
- it removes them from the management list
- it does not remove the current device

The empty state, error state, and tests must all align to this stronger meaning.

## 6. Architecture And Boundary Decisions

### 6.1 Backend Ownership

The backend owns:

- CORS correctness at the production edge
- persisted device classification
- strong batch quit semantics

Flutter must not compensate for backend ambiguity by guessing device categories or performing heuristic cleanup.

### 6.2 Flutter Ownership

Flutter owns:

- accurate user-facing copy
- calling the one truthful backend action
- reflecting the refreshed device list after the backend mutation
- tests proving the UI/controller chain remains stable

### 6.3 Compatibility Boundary

Android legacy clients may still conceptually think of `quitPc()` as "quit Web/PC online login". This spec accepts that older clients may observe the stronger semantics after the backend update, because the user explicitly chose stronger product behavior over legacy preservation.

We do **not** create a second compatibility endpoint in this design.

## 7. Data Model Changes

### 7.1 Device Table

The `device` table gains:

- `device_flag`

Requirements:

- existing rows must remain readable
- old rows must be backfilled safely
- ordering by `last_login` must remain unchanged
- current API payload shape for device list remains stable unless a new field is explicitly added for Flutter use

### 7.2 Migration Policy

Migration should be additive and low-risk:

- add nullable or defaulted column first
- backfill existing rows to a conservative value
- update write paths
- only then rely on the field inside batch quit logic

If historical rows cannot be perfectly classified, the implementation should prefer preservation over accidental deletion.

## 8. API Behavior After The Change

### 8.1 `POST /v1/user/pc/quit`

Success means:

- online PC/Web sessions were quit
- other PC/Web device records were removed
- current device remains present

Failure means:

- neither Flutter nor verification may claim the quit-all action was complete
- the page must show the backend error honestly and remain retryable

### 8.2 `GET /v1/user/devices`

The device list remains the canonical truth for the management page.

After batch quit:

- APP rows remain
- current device row remains
- other Web/PC rows are gone

The existing payload may stay unchanged, but if the implementation adds `device_flag` to the response, Flutter may optionally use it for future clarity. That is not required for this phase.

## 9. Verification Rules

### 9.1 Browser Verification

The final acceptance path must include a normal-browser Web verification run without disabled web security.

It must prove:

- authenticated startup no longer stalls on CORS
- device-management route is reachable in a standard browser
- authenticated API calls with `X-Device-ID` and `X-Device-Session-ID` succeed through the production edge

### 9.2 Quit-All Verification

The final acceptance path for the stronger semantics must prove:

1. there is at least one other PC or Web device row for the test user
2. Flutter device-management page shows it
3. user triggers the batch action from Flutter
4. backend logs show `POST /v1/user/pc/quit`
5. follow-up `GET /v1/user/devices` no longer contains the other PC/Web rows
6. current device still exists afterward

### 9.3 Delete-Single Verification

The earlier verified single-device remove flow remains required:

- direct remove of a non-self device still works
- it must not regress while implementing the stronger batch action

### 9.4 Scan Confirm Verification

The earlier verified Web confirm chain remains required:

- `loginuuid`
- `qrcode/:uuid`
- `grant_login`
- `loginstatus -> authed`

This spec does not redesign that flow; it only keeps it as a required regression guard.

## 10. Risks And Mitigations

### 10.1 Risk: Accidentally Deleting The Current Device

Mitigation:

- explicitly identify current request device/session
- preserve matching row even if it is Web or PC
- verify this in runtime evidence, not only unit tests

### 10.2 Risk: Historical Device Rows Lack Trustworthy Type

Mitigation:

- add `device_flag` going forward
- use conservative deletion rules for legacy rows
- if legacy rows cannot be safely proven as PC/Web, preserve them

### 10.3 Risk: CORS Fix Only Hits One Path

Mitigation:

- verify preflight on at least:
  - `/v1/user/device/bind`
  - one authenticated data route used after startup, such as `/v1/user/devices`

### 10.4 Risk: Flutter Copy And Backend Semantics Drift Again

Mitigation:

- update page copy and tests in the same task group
- use runtime verification after backend deployment, not only unit assertions

## 11. Exit Gate For This Spec

This spec is satisfied only when all of the following are true:

- normal Web browsers can restore and operate authenticated Flutter routes without CORS failure
- `/v1/user/pc/quit` truly removes other PC/Web device rows
- the current device remains after the batch action
- Flutter device-management copy matches the stronger behavior
- local tests pass
- live backend logs and live UI behavior agree

## 12. Immediate Planning Consequence

The next implementation plan should be a narrow Phase 4 closure plan with two coordinated workstreams:

- production-edge CORS repair
- strong PC/Web quit semantics across backend persistence, Flutter copy, and live verification

It should not reopen broader auth architecture work, because the owner chain itself is already converged enough. The remaining work is semantic truth, persistence truth, and deployment truth.
