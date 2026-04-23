# Phase 3 Auth And Device Login Alignment Design

**Date:** 2026-04-04
**Scope:** Build a new authoritative Flutter authentication and device-login subsystem that strictly matches the TangSengDaoDao Android reference on Android while exceeding it in flow orchestration, resilience, observability, and maintainability
**Phase Boundary:** This spec implements `Phase 3` from [2026-04-03-complete-feature-alignment-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-03-complete-feature-alignment-design.md)
**Approved Strategy:** `3` - build the new authentication architecture skeleton first, then migrate Android-reference flows into it instead of extending the current dual-track Flutter auth paths
**Git Status Note:** This workspace is not currently backed by a Git repository, so this spec can be written locally but cannot be committed yet

## 1. Problem Statement

The Flutter app already contains real login-related code, but it does not yet have one Android-reference-grade authentication subsystem.

The current implementation is split between two active-but-incomplete tracks:

- [`lib/modules/auth`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth)
- [`lib/wukong_login`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login)

The first track currently owns the app router entry through [`app_router.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/app/navigation/app_router.dart), but it mainly covers phone login and registration. The second track still holds reusable assets such as PC/Web login QR flow, Web login confirmation, device management, third-party login, and MVP-era login plumbing, but it is not the authoritative product path.

This creates the same structural problem already seen in search and other modules:

- duplicate ownership
- inconsistent UX and styling
- incomplete Android flow coverage
- no single transaction boundary for login bootstrap
- weak linkage between authentication, IM bootstrap, push registration, and device identity

Phase 3 therefore cannot be treated as "add a few missing login pages." It must establish a new auth/device-login mainline and then attach the Android-reference flow set to that mainline.

## 2. Product Mandate

This phase must satisfy both project mandates at the same time:

- on Android, the user-visible login, registration, verification, reset-password, Web/PC login confirmation, device-session management, and profile-completion behavior must align with the TangSengDaoDao Android reference
- internally, the Flutter implementation must exceed the Android reference through stronger state orchestration, better route coherence, cleaner module ownership, richer diagnostics, and safer cross-feature transactions

Remote debugging through `ssh root@103.207.68.33` remains an approved execution path whenever real server behavior and local assumptions diverge.

## 3. Goals

- Build one authoritative authentication subsystem under the active app mainline.
- Cover the Android-reference account-entry flow family end to end.
- Unify credential login, verification follow-up, profile completion, IM bootstrap, push setup, and device identity bind into one coherent transaction.
- Rebuild PC/Web login and device-session management as first-class authenticated features rather than isolated pages.
- Preserve the ability to exceed the Android reference in operational quality without changing the visible Android behavior contract.

## 4. Non-Goals

- This phase does not redesign unrelated chat, contacts, or home-tab systems.
- This phase does not replace backend contracts as a first move unless server validation proves a blocking mismatch.
- This phase does not require immediate cross-platform behavior parity outside Android.
- This phase does not finalize endpoint/UIKit-wide rebuild work from Phase 2; it only integrates with that architecture where authentication needs it.
- This phase does not promise third-party login availability if the deployed backend has not enabled the required OAuth providers, but it does require the Flutter module to support the Android-reference flow shape and graceful capability gating.

## 5. Reference Anchors

The Android behavior contract for this phase is anchored to the following source files:

- [`WKLoginActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/WKLoginActivity.java)
- [`ChooseAreaCodeActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/ChooseAreaCodeActivity.java)
- [`WKRegisterActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/WKRegisterActivity.java)
- [`WKResetLoginPwdActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/WKResetLoginPwdActivity.java)
- [`LoginAuthActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/LoginAuthActivity.java)
- [`InputLoginAuthVerificationCodeActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/InputLoginAuthVerificationCodeActivity.java)
- [`PerfectUserInfoActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/PerfectUserInfoActivity.java)
- [`WKWebLoginConfirmActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/WKWebLoginConfirmActivity.java)
- [`PCLoginViewActivity.java`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/PCLoginViewActivity.java)
- [`ThirdLoginActivity.kt`](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin/src/main/java/com/chat/login/ui/ThirdLoginActivity.kt)

## 6. Current Flutter Auth Audit

### 6.1 Active Mainline

The current app router sends unauthenticated users to [`lib/modules/auth/login_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/login_page.dart). This means any Phase 3 implementation that does not take control of `modules/auth` will remain structurally second-class.

