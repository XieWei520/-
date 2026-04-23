# IM Autopilot Execution Plan

> This is the sprint-level execution layer under `2026-04-11-im-native-parity-beyond-master-plan.md`. Use the master plan for final parity/superiority gates and use this file for implementation order inside the Flutter client.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the Flutter IM trunk around one authoritative realtime/session/timeline path, then close reliability and product-parity gaps in priority order, and only after that push into performance, UX, advanced capabilities, and delivery automation.

**Architecture:** The execution order follows one rule: the realtime trunk must become authoritative before feature expansion. The trunk is defined by four files and their immediate collaborators: `IMService` owns orchestration, `SessionRuntime` owns session supervision, `ConversationNotifier` owns conversation/timeline bridge decisions, and `ChatViewportController` owns render-side incremental reconciliation. Every later sprint attaches to this backbone instead of introducing new parallel paths.

**Tech Stack:** Flutter, Riverpod, WKIM Flutter SDK, sqflite, Dio, web_socket_channel, flutter_test, integration_test

---

## Preflight Facts

- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` is currently **not a git repository**. This means the planned progressive commits cannot be executed unless:
  - you provide the actual repo root, or
  - we initialize git before implementation.
- A partial Sprint 1 preparation has already happened in the current workspace:
  - `lib/realtime/session/session_runtime.dart`
  - `test/realtime/session/session_runtime_test.dart`
- The targeted runtime test file is already green locally:
  - `flutter test test/realtime/session/session_runtime_test.dart`

## Authoritative Core File Map

### Phase 0-1 trunk
- `lib/realtime/session/session_runtime.dart`
  - Session supervision, reconnect scheduling, degradation state, resume URI.
- `lib/realtime/session/session_event_gateway.dart`
  - Socket open/close, frame decoding, ack persistence boundary.
- `lib/service/im/im_service.dart`
  - WKIM lifecycle, session runtime lifecycle, command fan-out, device invalidation.
- `lib/data/providers/conversation_provider.dart`
  - Conversation list loading, message list merge/refresh, viewport bridge.
- `lib/modules/chat/chat_viewport_controller.dart`
  - Render-side incremental upsert/refresh/indexing for chat timeline.
- `lib/net/ws_manager.dart`
  - Legacy websocket stub; must be explicitly quarantined.
- `lib/wukong_base/net/ws_manager.dart`
  - Legacy websocket stub exported by base layer; must be explicitly quarantined.

### Phase 2-3 stability parity
- `lib/modules/conversation/conversation_activity_registry.dart`
  - Incoming typing/calling activity state.
- `lib/service/api/message_api.dart`
  - Typing send, read receipt calls, message-level remote state.
- `lib/modules/chat/chat_composer_controller.dart`
  - Outgoing typing trigger and local composer behavior.
- `lib/modules/chat/conversation_read_controller.dart`
  - Read batching and read edge transitions.
- `lib/modules/auth/application/device_session_controller.dart`
  - Device session management UX state.
- `lib/realtime/device/device_identity_service.dart`
  - Device bind version and session binding authority.
- `lib/service/api/group_api.dart`
  - Group contract boundary and server parity normalization.
- `lib/modules/group/group_controller.dart`
  - Group detail/member/setting surface.

### Phase 4-5 performance and UX
- `lib/modules/chat/widgets/chat_message_viewport.dart`
  - Scroll container, rebuild hotspots, pagination hooks.
- `lib/modules/chat/widgets/chat_message_list_item.dart`
  - Per-item rendering cost and identity stability.
- `lib/modules/chat/chat_message_mapper.dart`
  - Model mapping cost and cacheability.
- `lib/modules/chat/chat_voice_playback_controller.dart`
  - Voice playback interaction timing and state transitions.
- `lib/modules/chat/widgets/chat_voice_press_hold_button.dart`
  - Press/hold/cancel gesture behavior.

### Phase 6-7 advanced and infra
- `lib/service/api/crypto_api.dart`
  - E2EE transport and key-exchange API boundary.
- `lib/service/api/robot_api.dart`
  - Bot capability boundary.
- `test/realtime/session/...`
- `test/service/im/...`
- `test/modules/chat/...`
- `test/service/api/...`
  - Regression suite expansion.
- `.github/workflows/flutter.yml` or equivalent CI config
  - Delivery automation once repository infrastructure is available.

## Global Execution Rules

- Every sprint follows `RED -> GREEN -> REFACTOR -> targeted verification -> phase report`.
- No new page-first development before Phase 0-1 trunk is stable.
- No E2EE or bot work before Phase 6.
- Phase 7 quality work begins during Phase 2, not at the end.
- No new realtime path may bypass `IMService + SessionRuntime`.
- No new timeline path may bypass `ConversationNotifier + ChatViewportController`.

## Sprint 0: Preflight and Trunk Freeze

**Objective:** Freeze parallel transport paths, establish a safe baseline, and make the Phase 0 execution environment deterministic.

**Primary files:**
- `lib/net/ws_manager.dart`
- `lib/wukong_base/net/ws_manager.dart`
- `lib/wukong_base/wukong_base.dart`
- `test/service/im/im_service_test.dart`
- `test/realtime/session/session_runtime_test.dart`

**Tasks:**
- [ ] Confirm no production path depends on either legacy `WSManager`.
- [ ] Decide how to quarantine legacy websocket stubs:
  - preferred: annotate/export-guard them as deprecated compatibility shims,
  - fallback: leave file in place but ensure no active IM trunk imports depend on them.
- [ ] Capture Phase 0 baseline test commands and expected green subset.
- [ ] Record the git constraint and choose whether execution will proceed without progressive commits or after repo initialization.

**Verification:**
- `flutter test test/realtime/session/session_runtime_test.dart`
- `flutter test test/service/im/im_service_test.dart`

**Exit criteria:**
- The authoritative realtime trunk is unambiguous.
- Legacy websocket files are documented as non-authoritative.
- The user agrees on git handling before long autopilot execution.

## Sprint 1: SessionRuntime Supervisor Hardening

**Objective:** Make `SessionRuntime` a supervised session runner instead of a passive socket wrapper.

**Primary files:**
- `lib/realtime/session/session_runtime.dart`
- `lib/realtime/session/session_event_gateway.dart`
- `test/realtime/session/session_runtime_test.dart`
- `test/realtime/session/session_event_gateway_test.dart`

**Tasks:**
- [ ] Lock resume inputs inside `SessionRuntime`:
  - resume URI template,
  - resume headers,
  - retry generation token,
  - retry attempt counter.
- [ ] Keep reconnect URI generation sourced from `gateway.lastAckedSeq`.
- [ ] Ensure `stop()` cancels all delayed recovery paths.
- [ ] Ensure stream error, socket close, and frame handler failure all converge into the same recovery path.
- [ ] Separate three states cleanly:
  - running,
  - degraded,
  - stopped by intent.
- [ ] Make gateway ack behavior testable and strictly offline in tests.

**Verification:**
- `flutter test test/realtime/session/session_runtime_test.dart`
- `flutter test test/realtime/session/session_event_gateway_test.dart`

**Exit criteria:**
- Runtime degradation is observable.
- Runtime recovery is deterministic.
- Runtime tests are isolated from real network calls.

## Sprint 2: IMService Lifecycle Convergence

**Objective:** Make `IMService` the single orchestration authority for SDK connection, session runtime state, and device invalidation.

**Primary files:**
- `lib/service/im/im_service.dart`
- `test/service/im/im_service_test.dart`
- `test/realtime/session/session_runtime_test.dart`

**Tasks:**
- [ ] Introduce an explicit runtime-health model inside `IMServiceState`.
  - minimum shape: runtime running, runtime degraded, runtime error source.
- [ ] Align init reuse gating with both WKIM connection state and runtime health.
- [ ] Ensure `_startSessionRuntime()` does not silently skip needed restarts after degradation.
- [ ] Ensure `disconnect()` and device invalidation drive the same cleanup sequence:
  - complete init completer,
  - stop runtime,
  - disconnect SDK,
  - clear cached device-session identity when required.
- [ ] Ensure command handling remains side-effect safe while IM is reconnecting.
- [ ] Add tests for:
  - degraded runtime cannot be reused as healthy,
  - device invalidation clears init cache,
  - reconnect path does not leave stale `isInitialized` state behind.

**Verification:**
- `flutter test test/service/im/im_service_test.dart`
- `flutter test test/realtime/session/session_runtime_test.dart`

**Exit criteria:**
- `IMService` becomes the single authority for “can this IM session be reused?”
- Runtime failures no longer leave half-initialized service state behind.

## Sprint 3: Conversation Timeline Bridge Stabilization

**Objective:** Stop whole-list churn in the conversation/message provider layer and make refresh decisions deterministic.

**Primary files:**
- `lib/data/providers/conversation_provider.dart`
- `test/data/providers/conversation_provider_test.dart`
- `test/data/providers/conversation_provider_search_anchor_test.dart`

**Tasks:**
- [ ] Audit `ConversationNotifier.refresh()` and `_loadConversations()` for full-list replacement behavior.
- [ ] Keep `MessageListNotifier` as the only message-list source for chat timeline consumers.
- [ ] Harden merge rules for:
  - pending -> delivered replacement,
  - duplicate packet suppression,
  - delete/refresh coexistence,
  - out-of-order local refresh.
- [ ] Make `loadMessages()` vs `loadMore()` vs SDK push/refresh follow explicit replace/merge rules.
- [ ] Add regression tests for:
  - prepend-only incoming packets,
  - same-identity refresh,
  - local pending replacement after remote ack,
  - duplicate deleted refresh packet suppression.

**Verification:**
- `flutter test test/data/providers/conversation_provider_test.dart`
- `flutter test test/data/providers/conversation_provider_search_anchor_test.dart`

**Exit criteria:**
- Timeline data-source decisions are deterministic and documented.
- Provider-level regression cases cover the main non-destructive update paths.

## Sprint 4: ChatViewport Incremental Rendering Backbone

**Objective:** Make `ChatViewportController` capable of stable incremental upsert/refresh without forcing full rebuilds.

**Primary files:**
- `lib/modules/chat/chat_viewport_controller.dart`
- `lib/data/providers/conversation_provider.dart`
- `test/modules/chat/chat_viewport_controller_test.dart`

**Tasks:**
- [ ] Preserve render identity through pending -> delivered transitions.
- [ ] Keep index lookups authoritative after refresh and prepend operations.
- [ ] Add explicit support boundaries for:
  - replace all,
  - prepend incoming,
  - single refresh,
  - append older-history pages.
- [ ] Ensure bridge decision logic in `conversation_provider.dart` never classifies mixed refresh/prepend as incremental when it is unsafe.
- [ ] Keep head-insert and tail-append code paths separate so later pagination work can land without reopening replace-all behavior.

**Verification:**
- `flutter test test/modules/chat/chat_viewport_controller_test.dart`
- `flutter test test/data/providers/conversation_provider_test.dart`

**Exit criteria:**
- Render-side incremental updates are correct.
- The trunk from session -> provider -> viewport is coherent enough to start parity work.

## Sprint 5: Typing Parity

**Objective:** Complete the full typing loop: send, receive, expire, and surface.

**Primary files:**
- `lib/modules/conversation/conversation_activity_registry.dart`
- `lib/service/api/message_api.dart`
- `lib/modules/chat/chat_composer_controller.dart`
- `lib/widgets/wk_conversation_item.dart`
- `test/modules/conversation/conversation_activity_registry_test.dart`
- `test/modules/chat/chat_composer_controller_test.dart`
- `test/widgets/wk_conversation_item_parity_test.dart`

**Tasks:**
- [ ] Audit current receive-side typing behavior and keep Android-parity labels authoritative.
- [ ] Add composer-side typing send throttling:
  - fire on first input transition,
  - suppress spam during continuous typing,
  - re-arm after idle timeout.
- [ ] Clear typing state on:
  - message send success,
  - page leave/dispose,
  - remote timeout expiry.
- [ ] Keep personal and group typing labels consistent with existing parity tests.

**Verification:**
- `flutter test test/modules/conversation/conversation_activity_registry_test.dart`
- `flutter test test/modules/chat/chat_composer_controller_test.dart`
- `flutter test test/widgets/wk_conversation_item_parity_test.dart`

**Exit criteria:**
- Typing is no longer receive-only decoration.
- Typing send/receive/expiry behave consistently.

## Sprint 6: Read Receipt and Read-State Convergence

**Objective:** Make local read state, server read API, and rendered receipt metadata converge on one path.

**Primary files:**
- `lib/data/providers/conversation_provider.dart`
- `lib/modules/chat/conversation_read_controller.dart`
- `lib/service/api/message_api.dart`
- `lib/modules/chat/chat_message_mapper.dart`
- `test/modules/chat/conversation_read_controller_test.dart`
- `test/data/providers/conversation_provider_test.dart`
- `test/modules/chat/chat_message_mapper_test.dart`

**Tasks:**
- [ ] Audit current `markConversationRead()` flow for local-first / remote-later semantics.
- [ ] Prevent duplicate remote read submissions for the same visible range.
- [ ] Ensure receipt-related `wkMsgExtra` updates become viewport refreshes instead of replace-all churn.
- [ ] Decide and document one receipt truth source:
  - local red-dot clearance,
  - message-level receipt metadata,
  - remote mark-as-read acknowledgment.
- [ ] Add regression tests for partial visible read windows and repeated read batches.

**Verification:**
- `flutter test test/modules/chat/conversation_read_controller_test.dart`
- `flutter test test/data/providers/conversation_provider_test.dart`
- `flutter test test/modules/chat/chat_viewport_controller_test.dart`

**Exit criteria:**
- Receipt updates are incremental and idempotent.
- Read-state no longer causes timeline instability.

## Sprint 7: Multi-Device Session and Invalidation Parity

**Objective:** Unify device session identity, invalidation, and management surfaces into one consistent model.

**Primary files:**
- `lib/realtime/device/device_identity_service.dart`
- `lib/realtime/device/device_store.dart`
- `lib/modules/auth/application/device_session_controller.dart`
- `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
- `lib/service/im/im_service.dart`
- `test/realtime/device/device_identity_service_test.dart`
- `test/modules/auth/auth_device_sessions_web_login_test.dart`
- `test/service/im/im_service_test.dart`

