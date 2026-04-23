# IM Autopilot Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the Flutter IM core trunk first, then close parity gaps, then push into performance and UX work without destabilizing messaging reliability.

**Architecture:** The plan treats the IM stack as three concentric layers: runtime orchestration, timeline/state management, and feature shells. We first harden the runtime and timeline so later typing, receipts, device sync, group contract, performance, and UX work all land on one stable backbone instead of on parallel legacy paths.

**Tech Stack:** Flutter, Riverpod, WKIM Flutter SDK, sqflite, web_socket_channel, cached_network_image, flutter_test, integration_test

---

## Sprint List

### Sprint 1: Phase 0 Runtime Guardrails
- [ ] Lock a single realtime trunk around `lib/service/im/im_service.dart`, `lib/realtime/session/session_runtime.dart`, and `lib/realtime/session/session_event_gateway.dart`.
- [ ] Add failing tests for runtime degradation, retry supervision, and stop/restart behavior.
- [ ] Refactor `SessionRuntime` so degradation is observable and recoverable.
- [ ] Make legacy websocket stubs clearly dead code and keep them out of active imports.
- [ ] Run targeted runtime and IM service tests.

### Sprint 2: Phase 1 Timeline Core
- [ ] Add failing tests for timeline incremental sync and non-destructive refresh paths.
- [ ] Refactor `lib/data/providers/conversation_provider.dart` to reduce whole-list rebuilds.
- [ ] Refactor `lib/modules/chat/chat_viewport_controller.dart` to support stable incremental upserts.
- [ ] Wire the viewport bridge so incoming vs refresh vs replace-all decisions stay deterministic.
- [ ] Run targeted provider and viewport tests.

### Sprint 3: Phase 1 IM Orchestration
- [ ] Add failing tests for IM init reuse, degraded session recovery, and device invalidation.
- [ ] Introduce a clearer runtime health model inside `IMService`.
- [ ] Unify session runtime lifecycle with WKIM connection lifecycle.
- [ ] Re-run IM service and session tests.

### Sprint 4: Phase 2 Typing / Receipt / Device / Group Contract
- [ ] Close typing send + receive + expiry loop.
- [ ] Add receipt settings and message-level receipt behavior parity.
- [ ] Collapse device session management into one path.
- [ ] Reconcile group API contract mismatches and deprecations.
- [ ] Add or update tests as each behavior lands.

### Sprint 5: Phase 3 Reliability
- [ ] Add outbox and resend-state regression coverage.
- [ ] Improve reconnect classification and backoff policy.
- [ ] Add ack/resume/gap protection around session recovery.
- [ ] Begin CI-oriented regression grouping from this sprint onward.

### Sprint 6: Phase 4 Performance
- [ ] Move hot timeline reconciliation off the UI isolate when measurement proves benefit.
- [ ] Unify image/video decode and cache policy.
- [ ] Profile message list performance before and after each change.

### Sprint 7: Phase 5 UX
- [ ] Unify motion tokens and message interaction feedback.
- [ ] Upgrade chat, media, and voice gestures for smoother product feel.

### Sprint 8: Phase 6 Advanced Capabilities
- [ ] Evaluate E2EE and bot work only after the core trunk and parity features are stable.

### Sprint 9: Phase 7 Delivery Infrastructure
- [ ] Expand automated test coverage, release checks, and CI/CD from the reliability stage into final delivery.
