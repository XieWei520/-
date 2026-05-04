# Phase 5 Call Entry RTC Closure Design

**Date:** 2026-04-08
**Scope:** Close the active Flutter chat-page call entry gap by delivering truthful, production-routed 1v1 audio and video call entry parity against the Android reference, while explicitly deferring group multi-party call parity until backend and runtime contracts support it
**Refactor Radius:** Focused changes across the active chat shell, the current production call service chain, permission handling, and targeted regression coverage; no broad RTC rewrite in this phase
**Public Contract Flexibility:** Internal Flutter call ownership may be simplified and duplicate RTC paths may be retired later, but the current backend call contract remains authoritative in this phase
**Primary KPI:** A user can start, receive, accept, reject, and end a real 1v1 audio or video call from the active chat page with correct permission and failure feedback
**Git Status Note:** This workspace is not currently backed by a Git repository, so this spec can be written locally but cannot be committed yet

## 1. Problem Statement

The Flutter app already contains substantial RTC groundwork, but the active product entry is still incomplete. The visible problem is simple: the voice and video buttons in the active chat header exist, but they do nothing. The deeper problem is that the call stack currently has multiple candidate owner paths, and only one of them is actually production-routed.

Today the active user journey is inconsistent:

- the logged-in app starts the call coordinator and can receive call events
- the app can already display incoming-call overlays and open the call page
- the active call page can already place or accept a 1v1 call through the existing production service
- but the active chat header still does not launch those real flows

This means the Flutter app has meaningful call infrastructure but still fails the stricter parity question: can a user open a personal chat and start a real call from the same place as the Android reference? Right now, the answer is no.

## 2. Approved Truth Model

The approved execution boundary for this phase is intentionally narrow and honest:

- complete the 1v1 call entry path end to end
- keep all work on the authoritative production Flutter path
- do not claim group multi-party call parity in this phase
- do not treat dormant or partially wired RTC code as shipped capability

The approved truth standard is:

- if a behavior is not reachable from the active routed chat page, it is not done
- if a behavior depends on an unwired alternate RTC stack, it is not done
- if group calling still requires backend contracts that do not exist in the current server, it must remain explicitly out of scope for this phase

## 3. Confirmed Audit Facts

### 3.1 Active Flutter Production Path

The current authoritative 1v1 call chain is:

- `lib/modules/chat/chat_page_shell.dart`
- `lib/modules/video_call/video_call_service.dart`
- `lib/modules/video_call/video_call_page.dart`
- `lib/modules/video_call/call_coordinator.dart`
- `lib/service/api/call_api.dart`
- `lib/modules/video_call/call_history_service.dart`

This chain is real and active today:

- app startup starts `CallCoordinator` when logged in
- IM service hands realtime session frames into the coordinator
- incoming invites can show the overlay and open `VideoCallPage`
- `VideoCallPage` can already launch, accept, reject, and end 1v1 calls through `VideoCallService`

### 3.2 Active User-Facing Gap

The visible call buttons in the active chat header are still empty handlers in:

- `lib/modules/chat/chat_page_shell.dart`

This is the main user-facing parity blocker for this phase.

### 3.3 Dormant Alternate RTC Path

The repository also contains a more modern bootstrap-oriented stack:

- `lib/modules/video_call/call_session_service.dart`
- `lib/modules/video_call/infrastructure/call_bootstrap_api.dart`
- `lib/modules/video_call/infrastructure/call_realtime_client.dart`
- `lib/modules/video_call/media/livekit_call_media_engine.dart`

But source audit confirms this stack is not the current production owner:

- it is not instantiated into the application-level `VideoCallService.instance`
- `VideoCallPage` is still renderer-coupled to the existing `VideoCallService`
- `CallSessionService` does not yet complete the full remote state/event integration needed to replace the current production path

This stack must not be counted as already delivered parity.

### 3.4 Backend Reality

The same workspace contains the current server source at:

- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main`

Audit of `modules/extra/api.go`, `modules/extra/models.go`, and `modules/extra/db.go` confirms the current call contract is a strict two-party model:

- request uses `callee_uid`
- room model stores `caller_uid` and `callee_uid`
- pending calls query by `callee_uid`
- call-state broadcast logic routes to the single opponent of the caller

This backend is not a multi-party room contract today.

### 3.5 Android Reference Reality

The Android reference distinguishes two paths:

- personal chat: `ChatActivity` checks permissions and then offers audio/video 1v1 actions through `wk_p2p_call`
- group chat: `ChatActivity` opens `ChooseVideoCallMembersActivity`, which selects members and then invokes the endpoint extension `create_video_call`

Important consequence:

- group call behavior in the Android app is not implemented purely inside the stock `wkuikit` runtime path
- it depends on endpoint extension ownership outside the stock chat activity itself

So Flutter cannot honestly claim group-call parity by merely copying the selection UI without also having a matching runtime and backend contract.

## 4. Goals

- Make the active Flutter personal chat page capable of launching real 1v1 audio and video calls.
- Preserve the existing incoming-call and active-call production chain rather than introducing a second owner.
- Provide explicit permission and failure feedback so call entry never becomes a silent no-op.
- Add regression coverage proving the call buttons work from the active chat surface.
- Keep the repository cleaner by avoiding new duplicate RTC owner paths and by refusing to expand dead code usage.

## 5. Non-Goals

- This phase does not implement group multi-party room creation.
- This phase does not add a fake group-call picker that pretends to be backed by real multi-party call support.
- This phase does not switch production ownership from the current `VideoCallService` chain to the dormant bootstrap/LiveKit path.
- This phase does not redesign the backend call schema.
- This phase does not broaden the scope into a full call-history navigation project, although existing history recording must remain correct.

## 6. Authoritative Architecture Decision

The production owner for this phase remains the current 1v1 service chain:

- `ChatPageShell` owns user-visible call entry
- `WKPermissions` owns permission requests
- `VideoCallPage` owns the active in-call page
- `VideoCallService` owns outgoing, incoming, media, signal, and hangup behavior
- `CallCoordinator` owns incoming invite presentation and foreground recovery

The dormant bootstrap stack stays out of production ownership in this phase.

This decision is deliberate:

- it closes the highest-value product gap with the least false progress
- it avoids splitting call responsibility across two active paths
- it preserves the option to migrate to the bootstrap/LiveKit stack later through a separate spec and plan

`rtc_manager.dart` is not part of the authoritative path and must not receive new feature work.

## 7. Product Behavior Design

### 7.1 Visibility Rules

Call actions remain visible only for supported personal chats:

- show for personal channels
- hide for system account and file-helper special chats
- keep current hidden behavior for group channels in this phase

This preserves the already-audited active shell behavior and avoids lying about unsupported group call parity.

### 7.2 Audio Call Entry

When the user taps the voice-call icon in a supported personal chat:

- request microphone permission through `WKPermissions.requestMicrophone()`
- if permission is granted, navigate to `VideoCallPage` with `CallType.audio`
- the page then uses the existing `VideoCallService.startCall()` path

### 7.3 Video Call Entry

When the user taps the video-call icon in a supported personal chat:

- request camera and microphone permission through `WKPermissions.requestCameraAndMicrophone()`
- if permission is granted, navigate to `VideoCallPage` with `CallType.video`
- the page then uses the existing `VideoCallService.startCall()` path

### 7.4 Duplicate Call Guard

Before opening a new outgoing call page, the chat header must check the current call runtime state.

If `VideoCallService` already has:

- an active room
- or pending setup in progress

then the chat page must not open a second outgoing flow. It must instead show a clear user-facing message indicating that a call is already in progress.

### 7.5 Permission Failure Behavior

Permission denial must produce explicit feedback.

Rules:

- if microphone permission is denied for audio call, show a message explaining that microphone permission is required
- if camera or microphone permission is denied for video call, show a message explaining that both permissions are required
- if the denial is permanent, the text should explicitly direct the user to system settings

This phase uses lightweight in-app feedback rather than introducing a brand-new permission modal system.

### 7.6 Outgoing Failure Behavior

If the call page fails to create or establish the call:

- continue using the existing `VideoCallPage` error return and `SnackBar` behavior
- do not swallow errors in the chat header
- do not leave the service in a false active state

## 8. Detailed Data and Navigation Flow

### 8.1 Outgoing Audio or Video

The intended flow is:

1. User opens an active personal chat.
2. User taps the audio or video icon in `ChatPageShell`.
3. `ChatPageShell` checks runtime state and requests the required permission set.
4. If allowed, `ChatPageShell` pushes `VideoCallPage`.
5. `VideoCallPage.initState()` triggers `_startCall()`.
6. `VideoCallService.startCall()` creates the room through `CallApi.createRoom()`, establishes media/signaling, and updates `CallStore`.
7. Existing coordinator/history/runtime behavior continues unchanged.

### 8.2 Incoming Call

Incoming behavior remains on the existing path:

1. IM realtime frame reaches `ImService`.
2. `ImService` forwards the session frame to `CallCoordinator`.
3. `CallCoordinator` maps and applies the call event.
4. In foreground, the incoming overlay appears.
5. Accept opens `VideoCallPage` in incoming mode.
6. `VideoCallPage` uses `VideoCallService.acceptIncomingCall()`.

This path already exists and is preserved, not redesigned.

## 9. Error Handling and Edge Cases

The phase must explicitly protect these cases:

- tapping audio/video repeatedly should not create stacked outgoing pages
- denied permission must stop the flow before navigation
- disposed chat page must not try to show feedback after unmount
- existing cleanup on page dispose must continue to release a call when appropriate
- incoming call handling must remain unaffected by the new outgoing entry logic

The phase must not introduce:

- a second active RTC owner
- hidden fallbacks to unwired LiveKit/bootstrap components
- group-call entry affordances that imply unsupported functionality

## 10. Testing Strategy

Implementation must follow TDD and add focused regression coverage around the active chat entry point.

Required coverage:

- personal chat shows the voice and video call actions
- unsupported chats continue to hide them
- tapping audio entry requests microphone permission and opens the audio call page only when granted
- tapping video entry requests camera and microphone permission and opens the video call page only when granted
- denied permission keeps the user on the chat page and shows feedback
- active-call guard prevents duplicate outgoing call entry

Preferred test locations:

- a dedicated focused widget test under `test/modules/chat/` for call-entry behavior
- existing `test/modules/video_call/` tests remain for lower-level call runtime behavior

The phase should avoid hiding new call-entry coverage inside unrelated broad chat tests if a focused test file is cleaner.

## 11. Future Multi-Party Call Preconditions

Group multi-party parity requires a later dedicated design and plan because the current stack is not sufficient.

At minimum, that later phase requires:

- backend schema changes beyond `caller_uid/callee_uid`
- room and signal contracts that model multiple participants
- Flutter state machine changes beyond single `peerUid/peerName`
- a real group-call UI model rather than a single remote renderer page
- confirmation of how the Android endpoint extension actually maps onto the current server/runtime architecture

Until those preconditions are met, group-call parity must remain explicitly incomplete.

## 12. Risks and Mitigations

### 12.1 Risk: False Progress Through UI Copying

Adding a group-call picker now would make the app appear closer to parity than it really is.

Mitigation:

- keep this phase restricted to 1v1 closure
- document group multi-party parity as blocked by real runtime contracts

### 12.2 Risk: Reactivating Duplicate RTC Owners

Trying to partly wire the dormant bootstrap stack during this phase would create two competing production chains.

Mitigation:

- keep all work on the current production `VideoCallService` path
- defer bootstrap-stack activation to a later dedicated migration phase

### 12.3 Risk: Silent Permission Failure

If the header only requests permission and returns on failure, users will interpret the feature as broken.

Mitigation:

- require explicit feedback for all denial paths

## 13. Final Design Decision

The approved design for this phase is:

`Close the active Flutter chat-page 1v1 call entry gap by wiring the existing personal-chat audio and video buttons into the current production call chain, with explicit permission gating, duplicate-call protection, and focused regression coverage; defer all group multi-party parity work until real backend and runtime contracts exist.`

## 14. Immediate Next Step

After user review of this spec, the next step is to invoke `superpowers:writing-plans` and create a detailed implementation plan for this focused 1v1 call-entry closure phase.