**Tasks:**
- [ ] Keep bind-version ordering authoritative when device session changes race.
- [ ] Ensure remote invalidation from session runtime clears persisted device session safely.
- [ ] Reconcile device-management UI actions with runtime teardown behavior.
- [ ] Ensure “quit all PC/Web” and “delete one device” do not leave stale local cache.
- [ ] Add regression tests for:
  - invalidated device session after init,
  - stale bind version ignored,
  - device list reload after destructive actions.

**Verification:**
- `flutter test test/realtime/device/device_identity_service_test.dart`
- `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
- `flutter test test/service/im/im_service_test.dart`

**Exit criteria:**
- Multi-device session semantics are trustworthy.
- Device invalidation no longer feels bolted on.

## Sprint 8: Group Contract Parity

**Objective:** Make the Flutter group domain speak one authoritative backend contract and stop depending on non-authoritative assumptions.

**Primary files:**
- `lib/service/api/group_api.dart`
- `lib/modules/group/group_controller.dart`
- `lib/data/models/group.dart`
- `test/service/api/group_api_test.dart`
- `test/wukong_uikit/group/group_detail_page_settings_test.dart`
- `test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
- `test/wukong_uikit/group/group_edit_pages_parity_test.dart`

**Tasks:**
- [ ] Audit all `GroupApi` endpoints still marked or behaving as non-authoritative.
- [ ] Normalize payload names that may vary between server shapes:
  - `uids`,
  - `members`,
  - `member_ids`,
  - group setting keys.
