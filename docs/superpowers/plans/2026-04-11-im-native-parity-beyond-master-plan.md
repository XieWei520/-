# IM Native Parity and Beyond Master Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Flutter IM client and production backend that first reaches verified parity with the native Android reference, then surpasses it in reliability, performance, UX quality, operational robustness, and backend scalability with measurable evidence.

**Architecture:** This plan runs as three synchronized workstreams instead of one linear client-only plan. Workstream A establishes truth and baselines from the native Android app and current backend deployment. Workstream B stabilizes and expands the Flutter IM trunk until native feature parity is verified. Workstream C upgrades the backend from “working deployment” to “measurably superior service architecture” with repeatable deployment, observability, recovery, and scale validation.

**Tech Stack:** Flutter, Riverpod, WKIM Flutter SDK, TangSengDaoDao Android reference, WuKongIM Android SDK, TangSengDaoDaoServer (Go), WuKongIM (Go), MySQL, Redis, MinIO, Nginx, LiveKit, Coturn, Docker Compose, Prometheus, Loki, flutter_test, integration_test, Python smoke/perf scripts

---

## Program Truth Sources

### Flutter target
- `wukong_im_app/lib/service/im/im_service.dart`
- `wukong_im_app/lib/realtime/session/session_runtime.dart`
- `wukong_im_app/lib/data/providers/conversation_provider.dart`
- `wukong_im_app/lib/modules/chat/chat_viewport_controller.dart`
- `wukong_im_app/docs/superpowers/plans/2026-04-11-im-autopilot-execution-plan.md`

### Native Android reference
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/app`
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/wkbase`
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit`
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/wklogin`
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/wkpush`
- `TangSengDaoDao/TangSengDaoDaoAndroid-master/wkscan`
- `TangSengDaoDao/WuKongIMAndroidSDK-master/wkim`

### Backend reference and deployment
- `TangSengDaoDao/TangSengDaoDaoServer-main/modules`
- `TangSengDaoDao/TangSengDaoDaoServer-main/configs/tsdd.yaml`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/docker-compose.yaml`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/scripts/smoke_test.py`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/scripts/perf_probe.py`
- `TangSengDaoDao/WuKongIM-main/internal`
- `TangSengDaoDao/WuKongIM-main/config/wk.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/gateway/docker-compose.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/cluster/docker-compose.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/monitor/docker-compose.yaml`

## What “Complete” Means

This program is complete only when all three statements are true:

1. **Native parity is verified**
   - The Flutter app covers all release-critical Android IM behavior, not just the happy path.
2. **Flutter is measurably better than native**
   - Performance, interaction quality, and architecture are better on the same device class and test flows.
3. **Backend is measurably better than the current baseline**
   - Deployment, latency, observability, recovery, and scale posture are stronger than the current deployed state and stronger than the legacy “single working box” standard.

If any one of these is unproven, the program is not allowed to claim “fully aligned” or “beyond native”.

## Evidence Artifacts Required Before Final Sign-Off

The implementation effort must produce these documents before final release certification:

- `docs/superpowers/reports/im-native-feature-matrix.md`
- `docs/superpowers/reports/im-native-benchmark-baseline.md`
- `docs/superpowers/reports/im-client-performance-report.md`
- `docs/superpowers/reports/im-ux-validation-report.md`
- `docs/superpowers/reports/im-backend-architecture-report.md`
- `docs/superpowers/reports/im-backend-load-and-recovery-report.md`
- `docs/superpowers/reports/im-release-certification.md`

## Hard Acceptance Gates

### Gate 1: Native Feature Parity

The Flutter app may only claim parity when all of the following are true:

- `P0` and `P1` rows in `im-native-feature-matrix.md` are `100%` implemented and verified.
- `P2` parity coverage is at least `95%`.
- Open defects at release are:
  - `P0 = 0`
  - `P1 = 0`
  - accepted `P2 <= 5`
- Every row in the matrix contains:
  - Android reference entry point
  - Flutter target entry point
  - backend dependency
  - verification method
  - status

The parity matrix must include at minimum:

- auth and bootstrap
- single chat
- group chat
- conversation list
- unread state
- read receipts
- typing
- device session management
- group settings and member operations
- search
- message resend/revoke/delete/forward/reply/reaction
- media/file upload and preview
- notifications and push handoff
- voice/video call entry
- weak-network reconnect behavior

### Gate 2: IM Trunk Reliability

The trunk may only be called stable when all of the following are true:

- `IMService`, `SessionRuntime`, `ConversationNotifier`, and `ChatViewportController` are the only authoritative realtime/timeline path.
- No active product flow depends on legacy websocket stubs.
- Automated reconnect and recovery tests are green.
- A controlled chaos run of `1000` message events across reconnect, refresh, and duplicate-packet scenarios produces:
  - `0` user-visible message loss
  - `0` user-visible duplicate rows
  - `0` stuck pending messages after final sync
- Device invalidation, receipt refresh, typing expiry, and group state refresh all pass their regression suites.

### Gate 3: Flutter Performance Beyond Native

The Flutter client may only claim “beyond native” when both relative and absolute targets are met on at least:

- one flagship Android device
- one mid-tier Android device

#### Relative targets against native Android baseline

- chat timeline open time is at least `15%` faster than native on the same dataset size
- conversation list jank ratio is at least `30%` lower than native
- local send-to-render latency is at least `15%` lower than native
- peak memory during media-heavy chat browsing is at least `10%` lower than native

#### Absolute release floors

- conversation list average FPS on mid-tier device: `>= 58`
- chat timeline average FPS on mid-tier device with long history: `>= 58`
- visible jank frame ratio in tested chat flows: `<= 2%`
- warm open of a `5000`-message chat: `<= 600ms`
- cold open of a `5000`-message chat: `<= 1500ms`
- local send-to-render latency for text: `<= 80ms`
- peak resident memory during 30-image browse flow on mid-tier device: `<= 350MB`

### Gate 4: UX Beyond Native

The Flutter client may only claim UX superiority when all of the following are true:

- `30` scripted manual flows pass with:
  - `0` P0 defects
  - `0` P1 defects
  - `<= 3` accepted P2 issues
- voice press-hold gesture test passes `30 / 30`
  - hold to record
  - slide to cancel
  - release to send
- keyboard, emoji panel, and attachment panel toggle stress test passes `50` repeated transitions with `0` stuck states and `0` layout corruption
- chat page transition, reaction interaction, typing feedback, and media preview flows are signed off in `im-ux-validation-report.md` as better than the Android baseline on continuity, feedback, and perceived smoothness

### Gate 5: Backend Latency and Capacity Beyond Baseline

The backend may only claim superiority when both relative and absolute targets are met.

#### Relative targets against current production baseline

- `/v1/ping` p95 improves by at least `20%`
- core authenticated read APIs used by the client improve p95 by at least `15%`
- client reconnect-to-usable time improves by at least `20%`

#### Absolute release floors on the current production host class

- `/v1/ping` p95: `<= 30ms`
- user settings and favorites probe p95: `<= 120ms`
- message send-to-ack round trip p95 within the same region test path: `<= 300ms`
- current single-node production host sustains:
  - `2000` idle websocket sessions
  - `100` concurrent active senders
  - `30` minutes steady run
  - error rate `< 0.1%`
  - no OOM
  - no service crash

### Gate 6: Backend Architecture and Operability Beyond Baseline

The backend may only claim architectural superiority when all of the following are true:

- deployment is reproducible from source-controlled scripts and templates
- configuration is template-driven and environment-specific, not ad-hoc on-server editing
- Prometheus and Loki monitoring paths are configured for:
  - CPU
  - memory
  - goroutines
  - websocket connection count
  - API latency p95/p99
  - error rate
  - MySQL slow queries
  - Redis health
- daily backup path exists and restore drill passes
- restart recovery validation passes for:
  - `tsdd-api`
  - `wukongim`
  - `nginx`
- each single-service restart restores healthy probes within `60s`
- full stack restore after controlled stop returns to healthy state within `5min`

### Gate 7: Cluster-Ready Proof

The backend may only claim it has gone beyond a legacy single-node architecture when these staging validations pass:

- `WuKongIM` cluster compose boot proof succeeds using `docker/cluster`
- metrics pipeline boot proof succeeds using `docker/monitor`
- gateway path boot proof succeeds using `docker/gateway`
- one-node failure drill in staging proves:
  - surviving nodes remain healthy
  - client reconnect recovers within `15s`
  - no message corruption is observed in validation flows

### Gate 8: Release Certification

Final release may only be declared when:

- Gates 1 through 7 are all green
- `im-release-certification.md` contains:
  - exact build identifiers
  - tested server version
  - tested Flutter commit reference or snapshot reference
  - device matrix
  - test commands
  - unresolved accepted risks
  - rollback steps

## Program Structure

### Workstream A: Truth, Baselines, and Matrix

**Objective:** Create the evidence model that prevents fake parity and fake “beyond native” claims.

**Outputs:**
- `im-native-feature-matrix.md`
- `im-native-benchmark-baseline.md`

**Tasks:**
- [ ] Inventory native Android feature entry points from `app`, `wkbase`, `wkuikit`, `wklogin`, `wkpush`, and `wkscan`.
- [ ] Map each Android feature to Flutter equivalent or gap.
- [ ] Classify every row as `P0`, `P1`, `P2`, or `P3`.
- [ ] Capture baseline native Android benchmarks on the same test devices used later for Flutter comparison.
- [ ] Capture current backend baseline from existing deployment scripts and production probes.

**Completion standard:**
- No release-critical feature is left outside the matrix.
- No “beyond native” claim is made without a recorded native baseline.

### Workstream B: Flutter Trunk Convergence

**Objective:** Execute the existing client execution plan until the realtime/timeline trunk is authoritative.

**Primary source plan:**
- `docs/superpowers/plans/2026-04-11-im-autopilot-execution-plan.md`

**Mandatory order inside this workstream:**
- [ ] Sprint 0: preflight and websocket stub quarantine
- [ ] Sprint 1: `SessionRuntime` supervisor hardening
- [ ] Sprint 2: `IMService` lifecycle convergence
- [ ] Sprint 3: `ConversationNotifier` stabilization
- [ ] Sprint 4: `ChatViewportController` incremental rendering backbone

**Completion standard:**
- Gate 2 is green.
- No second realtime path remains active in production flows.

### Workstream C: Native Parity Closure

**Objective:** Close all `P0` and `P1` gaps from the parity matrix before advanced features.

**Primary files likely involved:**
- `wukong_im_app/lib/modules/conversation/conversation_activity_registry.dart`
- `wukong_im_app/lib/service/api/message_api.dart`
- `wukong_im_app/lib/modules/chat/chat_composer_controller.dart`
- `wukong_im_app/lib/modules/chat/conversation_read_controller.dart`
- `wukong_im_app/lib/modules/auth/application/device_session_controller.dart`
- `wukong_im_app/lib/realtime/device/device_identity_service.dart`
- `wukong_im_app/lib/service/api/group_api.dart`
- `wukong_im_app/lib/modules/group/group_controller.dart`

**Tasks:**
- [ ] Finish typing send/receive/expiry loop.
- [ ] Finish read receipt and unread convergence.
- [ ] Finish multi-device session invalidation and device-management parity.
- [ ] Finish group contract parity and state refresh.
- [ ] Finish search, message actions, resend, revoke, media flow, and parity leftovers identified in the matrix.

**Completion standard:**
- Gate 1 is green.
- Remaining `P2` rows are consciously deferred and documented.

### Workstream D: Flutter Beyond Native Performance

**Objective:** Make the Flutter client technically superior on the same device class and workload.

**Primary files likely involved:**
- `wukong_im_app/lib/modules/chat/chat_viewport_controller.dart`
- `wukong_im_app/lib/modules/chat/chat_message_mapper.dart`
- `wukong_im_app/lib/modules/chat/widgets/chat_message_viewport.dart`
- `wukong_im_app/lib/modules/chat/widgets/chat_message_list_item.dart`
- `wukong_im_app/lib/modules/chat/chat_media_action_service.dart`