Relevant mainline assets already exist:

- [`auth_provider.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/data/providers/auth_provider.dart)
- [`auth_api.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/service/api/auth_api.dart)
- [`login_bridge_api.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/service/api/login_bridge_api.dart)
- [`modules/auth/login_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/login_page.dart)
- [`modules/auth/register_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/register_page.dart)

Strengths already present:

- token persistence and session restore
- IM bootstrap handoff through the existing auth provider
- device identity binding on successful login
- phone login and two forms of registration
- router-level auth gating

### 6.2 Reusable Legacy-Or-Sidecar Assets

The older [`lib/wukong_login`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login) tree still contains valuable product assets:

- [`pc_login_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/pc_login_page.dart)
- [`web_login_confirm_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/web_login_confirm_page.dart)
- [`third_login_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/third_login_page.dart)
- [`pc_login_management_page.dart`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login/pc_login_management_page.dart)

These are not throwaway. They prove backend bridge capability and already encode useful behavior. But they are not organized as the mainline auth product system and should not remain a parallel product branch.

### 6.3 Confirmed Gaps Against Android

Compared with the Android reference, the Flutter mainline still lacks or incompletely wires:

- login second-factor follow-up flow
- explicit verification-code input page for login auth
- reset-password page in the active auth route family
- profile-completion flow after successful auth when required fields are missing
- coherent area-code chooser behavior across login, register, and reset-password
- PC/Web login confirmation integrated as a routed authenticated flow
- one unified device-session center aligned with login state and runtime capabilities
- clean capability gating for third-party login
- coherent flow transaction after auth success
- a single owner for all auth-related route decisions and side effects

## 7. Why Strategy 3 Is The Right Choice

The user selected strategy `3` for this phase: build the new auth architecture skeleton first, then migrate.

This is the correct choice because:

- strategy `1` would improve the current mainline faster, but it would still force repeated migration decisions while implementing product-critical flows
- strategy `2` would preserve the current dual-track drift and postpone structural cleanup
- strategy `3` creates one clean contract for all future login-related work, which is especially important because authentication touches routing, storage, push, device identity, scan, and IM bootstrap at the same time

Phase 3 is therefore both a product-completion phase and an architecture-convergence phase.

## 8. Target Architecture

### 8.1 Authoritative Module

The new authoritative subsystem remains rooted at [`lib/modules/auth`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth), because that path already owns the app router contract. However, it will be rebuilt internally into clear sub-boundaries rather than remaining a flat pair of pages.

Target layout direction:

- `lib/modules/auth/domain`
- `lib/modules/auth/application`
- `lib/modules/auth/data`
- `lib/modules/auth/presentation`
- `lib/modules/auth/coordinators`
- `lib/modules/auth/widgets`
- `lib/modules/auth/compat`

The old [`lib/wukong_login`](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_login) tree becomes a migration-source layer and then a compatibility shell where necessary, not an equal product path.

### 8.2 Core Building Blocks

The new auth subsystem should formalize these responsibilities:

- `AuthFlowState`
  - the typed state machine for unauthenticated, submitting, awaiting auth verification, awaiting profile completion, authenticated bootstrapping, authenticated ready, and device-session side flows
- `AuthRepository`
  - one contract over `AuthApi`, `LoginBridgeApi`, and any runtime capability fetches
- `AuthBootstrapCoordinator`
  - owns the post-auth transaction: persist token, load current user, bind device identity, initialize IM, register push, refresh drafts, and resolve the next route
- `AuthRouteCoordinator`
  - maps route entries from login, scan, Web-login callbacks, or device-session actions into the correct auth flow surface
- `DeviceSessionController`
  - owns PC/Web login records, current-device lock state, explicit sync state, and remote-device actions
- `AuthCapabilityController`
  - exposes server/runtime capability flags that determine whether third-party login, Web login, invite-code registration, or device-center warnings should appear

### 8.3 Typed State Machine

The subsystem should treat account entry as a state machine, not a loose collection of pages.

Core states:

