# Realtime Event Core V2 Phase 1 Design

**Date:** 2026-04-02
**Scope:** Device identity, unified realtime event ingress, and call signaling rewrite
**Refactor Radius:** Breaking changes allowed across Flutter client, API layer, IM/session runtime, and backend services
**Release Policy:** Forced client upgrade with coordinated client/server release window
**Primary KPI:** Real-time latency first, with deterministic recovery and lower polling dependency

## 1. Problem Statement

The current application still routes critical realtime behaviors through scattered polling loops, page-local listeners, and duplicated device identity code. This creates latency spikes, race conditions, and operational blind spots that are incompatible with a commercial-grade IM stack.

The most visible symptoms are already present in the codebase and the production environment:

- call invitation discovery depends on fixed-interval polling in [call_coordinator.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\call_coordinator.dart)
- call signaling still depends on timer-based polling in [video_call_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\video_call_service.dart)
- device identity is generated and carried in multiple places, including [auth_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\auth_api.dart), [login_bridge_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\login_bridge_api.dart), and [im_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart)
- production logs on `ssh root@103.207.68.33` still show repeated `"device_info_missing" (`设备信息不存在`) errors and dense `/v1/extra/call/pending` traffic

This phase introduces a new realtime core that treats polling as a temporary fallback rather than the primary transport. It also establishes one authoritative device identity flow so the client and server stop disagreeing about which device is actually online.

## 2. Goals

- Replace call invitation and call signal polling as the primary realtime path.
- Introduce one unified event ingress for user-scoped realtime state.
- Make device identity authoritative, stable, and shared across login, bridge login, and IM initialization.
- Keep client state updates ordered, replayable, and idempotent.
- Allow coordinated client/server release with a forced upgrade and no long-lived legacy protocol support.
- Preserve direct production diagnostics using `ssh root@103.207.68.33` and container/log inspection as part of acceptance.

## 3. Non-Goals

- This phase does not yet redesign the full chat surface kernel.
- This phase does not yet rebuild the media pipeline for avatars, images, and video thumbnails.
- This phase does not attempt to preserve backward compatibility with old client builds.
- This phase does not optimize every screen; it focuses on the realtime spine that future optimizations will hang from.

## 4. Approved Direction

The approved direction is a breaking `Realtime Event Core V2` rollout with forced client upgrade and simultaneous client/server release control.

Phase 1 includes three subprojects only:

1. `Device Identity V2`
2. `Session Event Gateway V2`
3. `Call Signaling V2`

The remaining work for `Chat Surface Kernel V2`, `Media Pipeline V2`, and `Perf Observatory` will be specified in later documents after Phase 1 lands cleanly.

## 5. Current Hotspots

### 5.1 Device Identity Drift

Device identity creation is duplicated and weakly coordinated:

- [auth_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\auth_api.dart) creates and persists default device payloads
- [login_bridge_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\login_bridge_api.dart) creates a similar but separate device info flow
- [im_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart) relies on the stored device id during IM setup

This architecture makes it possible for the client to think it has one valid device identity while the backend device table disagrees. The remote `"device_info_missing" (`设备信息不存在`) errors strongly suggest this is already happening in production.

### 5.2 Polling as the Primary Realtime Mechanism

The app still uses fixed timers for critical call flows:

- [call_coordinator.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\call_coordinator.dart) polls pending calls every 4 seconds
- [video_call_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\video_call_service.dart) polls signals every 2 seconds

This causes:

- avoidable latency for incoming call presentation
- background wakeups and battery cost
- unnecessary backend traffic
- more complicated client state reconciliation

### 5.3 Realtime State Has No Unified Ingress

Conversation, call, presence, and device state still arrive through different ad hoc paths. That makes it harder to guarantee ordering, dedupe stale results, or replay state after reconnect.

## 6. Target Architecture

Phase 1 creates a strict split between transport/runtime, domain stores, and UI surfaces.

### 6.1 `DeviceIdentityAuthority`

Responsibilities:

- generate and persist one stable `device_id`
- manage install-scoped metadata
- request and refresh backend-issued `device_session_id`
- expose a single device identity contract to login and IM bootstrap

Rules:

- no other module may generate its own device identity
- all realtime subscriptions and authenticated IM bootstrap require a valid bound device session

### 6.2 `SessionEventGateway`

Responsibilities:

- open the primary user-scoped realtime event stream
- track `last_acked_seq`
- ACK processed events
- replay missed events after reconnect
- expose normalized event frames to domain stores

Rules:

- this is the main realtime ingress
- REST polling is fallback only and must not remain the default path
- ordering is defined by server-issued sequence, not local arrival timing

### 6.3 Domain Stores

Phase 1 introduces or prepares these stores:

- `DeviceStore`
- `CallStore`
- `ConversationStore` integration points only

Rules:

- each store is the single structural writer for its own branch
- stores must merge events idempotently
- UI consumes derived state only

### 6.4 `CallSignalingV2`

Responsibilities:

- consume `call.invite`, `call.signal`, and `call.state` events
- drive the local call state machine
- send ACKed signaling actions back to the server
- fall back to short-lived polling only when the event stream is degraded

Rules:

- no page or overlay may own the authoritative call lifecycle
- one user may have at most one active call session in the client runtime

## 7. Data Model

### 7.1 Device Identity

The client runtime maintains:

- `device_id`: stable install-scoped device id
- `device_install_id`: installation instance marker used for migration and diagnostics
- `device_session_id`: backend-issued session identity for the bound device
- `user_id`
- `device_flag`
- `bind_version`

Key semantics:

- `device_id` survives normal app restarts
- `device_session_id` is authoritative for authenticated realtime behavior
- `bind_version` prevents old bind acknowledgements from overwriting newer state

### 7.2 Session Events

Every event from the gateway must include:

- `event_id`
- `user_seq`
- `server_ts`
- `kind`
- `aggregate_id`
- `payload`

Examples of `kind` values:

- `message.upsert`
- `message.read`
- `conversation.delta`
- `call.invite`
- `call.signal`
- `call.state`
- `device.bound`
- `device.invalidated`
- `session.kicked`
- `presence.delta`

### 7.3 Call Session State

The client call state machine is:

- `idle`
- `invited`
- `ringing`
- `connecting`
- `connected`
- `reconnecting`
- `ending`
- `ended`
- `failed`

Transitions are driven only by:

- gateway events
- explicit local call actions
- RTC layer callbacks translated through `CallStore`

## 8. Client-Side Module Boundaries

### 8.1 New Modules

- `lib/realtime/device/device_identity_service.dart`
- `lib/realtime/device/device_store.dart`
- `lib/realtime/session/session_event_gateway.dart`
- `lib/realtime/session/session_event_frame.dart`
- `lib/realtime/session/session_runtime.dart`
- `lib/realtime/call/call_store.dart`
- `lib/realtime/call/call_state_machine.dart`
- `lib/realtime/call/call_event_mapper.dart`

### 8.2 Existing Files To Refactor

- [auth_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\auth_api.dart)
- [login_bridge_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\login_bridge_api.dart)
- [im_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart)
- [call_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\call_api.dart)
- [call_coordinator.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\call_coordinator.dart)
- [video_call_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\video_call_service.dart)

### 8.3 Boundary Rules

- API classes may perform IO only; they do not own state machines
- stores may own merge logic and state transitions; they do not perform widget work
- widgets and overlays may render derived state and dispatch intents only
- `SessionEventGateway` may not become a god object; it transports frames, it does not implement business logic

## 9. Server-Side Changes

### 9.1 Device Identity Endpoints

The backend must expose a single authoritative device bind/update flow. Exact URI names may change during implementation, but the protocol requirements are fixed:

- bind or refresh a device session from login/bootstrap inputs
- invalidate stale or conflicting device sessions
- return a stable `device_session_id`
- emit `device.bound` and `device.invalidated` events into the session event stream

### 9.2 Session Event Gateway

The backend must expose one user-scoped realtime event stream with:

- ordered `user_seq`
- per-user replay from sequence
- ACK support
- event fanout for conversation, call, presence, and device events

Phase 1 implements the session event gateway as a dedicated ordered WebSocket session channel with replay and ACK semantics. REST polling remains fallback only and is not an acceptable primary transport.

### 9.3 Call Signaling V2

The backend must:

- emit `call.invite` events instead of waiting for client pending-call polling
- emit ordered `call.signal` and `call.state` events into the gateway
- accept explicit call action requests from the client and respond with canonical room/session state
- expire dead rooms and surface deterministic terminal states

## 10. Recovery and Reliability Rules

### 10.1 Device Recovery

- if `device_session_id` is invalidated, the runtime must halt realtime subscription and rebind before resuming
- the client must not continue optimistic IM bootstrap with stale device identity

### 10.2 Session Recovery

- reconnect uses `last_acked_seq` as the only replay anchor
- replayed events must be safe to process multiple times
- stale async completions must not overwrite newer store state

### 10.3 Call Recovery

- transient stream interruption may move a call to `reconnecting`
- explicit remote end moves to `ended`
- unrecoverable RTC or protocol failures move to `failed`
- local UI may show fallback affordances, but store state remains authoritative

## 11. Polling Exit Strategy

Polling is no longer the primary realtime path.

Phase 1 rules:

- `/v1/extra/call/pending` is removed from the main incoming-call path
- signal polling is removed from the main signaling path
- a temporary fallback poller may exist behind runtime degradation checks only
- any fallback poller must be visibility-aware, short-lived, and explicitly observable
- fallback polling activates only after the session event gateway has remained degraded or disconnected for at least 10 seconds
- fallback polling uses bounded backoff `2s -> 4s -> 8s -> 15s` and must stop immediately after gateway recovery

## 12. Testing Strategy

### 12.1 Unit Tests

