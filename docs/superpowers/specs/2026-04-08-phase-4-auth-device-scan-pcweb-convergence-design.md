# Phase 4 Auth, Device Session, Scan, And PC-Web Convergence Design

**Date:** 2026-04-08
**Scope:** Refresh the auth/device-login program design so the Flutter app converges on one truthful production chain for phone/password login, scan-based Web login confirmation, device-session management, and PC/Web session entry ownership
**Phase Boundary:** This spec implements `Phase 4` from [2026-04-07-android-reference-parity-master-blueprint.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/plans/2026-04-07-android-reference-parity-master-blueprint.md)
**Approved Strategy:** `B` - converge the existing auth mainline around one owner chain instead of rebuilding the whole subsystem from scratch
**User Decisions Locked:** exclude third-party login from this phase, prioritize mainline auth chain closure before legacy cleanup, allow coordinated backend changes, and use phone/password login as the primary acceptance path
**Git Status Note:** This workspace is not currently backed by a Git repository, so this spec can be written locally but cannot be committed yet

## 1. Why This Spec Exists

The older auth design at [2026-04-04-phase-3-auth-device-login-alignment-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-04-phase-3-auth-device-login-alignment-design.md) is no longer the correct execution baseline.

It predates the current master blueprint numbering, predates recent scan and auth convergence work, and still assumes older remote-debugging infrastructure. We therefore need a refreshed Phase 4 design based on the current codebase truth rather than on the earlier "rebuild-first" assumption.

This refreshed spec supersedes the earlier auth design as the current design authority for Phase 4 execution.

## 2. Problem Statement

The Flutter codebase now contains a partially converged auth mainline, but the production truth is still not fully locked to one owner chain.

Current positive reality:

- [`lib/modules/auth/data/auth_repository_impl.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/data/auth_repository_impl.dart) already centralizes phone login, username login, registration, login verification, password reset, profile completion, device sessions, Web login confirmation, and legacy third-login bridge calls.
- [`lib/modules/auth/application/auth_flow_controller.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/application/auth_flow_controller.dart) already drives a typed auth state machine.
- [`lib/modules/auth/application/auth_providers.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/application/auth_providers.dart) already wires the repository, bootstrap coordinator, and device-session controller into the main runtime.
- [`lib/wukong_scan/scan_result_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_scan/scan_result_page.dart) already routes `loginConfirm` scans into [`AuthWebLoginConfirmPage`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart).
- [`test/modules/auth/auth_device_sessions_web_login_test.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/auth/auth_device_sessions_web_login_test.dart) and [`test/modules/auth/auth_routes_compile_test.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/auth/auth_routes_compile_test.dart) already prove part of the intended owner chain.

Current unresolved reality:

- [`lib/wukong_login/pc_login_service.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/pc_login_service.dart) is still a stub-heavy legacy service with `TODO` placeholders and demo returns.
- legacy `wukong_login/**` entrypoints still exist and need an explicit final role: wrapper, bridge, or retired
- device-session, PC/Web entry, scan confirmation, and login success all need to be verified against the same deployed backend contract
- several auth-facing screens still contain mojibake copy, which is a real production bug
- the current code exposes third-login plumbing even though this phase is now explicitly not responsible for making third-party login product-complete

Phase 4 therefore is not "build auth from zero." It is "finish owner convergence, validate the real backend chain, and retire false owners."

## 3. Product Mandate

This phase must produce one truthful auth/session chain for the following user-visible capabilities:

- phone/password login
- login follow-up verification when the backend requires it
- scan-based Web login confirmation
- PC/Web session list and remote removal
- consistent production routing into the same auth/session authority

This phase must not claim completion based only on page existence, compile success, or old wrapper compatibility. Completion requires:

- one real owner chain
- real deployed-backend validation
- honest runtime verification

## 4. Explicit In-Scope And Out-of-Scope Boundaries

### 4.1 In Scope

- phone/password login as the primary acceptance chain
- login verification follow-up if required by the real backend
- post-login bootstrap integrity where it affects entry into the authenticated app
- device-session list, remote removal, and quit-all-PC/Web flow
- scan-result routing for Web login confirmation
- PC/Web login management entry convergence onto the same owner chain
- cleanup decisions for `wukong_login/**` and `pc_login_service.dart`
- backend changes on `ubuntu@42.194.218.158` when the deployed contract blocks truthful convergence

### 4.2 Out Of Scope

- third-party login product delivery
- unrelated chat/group/settings features
- speculative auth features not confirmed by either current Flutter code, Android reference, or deployed backend
- aesthetic-only refactors that do not help owner convergence or verification

## 5. Current Code Truth

### 5.1 Owner Candidates That Already Exist

The likely authoritative owner chain is already visible in source:

- UI and route entry:
  - [`lib/modules/auth/presentation/pages/**`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/presentation/pages)
  - [`lib/app/navigation/app_router.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/app/navigation/app_router.dart)
- flow state and orchestration:
  - [`lib/modules/auth/application/auth_flow_controller.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/application/auth_flow_controller.dart)
  - [`lib/modules/auth/application/device_session_controller.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/application/device_session_controller.dart)
  - [`lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart)
- backend contract convergence:
  - [`lib/modules/auth/data/auth_repository_impl.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/data/auth_repository_impl.dart)
  - [`lib/service/api/login_bridge_api.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/service/api/login_bridge_api.dart)
  - [`lib/service/api/auth_api.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/service/api/auth_api.dart)

### 5.2 Legacy Paths That Cannot Remain Owners

- [`lib/wukong_login/pc_login_service.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/pc_login_service.dart)
  - contains placeholder polling and mock returns
  - cannot remain a production owner
- legacy `wukong_login` entrypages
  - may survive as wrappers for compatibility
  - must not continue to own business decisions once Phase 4 is complete

### 5.3 Scan/Auth Boundary

[`lib/wukong_scan/scan_result_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_scan/scan_result_page.dart) should remain the routing owner for parsed scan outcomes, but for auth it must stop at one boundary:

- recognize `loginConfirm`
- route to `AuthWebLoginConfirmPage`
- do not duplicate login-confirm business logic locally

## 6. Approved Design Strategy

The approved strategy is convergence, not rebuild.

### 6.1 Rejected Strategy: Full Auth Rewrite

We explicitly reject a full rewrite because the codebase already has:

- a typed auth state model
- a bootstrap coordinator
- a working repository layer
- route registration
- regression tests

Rebuilding all of that would increase risk while duplicating already-landed work.

### 6.2 Approved Strategy: Mainline Owner Convergence

Phase 4 will:

- keep `modules/auth/**` as the only production auth mainline
- keep `AuthRepositoryImpl` as the principal auth contract convergence layer
- keep `login_bridge_api.dart` as the only PC/Web/device-session bridge API owner
- keep `scan_result_page.dart` as the scan routing owner
- demote `wukong_login/**` to wrapper/bridge status where still needed
- demote `pc_login_service.dart` to legacy-only status or remove it from production ownership completely

## 7. Architecture And Component Boundaries

### 7.1 Auth Presentation Pages

Auth presentation pages own:

- form rendering
- validation presentation
- loading and retry surfaces
- navigation triggers produced by controllers

They do not own:

- low-level API stitching
- session persistence rules
- device-session backend policy

### 7.2 Flow Controllers

`AuthFlowController` and `DeviceSessionController` own:

- transient page state
- submission status
- recoverable error states
- retry and refresh semantics

They must remain page-facing orchestrators, not become a second API layer.

### 7.3 Repository Layer

`AuthRepositoryImpl` owns auth-side backend convergence across:

- `AuthApi`
- `LoginBridgeApi`
- `UserApi`

This is the place where multiple backend contracts are normalized into one app-facing interface.

### 7.4 Login Bridge API

`login_bridge_api.dart` owns:

- login UUID / QR generation
- login status polling contract
- Web login grant
- PC/Web quit-all
- device-session list and deletion

This ownership must be exclusive. No parallel service may keep an alternative implementation of the same bridge behavior.

### 7.5 Scan Routing Layer

`scan_result_page.dart` owns scan result routing only. For auth-related scans it must:

- identify a login confirmation result
- hand off to `AuthWebLoginConfirmPage`
- avoid duplicate confirmation state or backend mutation logic

## 8. Primary Data Flows

### 8.1 Phone/Password Login

The canonical login path is:

1. `AuthLoginPage`
2. `AuthFlowController.loginWithPhone(...)`
3. `AuthRepositoryImpl.loginWithPhone(...)`
4. `AuthBootstrapCoordinator.bootstrap(...)`
5. `AuthNotifier.commitBootstrapResult(...)`
6. router transition into authenticated runtime

This is the primary acceptance path for Phase 4.

### 8.2 Login Verification Follow-Up

If the backend requires extra login verification:

1. `AuthRepositoryImpl.loginWithPhone(...)` returns verification-required state
2. `AuthFlowController` enters `awaitingLoginVerification`
3. verification page(s) collect and submit code
4. successful verification re-enters the same bootstrap transaction as normal login

There must not be a separate, weaker post-verification success chain.

### 8.3 Device Sessions

The canonical device-session path is:

1. `AuthDeviceSessionsPage`
2. `DeviceSessionController`
3. `AuthRepositoryImpl.loadDevices/deleteDevice/quitPcWebSessions`
4. `LoginBridgeApi`

This path must become the only truthful device-session owner chain.

### 8.4 Scan-Based Web Login Confirmation

The canonical scan-confirm path is:

1. scan parse result identifies `loginConfirm`
2. `ScanResultPage`
3. `AuthWebLoginConfirmPage`
4. `AuthRepositoryImpl.grantWebLogin(...)`
5. `LoginBridgeApi.grantLogin(...)`

This path must be validated end-to-end against the deployed backend.

### 8.5 Legacy Entry Wrappers

Legacy wrappers under `wukong_login/**` may stay only if they do this:

- receive the old entry call
- construct or forward to the new `modules/auth/**` page
- perform no hidden business logic beyond bridging required parameters

## 9. Legacy Cleanup Rules

### 9.1 `pc_login_service.dart`

`pc_login_service.dart` must be explicitly reclassified in this phase.

Acceptable end states:

- removed from production imports and retained only as dead legacy code pending later deletion
- converted into a trivial compatibility facade that delegates to `LoginBridgeApi`

Unacceptable end state:

- still being treated as a production service owner with its current placeholder methods

### 9.2 `wukong_login/**`

Each legacy entrypoint must end Phase 4 as exactly one of:

- wrapper over a `modules/auth/**` page
- compatibility export
- dead path isolated from production routing

No legacy entrypoint may remain a second production business owner.

## 10. Backend Alignment Policy

This phase is explicitly allowed to change backend code when the deployed contract blocks truthful convergence.

Approved runtime/backend environment:

- `ssh ubuntu@42.194.218.158`

Backend changes are allowed only when they unblock one of the in-scope auth/session chains:

- phone/password login
- login verification
- device sessions
- scan-based Web login confirmation
- PC/Web session management

This phase must not turn into a broad backend rewrite. Every backend change must trace back to one blocked owner chain.

## 11. Error Handling Rules

### 11.1 Recoverability

The following failures must remain recoverable from the visible page state:

- phone/password login failure
- login verification code failure
- Web login confirm failure
- device-session removal failure
- quit-all-PC/Web failure

No page is allowed to enter a permanently disabled state after a generic transient failure.

### 11.2 Business Success Vs HTTP Success

This phase keeps the same honesty rule already enforced in recent scan work:

- HTTP `200` does not imply business success
- envelope `code`/`status`/message semantics must still be checked

This matters especially for:

- Web login grant
- login status polling
- device deletion

### 11.3 Text Hygiene

Mojibake in auth-facing production pages is treated as a real bug in this phase.

Phase 4 must leave the active auth/session surfaces with clean readable copy, at least for:

- device-session page
- Web login confirmation page
- scan login-confirm result page if it remains on a production path

## 12. Verification Strategy

Phase 4 completion requires three verification layers.

### 12.1 Local Verification

Minimum local verification covers:

- `flutter analyze` over `modules/auth`, `wukong_login`, `wukong_scan`, `login_bridge_api.dart`, router files
- targeted tests for:
  - auth flow
  - device sessions
  - Web login confirm
  - scan login-confirm routing
  - legacy wrapper compile paths

### 12.2 Real Backend Verification

Using `ssh ubuntu@42.194.218.158`, Phase 4 must verify the real deployed contract for:

- phone/password login
- login verification if currently enabled
- device-session list
- device-session delete / quit-all
- Web login confirmation

Where needed, server logs or direct endpoint checks must prove the chain used by Flutter is the same chain being validated.

### 12.3 Manual Runtime Verification

Manual/runtime validation must cover:

- phone/password login reaches authenticated runtime
- authenticated user can open device sessions and see live data
- scan result for login confirmation reaches `AuthWebLoginConfirmPage`
- confirmation action succeeds or fails honestly against the live backend
- any user-center or compatibility entry to PC/Web session management lands on the same production owner chain

## 13. Exit Gate

Phase 4 is complete only when all of the following are true:

- phone/password login is the one truthful primary auth chain
- login verification, when required by the backend, rejoins the same bootstrap chain
- device sessions and Web login confirmation both route through `AuthRepositoryImpl -> LoginBridgeApi`
- `scan_result_page.dart` routes login confirmation into the auth mainline without duplicating auth business logic
- `pc_login_service.dart` is no longer a production owner
- legacy `wukong_login/**` paths are wrappers/bridges only
- local verification, real backend validation, and manual runtime checks all succeed
- third-party login is not counted toward completion and does not block honest Phase 4 closure

## 14. Immediate Planning Consequence

The next implementation plan should not be a from-scratch auth rebuild.

It should instead be a Phase 4 convergence plan that:

- audits what is already landed
- removes false owners
- validates the real backend chain on `42.194.218.158`
- closes any remaining login/device/scan/PC-Web gaps in the current mainline