- `restoringSession`
- `unauthenticated`
- `submittingCredentials`
- `awaitingLoginVerification`
- `awaitingRegistrationCode`
- `awaitingPasswordResetCode`
- `awaitingProfileCompletion`
- `bootstrappingAuthenticatedSession`
- `authenticatedReady`
- `loadingExternalLoginConfirmation`
- `managingDeviceSessions`

The purpose is to stop encoding critical auth transitions implicitly inside widget callbacks.

### 8.4 Transaction Boundary

The moment a credential, auth code, QR auth code, or third-party result succeeds, the system must pass through one shared bootstrap transaction:

1. persist auth result
2. normalize user identity
3. bind device identity
4. fetch current user if needed
5. initialize IM runtime
6. trigger push registration
7. load draft scope
8. determine whether profile completion is required
9. route to the correct destination

This transaction is the main place where the Flutter implementation should exceed the Android reference in reliability and observability.

## 9. Flow Coverage Required For Parity

### 9.1 Credential Login

Flutter must match Android behavior for:

- phone login with area code
- validation order
- agreement enforcement
- password visibility toggle
- login failure messaging
- login-auth redirect when the backend requires extra verification

### 9.2 Area Code Selection

Area code must become one shared reusable auth component used consistently by:

- login
- phone registration
- reset password

It must no longer exist as duplicated picker logic in separate pages.

### 9.3 Registration

The subsystem must support:

- phone registration
- username registration where supported
- invite-code requirement gating when backend config requires it
- SMS code countdown and resend
- post-registration bootstrap
- profile completion handoff when necessary

### 9.4 Login Verification

The Flutter app must add the Android-style two-step follow-up flow:

- login returns "needs verification"
- intermediate explanation page
- verification code input page
- successful verification enters the same bootstrap transaction as normal login

### 9.5 Reset Password

The reset-password flow must become an actual routed auth page, not a placeholder feedback branch.

It must support:

- area code
- phone number
- verification code request
- countdown/resend
- new password set
- success return semantics consistent with Android

### 9.6 Profile Completion

When the authenticated user lacks required profile fields, Flutter must show a post-auth profile-completion page aligned with Android's `PerfectUserInfoActivity` behavior.

Required outcome:

- profile completion blocks direct home entry until the minimum profile requirement is satisfied
- success continues through the normal post-login route resolution

### 9.7 PC/Web Login Confirmation

The Flutter app already has bridge code here, but it must be reorganized into the new auth route family.

Required coverage:

- scan or external auth code opens confirmation flow
- user can confirm or cancel
- success updates server session state and user feedback
- behavior remains coherent whether the entry came from QR scan or a pending desktop auth route

### 9.8 Device Session Center

The device center should remain richer than Android where it helps, but it must still preserve Android-visible semantics:

- show current and remote logged-in devices
- support remote-device removal
- support exit-all PC/Web login
- support current-device lock state
- expose sync/refresh state clearly

Where Flutter exceeds Android, it should do so in diagnostics and resilience, not by inventing a different core flow.

### 9.9 Third-Party Login

Third-party login remains in scope because the Android reference includes it.

However, the Flutter implementation should be capability-gated:

- if providers are enabled, show Android-aligned entry and completion flow
- if providers are unavailable, hide or disable the entry with a clean reason instead of exposing a dead-end path

## 10. Migration Strategy

### 10.1 New Skeleton First

Before moving visible pages, the implementation should land:

- new auth domain models
- repository contracts
- flow state machine
- bootstrap coordinator
- device-session controller
- route coordinator

This creates the execution surface that later tasks plug into.

### 10.2 Move Existing Strong Assets Into The New Skeleton

The following current Flutter assets should be migrated, not blindly rewritten:

- `auth_provider` login transaction pieces
- `AuthApi` and `LoginBridgeApi`
- `PCLoginPage`
- `WebLoginConfirmPage`
- `ThirdLoginPage`
- `PCLoginManagementPage`

The goal is to preserve what is already strong while ending structural duplication.

### 10.3 Replace Legacy Entrypoints With Compatibility Wrappers

Once the new pages exist, old exports or route targets should become thin wrappers:

- old `modules/auth` flat pages route into the new presentation pages
- old `wukong_login` pages either wrap or export the new mainline pages

This keeps callers stable during migration while preserving one product path.