- [ ] Ensure `GroupDetailNotifier` reload strategy is minimal and does not refetch unrelated data.
- [ ] Verify owner transfer, manager toggle, invite mode, history visibility, mute/forbidden settings against one canonical contract.
- [ ] Add coverage for group-detail setting mutations that should update cached channel state.

**Verification:**
- `flutter test test/service/api/group_api_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_page_settings_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_slot_assembly_test.dart`

**Exit criteria:**
- Group behavior is server-contract-led, not guessed.
- Group setting changes do not drift from cached local channel state.

## Sprint 9: Reliability Deepening

**Objective:** Close the message-loss and reconnect edge cases that show up only under unstable network or duplicate delivery.

**Primary files:**
- `lib/realtime/session/session_runtime.dart`
- `lib/realtime/session/session_event_gateway.dart`
- `lib/service/im/im_service.dart`
- `lib/data/providers/conversation_provider.dart`
- `test/realtime/session/session_runtime_test.dart`
- `test/service/im/im_service_test.dart`

**Tasks:**
- [ ] Add reconnect classification rules:
  - stream done,
  - transient decode failure,
  - handler failure,
  - deliberate shutdown.
- [ ] Add resume/gap protection around `lastReceivedSeq` vs `lastAckedSeq`.
- [ ] Decide what happens when a frame is received but side effects fail before ack.
- [ ] Add an explicit outbox/resend-state regression slice for pending messages during reconnect.
- [ ] Create one targeted manual probe or integration harness for forced reconnect storms.