- device identity generation and persistence
- bind version conflict handling
- session event dedupe and replay merge
- ACK cursor updates
- call state machine transitions
- invalidation handling for stale device sessions

### 12.2 Widget and Runtime Tests

- incoming call presentation triggered by push event rather than pending-call polling
- reconnect resumes from sequence without duplicated call or conversation state
- invalid device session stops realtime flow and triggers rebind

### 12.3 Integration Tests

- coordinated login -> device bind -> IM bootstrap
- call invite -> accept -> signal exchange -> end
- reconnect during active call
- forced logout or session kick

### 12.4 Remote Verification

Every major milestone must include server correlation through:

- `ssh root@103.207.68.33`
- `docker ps`
- `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`
- `docker logs --tail 200 fullstack-tangsengdaodaoserver-1`

The new implementation must make it straightforward to correlate:

- device bind success/failure
- event stream subscription and replay
- call invite delivery
- call signal ordering

## 13. Acceptance Criteria

### 13.1 Architecture Acceptance

- client device identity is owned by one authority, not three separate code paths
- polling is no longer the primary realtime transport for call invite or signaling
- session events enter through one ordered gateway
- UI surfaces consume derived store state rather than stitching transport callbacks themselves

### 13.2 Realtime Acceptance

- call invite latency no longer depends on a 4-second polling window
- call signaling no longer depends on a 2-second signal poll loop
- reconnect resumes ordered event processing from sequence instead of coarse full refresh

### 13.3 Stability Acceptance

- `"device_info_missing" (`设备信息不存在`) is eliminated for valid upgraded clients
- stale events do not overwrite newer store state
- one active call session is enforced locally
- forced upgrade path lands on the V2 protocol only

### 13.4 Operational Acceptance

- production diagnostics remain accessible via `ssh root@103.207.68.33`
- event, device, and call state transitions can be correlated with backend logs and container state

## 14. Directly Executable Task Checklist

This checklist is intentionally execution-oriented and includes the required remote-debug entry.

1. Extract all install-scoped device identity generation into `DeviceIdentityAuthority`, and remove duplicate device creation from [auth_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\auth_api.dart) and [login_bridge_api.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\login_bridge_api.dart).
2. Introduce `DeviceStore` and persist `device_id`, `device_install_id`, `device_session_id`, and `bind_version` behind one read/write contract.
3. Refactor [im_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart) so IM bootstrap blocks on authoritative device bind instead of optimistic stale identity reuse.
4. Add `SessionEventGateway`, `SessionRuntime`, and normalized event-frame mapping under `lib/realtime/session/`.
5. Implement the ordered WebSocket session channel with replay-from-sequence and ACK cursor advancement.
6. Route call invite, signal, and call-state updates through `CallStore` and `CallSignalingV2` instead of page-local timers.
7. Remove `/v1/extra/call/pending` from the primary incoming-call path and demote polling to degradation-only fallback behavior.
8. Replace the 2-second signal poll loop in [video_call_service.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\video_call\video_call_service.dart) with gateway-driven signaling and explicit degradation fallback.
9. Add idempotent merge, stale-result suppression, and one-active-call enforcement in the new call state machine.
10. Add unit, runtime, and integration tests for device bind, event replay, reconnect, call invite, and call termination flows.
11. Run local verification for `dart analyze`, targeted tests, and reconnect/call-path regression coverage.
12. Log into the cloud server with `ssh root@103.207.68.33` for remote debugging and environment correlation.
13. Run `docker ps` to confirm the expected containers are healthy before exercising the V2 rollout path.
14. Inspect `/data/fullstack/wukongimdata/logs/error.log` and `docker logs --tail 200 fullstack-tangsengdaodaoserver-1` to verify whether `device_info_missing` and `/v1/extra/call/pending` traffic have been eliminated.
15. Correlate backend event-stream logs with client device bind, replay, ACK, and call state transitions during verification.

## 15. Risks and Mitigations

### Risk: Event gateway turns into a god object

Mitigation:

- keep transport and framing in the gateway
- move all domain merge and state machine logic into dedicated stores

### Risk: Forced upgrade cutover creates a short outage window

Mitigation:

- coordinate client and server release
- verify new gateway and device bind flow in staging first
- keep a short-lived, explicit rollback plan for the release window only

### Risk: RTC layer and signaling layer drift apart

Mitigation:

- model call lifecycle explicitly in `CallStore`
- treat RTC callbacks as inputs into the store, not the state source

### Risk: Device identity migration breaks existing installs

Mitigation:

- preserve existing stored `device_id` where valid
- introduce `device_install_id` and bind version checks
- log migration outcomes and invalidations with enough context to debug remotely

## 16. Execution Recommendation

The next implementation plan should target only Phase 1 and keep the task sequence strict:

1. `Device Identity V2`
2. `Session Event Gateway V2`
3. `Call Signaling V2`

`Chat Surface Kernel V2`, `Media Pipeline V2`, and `Perf Observatory` should be planned separately after the realtime core is stable.