**Tasks:**
- [ ] Measure current render hotspots before optimization.
- [ ] Reduce full-list rebuild frequency.
- [ ] Offload only proven heavy workloads to isolates.
- [ ] Tune media cache and image/video memory behavior.
- [ ] Re-run benchmark suite after each major performance change.

**Completion standard:**
- Gate 3 is green.

### Workstream E: Flutter Beyond Native UX

**Objective:** Make interactions feel more coherent, responsive, and polished than the Android baseline.

**Primary files likely involved:**
- `wukong_im_app/lib/modules/chat/widgets/chat_voice_press_hold_button.dart`
- `wukong_im_app/lib/modules/chat/widgets/chat_voice_record_overlay.dart`
- `wukong_im_app/lib/modules/chat/widgets/chat_message_viewport.dart`
- `wukong_im_app/lib/modules/conversation/conversation_list_page.dart`

**Tasks:**
- [ ] Improve gesture confidence and cancellation feedback.
- [ ] Improve transition continuity between conversation list, chat, media preview, and search locate flows.
- [ ] Make message feedback animations informative without adding churn.
- [ ] Run manual UX validation against the native baseline on real devices.

**Completion standard:**
- Gate 4 is green.

### Workstream F: Backend Deployment and Service Hardening

**Objective:** Move the backend from “production scaffold” to “measurably stronger production system”.

**Primary files and directories:**
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/docker-compose.yaml`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/config/tsdd.yaml.tpl`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/config/wk.yaml.tpl`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/scripts/smoke_test.py`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/scripts/perf_probe.py`
- `TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/scripts/call_stack_smoke.py`

**Tasks:**
- [ ] Freeze the current production topology and document it.
- [ ] Add missing health, smoke, and perf checks for the Flutter-critical endpoints.
- [ ] Validate backup and restore paths.
- [ ] Validate service restart recovery paths.
- [ ] Establish repeatable production rollout and rollback steps.

**Completion standard:**
- Gates 5 and 6 are green for the current production host class.

### Workstream G: Backend Architecture Beyond Legacy Single Node

**Objective:** Prove the backend architecture is not only deployable but scale-ready and observable.

**Primary files and directories:**
- `TangSengDaoDao/WuKongIM-main/config/wk.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/gateway/docker-compose.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/cluster/docker-compose.yaml`
- `TangSengDaoDao/WuKongIM-main/docker/monitor/docker-compose.yaml`

**Tasks:**
- [ ] Stand up gateway, cluster, and monitor staging proofs.
- [ ] Capture cluster boot, metrics, and failover evidence.
- [ ] Add dashboards and alert rules needed for production confidence.
- [ ] Validate reconnect behavior through cluster/gateway paths.

**Completion standard:**
- Gate 7 is green.

### Workstream H: Advanced Capabilities

**Objective:** Add E2EE and bot work only after parity and superiority foundations are proven.

**Primary files likely involved:**
- `wukong_im_app/lib/service/api/crypto_api.dart`
- `wukong_im_app/lib/service/api/robot_api.dart`
- `wukong_im_app/lib/data/models/wk_custom_content.dart`

**Tasks:**
- [ ] Define E2EE boundaries so they do not destabilize message reliability.
- [ ] Define bot capability boundaries so they do not fragment the main chat model.
- [ ] Add tests and rollout strategy only after the core program is already green.

**Completion standard:**
- Advanced features remain isolated from the core IM trunk.
- No advanced feature is allowed to regress Gates 1 through 7.

## Recommended Execution Order

1. Workstream A
2. Workstream B
3. Workstream C
4. Workstream D
5. Workstream E
6. Workstream F
7. Workstream G
8. Workstream H
9. Release certification

## Non-Negotiable Reporting Rules

Every implementation phase must publish evidence, not just status text.

- “Parity complete” requires a matrix row closure report.
- “Beyond native performance” requires before/after benchmark tables.
- “Backend improved” requires probe output, recovery logs, and deployment evidence.
- “Release ready” requires all gate documents linked in `im-release-certification.md`.

## What This Plan Does Not Claim Today

This plan defines how the program can honestly earn the claim “aligned with native and beyond native”. It does **not** claim that the current Flutter app or backend has already achieved that standard.