**Verification:**
- `flutter test test/realtime/session/session_runtime_test.dart`
- `flutter test test/service/im/im_service_test.dart`
- `flutter test test/tool/manual_phase3_runtime_probe_test.dart`

**Exit criteria:**
- Reconnect behavior is intentionally classified.
- Message-loss risk is materially reduced.

## Sprint 10: Performance Specialization

**Objective:** Remove avoidable UI-isolate pressure and long-list rebuild cost before polishing UI.

**Primary files:**
- `lib/modules/chat/chat_viewport_controller.dart`
- `lib/modules/chat/chat_message_mapper.dart`
- `lib/modules/chat/widgets/chat_message_viewport.dart`
- `lib/modules/chat/widgets/chat_message_list_item.dart`
- `lib/modules/chat/chat_media_action_service.dart`
- `test/modules/chat/chat_viewport_controller_test.dart`

**Tasks:**
- [ ] Measure current chat list hotspot classes:
  - full-list replace frequency,
  - mapper cost,
  - item rebuild frequency,
  - media decode churn.
- [ ] Introduce isolate offload only where profiling justifies it:
  - `ChatMessageMapper` batch mapping,
  - media metadata parsing before upload/render,
  - not for trivial list diffs.
- [ ] Tighten image/video cache usage and disposal behavior.
- [ ] Audit `ListView`/viewport keys and identity stability for frame drops.
- [ ] Keep all optimizations behind measurable before/after notes.