## 11. Technical Decisions That Must Exceed Android

### 11.1 Routing

Authentication should be orchestrated through explicit routes and coordinators rather than ad hoc `Navigator.push` chains embedded in many unrelated widgets.

This is especially important for:

- login verification redirect
- reset-password entry
- scan-driven Web login confirmation
- post-login profile-completion redirect
- device-session deep links

### 11.2 Error Handling

The subsystem should separate:

- field validation errors
- backend business-rule failures
- temporary network failures
- capability-disabled states
- post-auth bootstrap failures

The Android reference often compresses these into dialogs or toasts. Flutter should keep the visible behavior familiar while making the internal error categories explicit.

### 11.3 Observability

The new auth core should emit structured diagnostics around:

- login attempt start and finish
- login verification required
- registration code send success and failure
- Web/PC login confirm success and failure
- device-session refresh and deletion
- bootstrap stage success and failure

This is a direct superiority target over the reference implementation.

### 11.4 Text And Encoding Hygiene

Several current Flutter auth surfaces contain visible mojibake-like text corruption. Phase 3 must treat this as a real product bug, not a cosmetic side issue.

All new mainline auth surfaces must:

- use clean UTF-8 source text
- preserve the Android-reference Chinese copy where appropriate
- structure strings so they can later be internationalized cleanly

## 12. Acceptance Criteria

Phase 3 is complete only when all of the following are true:

- unauthenticated routing enters one new authoritative auth mainline
- Android-reference login, register, reset-password, login-verification, profile-completion, Web-login-confirm, and device-session flows are reachable on Android
- successful auth always passes through one shared bootstrap transaction
- PC/Web login and device-session management are integrated with the authenticated runtime, not isolated side pages
- old duplicate auth implementations are either removed from production routing or reduced to thin wrappers
- visible auth text and validation behavior are production-ready
- runtime capability gates prevent dead-end third-party or Web-login affordances

## 13. Testing And Validation Strategy

### 13.1 Required Test Layers

- unit tests for auth flow reducers/controllers/coordinators
- widget tests for login, register, reset-password, login-verification, profile-completion, Web confirm, and device-session surfaces
- route tests for unauthenticated and post-auth redirects
- integration-style tests for the post-auth bootstrap transaction

### 13.2 Remote Validation Rule

Use `ssh root@103.207.68.33` when:

- login verification responses differ from local assumptions
- Web/PC login QR or auth-code behavior appears inconsistent
- device-session records or delete/quit actions behave differently from expected payload shapes
- third-party login callback behavior is unclear

Minimum likely server checks during execution:

- container/process status for the deployed server stack
- recent server logs around `/v1/user/loginuuid`, `/v1/user/loginstatus`, `/v1/user/grant_login`, `/v1/user/devices`, and auth endpoints
- payload-shape verification when Flutter parsing and runtime behavior disagree

## 14. Risks And Mitigations

### 14.1 Risk: Rebuilding Too Much Before Shipping Behavior

Mitigation:

- land the new auth skeleton first, but keep the plan split into thin vertical tasks that each close a user-visible flow

### 14.2 Risk: Keeping Two Product Auth Paths Alive

Mitigation:

- new feature work lands only on the new mainline
- old pages become wrappers as soon as each migrated flow is stable

### 14.3 Risk: Backend Capability Drift

Mitigation:

- expose explicit runtime capabilities in the new auth core
- validate server behavior through SSH when local assumptions fail

### 14.4 Risk: Bootstrap Failures Leaving The App Half-Logged-In

Mitigation:

- centralize the post-auth transaction
- make partial failure handling explicit
- keep token persistence, IM bootstrap, and push registration observable and recoverable

## 15. Final Design Decision

The approved Phase 3 design direction is:

`Build a new authoritative Flutter authentication and device-login subsystem inside the active app mainline, use it to absorb and replace the current dual-track auth paths, and migrate the full TangSengDaoDao Android login flow family onto that subsystem with stronger route coordination, typed state orchestration, unified post-auth bootstrap, and production-grade device-session management.`

## 16. Immediate Next Step

After user review of this spec, the next step is to invoke `superpowers:writing-plans` and create the detailed Phase 3 implementation plan for the new auth/device-login subsystem.