**Verification:**
- `flutter test test/modules/chat/chat_viewport_controller_test.dart`
- `flutter test test/modules/chat/message_bubble_experience_test.dart`
- profile run on real device or emulator for scroll traces

**Exit criteria:**
- Performance changes are evidence-driven.
- No speculative isolate work lands without measurement.

## Sprint 11: UI/UX Motion and Gesture Upgrade

**Objective:** Improve perceived quality only after correctness and performance are under control.

**Primary files:**
- `lib/modules/chat/widgets/chat_message_viewport.dart`
- `lib/modules/chat/widgets/chat_message_list_item.dart`
- `lib/modules/chat/widgets/chat_voice_press_hold_button.dart`
- `lib/modules/chat/widgets/chat_voice_record_overlay.dart`
- `lib/modules/conversation/conversation_list_page.dart`
- `test/modules/chat/chat_voice_record_overlay_test.dart`
- `test/modules/chat/chat_voice_message_bubble_test.dart`
- `test/modules/chat/message_bubble_experience_test.dart`
- `test/modules/conversation/conversation_list_refresh_controller_test.dart`

**Tasks:**
- [ ] Unify motion timing across conversation -> chat transitions.
- [ ] Improve press/hold/cancel gesture confidence for voice interactions.
- [ ] Tune message insertion and refresh animation so it feels faster than native without causing layout churn.
- [ ] Polish typing/calling micro-feedback where it helps situational awareness.
- [ ] Reserve any true “needs real device” checks for the final checkpoint of this sprint.

**Verification:**
- widget tests for affected surfaces
- manual run on device for gesture and scroll feel

**Exit criteria:**
- UX changes are layered on top of a stable trunk.
- Real-device-only checks are isolated to this sprint instead of blocking earlier work.

## Sprint 12: Advanced Capabilities Gate

**Objective:** Add only the minimum scaffolding for E2EE and bots once the core product is already stable.

**Primary files:**
- `lib/service/api/crypto_api.dart`
- `lib/service/api/robot_api.dart`
- `lib/modules/chat/chat_page.dart`
- `lib/modules/chat/chat_message_mapper.dart`
- `lib/data/models/wk_custom_content.dart`
- `test/service/api/crypto_api_test.dart`
- `test/service/api/robot_api_test.dart`

**Tasks:**
- [ ] First perform a feasibility and boundary audit:
  - where keys live,
  - which message types are encryptable,
  - what bot contracts already exist.
- [ ] Add capability scaffolding before UX:
  - no full page rollout before transport/storage boundaries are clear.
- [ ] Keep these features isolated from the core IM trunk.

**Verification:**
- targeted API and unit tests to be created only after boundary design is settled

**Exit criteria:**
- Advanced features do not destabilize the core product.

## Sprint 13: Quality Infrastructure and CI/CD

**Objective:** Turn the working code into a repeatable, testable delivery system.

**Primary files:**
- `test/realtime/session/...`
- `test/service/im/...`
- `test/modules/chat/...`
- `test/modules/conversation/...`
- `test/service/api/...`
- repo CI config once a git repo is available
- CI entrypoint scripts under `tool/` when needed

**Tasks:**
- [ ] Group tests by critical lanes:
  - realtime/session,
  - IM orchestration,
  - conversation/timeline,
  - parity widgets,
  - API contracts.
- [ ] Define the minimum blocking test matrix for pull requests and release builds.
- [ ] Add formatting/lint/test/build automation once repository infrastructure exists.
- [ ] Ensure long-running manual or probe tests are separated from the default fast lane.

**Verification:**
- fast lane: targeted unit/widget suite
- full lane: aggregated regression command set

**Exit criteria:**
- Delivery no longer depends on manual luck.
- Quality gates exist before late-stage feature pressure arrives.

## Execution Order and Checkpoints

### Mandatory order
1. Sprint 0
2. Sprint 1
3. Sprint 2
4. Sprint 3
5. Sprint 4
6. Sprint 5
7. Sprint 6
8. Sprint 7
9. Sprint 8
10. Sprint 9
11. Sprint 10
12. Sprint 11
13. Sprint 12
14. Sprint 13

### Formal phase gates
- Phase 0 done:
  - Sprint 0 + Sprint 1 green
- Phase 1 done:
  - Sprint 2 + Sprint 3 + Sprint 4 green
- Phase 2 done:
  - Sprint 5 green
- Phase 3 done:
  - Sprint 6 + Sprint 7 + Sprint 8 green
- Phase 4 done:
  - Sprint 9 + Sprint 10 green
- Phase 5 done:
  - Sprint 11 green
- Phase 6 done:
  - Sprint 12 green
- Phase 7 done:
  - Sprint 13 green

## Recommended Start Sequence

If you approve this plan, the first execution block will be:

1. Sprint 0
   - quarantine legacy websocket stubs
   - confirm git handling decision
2. Sprint 1
   - keep `SessionRuntime` recovery path green
   - extend targeted runtime coverage only where behavior changes
3. Sprint 2
   - introduce explicit runtime-health modeling in `IMService`

## Approval Notes

Before autopilot implementation starts, I need your approval on two operational points:

- Whether to proceed **without git commits** for now, or whether you want to first point me to the actual repo root / initialize git.
- Whether you want me to execute strictly **inline in this session** after approval, or whether you also want later subagent-style parallelization for non-overlapping sprints.
