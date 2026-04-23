# WuKongIM Gray Release Runbook (Task 7)

Last updated: 2026-04-17 (Asia/Shanghai)

## 1. Scope

This runbook is for Task 7 of `docs/superpowers/plans/2026-04-17-wukongim-30-day-optimization-rollout.md` and covers gray release, dashboard monitoring, and rollback execution for realtime/session changes.

Fixed rollout order:

`10% internal users -> 30% Android users -> 50% full mobile users -> 100% all devices`

Fixed KPI set:

- `gateway_connect_success_rate`
- `gateway_reconnect_count`
- `control_frame_decode_error_count`
- `pull_after_seq_repair_count`
- `sqlite_page_query_p95_ms`
- `conversation_list_patch_apply_p95_ms`

Fixed rollback triggers:

- `decode_error_rate > 0.5%`
- `reconnect_count p95 > baseline * 2`
- `gap_repair_rate > 5%`

## 2. Owners and Roles

- Release commander: owns phase promotion/hold/rollback decisions.
- Client owner: owns app-side protocol mode, session runtime, conversation patch behavior.
- Backend owner: owns gateway protocol negotiation, decode path, `pull_after_seq` endpoint.
- DB/perf owner: owns SQLite and pagination performance interpretation.
- On-call SRE: owns alert routing, incident bridge, and rollback clock tracking.

## 3. Pre-Checks (must pass before Phase 1)

### 3.1 Baseline evidence capture (T-60 to T-30)

Archive baseline evidence using `docs/2026-04-17-realtime-baseline-template.md`.
Unit/integration verification must come from CI or an operator workstation or staging checkout, not from the production host.

```powershell
flutter test test/realtime/control/control_proto_codec_test.dart test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart test/service/im/im_service_test.dart
dart analyze lib/realtime/session/session_runtime.dart test/realtime/session/session_runtime_test.dart lib/service/im/im_service.dart test/service/im/im_service_test.dart
```

Required attachments before rollout:

- Latest successful CI or staging evidence for backend `go test -count=1 ./modules/realtime/...`
- Latest successful CI or staging evidence for backend `go test -v -count=1 ./modules/user -run '^TestSessionCompat'`
- Archived baseline snapshot for all six KPIs
- Recorded immutable rollback target:
  - `rollback_target_commit` or CI artifact ID
  - operator confirmation that `git status --porcelain` is empty before deploy from that target

Capture current production build metadata before rollout:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && grep -E '^(BUILD_VERSION|BUILD_COMMIT|BUILD_COMMIT_DATE|BUILD_TREE_STATE)=' .env"
```

Record baseline values (required):

- `gateway_connect_success_rate` baseline
- `gateway_reconnect_count` p95 baseline
- `control_frame_decode_error_count` and baseline decode error rate
- `pull_after_seq_repair_count` and baseline gap repair rate
- `sqlite_page_query_p95_ms` baseline
- `conversation_list_patch_apply_p95_ms` baseline

### 3.2 Production readiness checks (T-30 to T-10)

Run only health/readiness and smoke probes on the production host:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10"
```

- Confirm client still supports protocol fallback (JSON path remains valid).
- Confirm server protocol negotiation supports both JSON and protobuf.
- Confirm `/v1/realtime/session/events/pull_after_seq` is reachable and returns ordered frames.
- Confirm dashboard file `deploy/dashboard/realtime-kpis.md` has been applied.
- Confirm `docker compose --env-file .env ps` reports `tsdd-api`, `callgateway`, `nginx`, `wukongim`, `mysql`, `redis`, and `minio` healthy or running as expected.
- Confirm rollback operator, approver, and comms channel are online.

### 3.3 Launch go/no-go (T-10 to T0)

- Commander reads baseline snapshot and signs off.
- Incident bridge prepared (but not opened unless hold/rollback).
- Rollout starts only after all pre-checks are green.

## 4. Phase Release Plan and Monitoring Windows

Phase targeting semantics:

- Percentages are cohort-scoped, not global. Each phase percentage is evaluated against the eligible cohort for that phase.
- Rollout is cumulative. A user enabled in an earlier phase stays enabled until rollback.
- Cohort predicates must be frozen in the release ticket before T-10 and cannot change mid-phase.
- Pre-promotion validation is mandatory. The operator must record `eligible_count`, `enabled_count`, and `enabled_pct` for the next phase cohort, and promotion is blocked unless `enabled_pct` matches the target within `+/-0.5pp`.

Phase cohort definition:

| Phase | Eligible cohort | Percentage basis | Cumulative rule |
|---|---|---|---|
| Phase 1 | Internal users only | `enabled_internal / eligible_internal = 10%` | First enabled cohort |
| Phase 2 | External Android users only | `enabled_android_external / eligible_android_external = 30%` | Keep Phase 1 enabled; add Android cohort |
| Phase 3 | All external mobile users (`android + ios`) | `enabled_mobile_external / eligible_mobile_external = 50%` | Keep Phase 1-2 enabled; expand total mobile cohort to 50% |
| Phase 4 | All users on all devices | `enabled_all / eligible_all = 100%` | Global full rollout |

Current limitation:

- The backend rollout controller is now driven by `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON` in `deploy/production/.env`, but it is still deployment-scoped rather than a live remote-config toggle.
- Phase promotions currently require updating `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON` and recreating `tsdd-api` / `callgateway`.
- The client code still does not expose a runtime app-side protobuf kill switch for `lib/service/im/im_service.dart::_preferProtobufControlProtocol`. Treat client protobuf disablement as a follow-up hotfix, not as an immediate no-code rollback lever.

| Phase | Traffic | Audience | Minimum monitoring window | Promote when all conditions are true |
|---|---|---|---|---|
| Phase 1 | 10% | Internal users | 60 min | No rollback trigger fired; no sustained KPI regression vs baseline |
| Phase 2 | 30% | Android users | 90 min | Phase 1 stable + no rollback trigger in Phase 2 |
| Phase 3 | 50% | Full mobile users | 120 min | Phase 2 stable + no rollback trigger in Phase 3 |
| Phase 4 | 100% | All devices | 180 min (heightened watch) | Phase 3 stable + no rollback trigger in first 180 min |

Operational rule:

- If any rollback trigger fires in any phase, stop promotion immediately and execute Section 6 rollback steps.
- Promotion is blocked until the current phase has satisfied every rollback-signal sample guard at least once. If sample coverage is not reached by the end of the minimum window, extend the phase and do not auto-promote.

## 5. KPI Watch Rules During Rollout

Watch all six KPIs continuously and evaluate these derived rollback signals:

- `decode_error_rate = control_frame_decode_error_count / inbound_control_frame_count`
- `reconnect_count_p95 = p95(gateway_reconnect_count per session/window)`
- `gap_repair_rate = pull_after_seq_repair_count / successful_gateway_connect_count`

Trigger validation guardrails:

- `decode_error_rate` is actionable only when `inbound_control_frame_count >= 2000` in each 5-minute window and the threshold is breached for 2 consecutive windows.
- `reconnect_count_p95` is actionable only when `active_realtime_session_count >= 200` in each 10-minute window, the threshold is breached for 2 consecutive windows, and the alerting baseline uses `max(captured_baseline_reconnect_p95, 1)` when the raw baseline is zero.
- `gap_repair_rate` is actionable only when `successful_gateway_connect_count >= 500` in each 10-minute window and the threshold is breached for 2 consecutive windows.

Rollback thresholds (fixed):

- rollback when `decode_error_rate > 0.5%`
- rollback when `reconnect_count_p95 > baseline * 2`
- rollback when `gap_repair_rate > 5%`

Note: `inbound_control_frame_count` and `successful_gateway_connect_count` are denominator series from gateway ingestion/handshake telemetry used to compute rate signals.

## 6. Rollback Procedure (executable)

### 6.1 Immediate actions (0-5 minutes)

1. Freeze rollout at current phase percentage (no further traffic increase).
2. Commander declares `ROLLBACK` in release channel with timestamp and trigger metric.
3. Start incident timer and assign owner per stream: client, backend, SRE.

### 6.2 Technical rollback actions (5-20 minutes)

Rollback command matrix:

| Step | Owner | Command or control point | SLA | Success criteria |
|---|---|---|---|---|
| 1 | Backend owner | On the operator workstation, check out the pre-recorded immutable rollback target, confirm a clean tree, then redeploy: `git checkout --detach <ROLLBACK_TARGET_COMMIT>`; `git status --porcelain`; `.\deploy\production\scripts\deploy_remote.ps1 -Server ubuntu@42.194.218.158 -RemoteRoot /opt/wukongim-prod -BuildTsddApi` | 10 min | `tsdd-api` and `callgateway` are recreated from the pinned rollback target; deploy starts from a clean detached checkout |
| 2 | SRE | Verify compose health on host: `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"` | 3 min | `tsdd-api`, `callgateway`, `nginx`, `wukongim`, `mysql`, `redis`, `minio` are healthy or running as expected |
| 3 | SRE | Verify deployed metadata matches the rollback target: `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && grep -E '^(BUILD_VERSION|BUILD_COMMIT|BUILD_COMMIT_DATE|BUILD_TREE_STATE)=' .env"` | 3 min | `BUILD_COMMIT` and related metadata match the recorded rollback target in the release ticket |
| 4 | SRE | Verify no immediate crash loop or decode storm: `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env logs --since=10m tsdd-api callgateway nginx | tail -n 200"` | 5 min | No repeated panic/restart loop; no sustained control decode failures in the latest log window |
| 5 | Backend owner | If the trigger is gap-repair related, verify the stable `/v1/realtime/session/events/pull_after_seq` path with the existing smoke tooling: `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10"` | 5 min | Realtime/session smoke checks pass on the stable deployment |
| 6 | Client owner | Open a containment follow-up for client hotfix by setting `lib/service/im/im_service.dart::_preferProtobufControlProtocol = false`, rebuilding the affected app release, and distributing it by channel priority | Same business day | New client build stops sending `control_protocol=protobuf` and `X-Realtime-Control-Protocol: protobuf` on new session connections |

Operational note:

- Because `_preferProtobufControlProtocol` is currently a compile-time constant, client-side protobuf disablement is not an immediate rollback control. The immediate rollback action is the stable backend redeploy in Steps 1-5; Step 6 is follow-up containment.

### 6.3 Recovery verification (20-50 minutes)

- Run the full minimum monitoring window of the current rollback phase after rollback actions:
  - Phase 1 rollback: 60 minutes
  - Phase 2 rollback: 90 minutes
  - Phase 3 rollback: 120 minutes
  - Phase 4 rollback: 180 minutes
- Confirm all three rollback trigger signals are below threshold.
- Confirm no continued degradation in `sqlite_page_query_p95_ms` and `conversation_list_patch_apply_p95_ms`.

### 6.4 Rollback closeout

- Mark release status `ROLLED_BACK`.
- Store incident summary with root cause hypothesis and follow-up owner.
- Do not restart rollout until baseline is re-captured and approved.

## 7. Task 1/3/4/5/6 to KPI Traceability

| Task | What changed | Primary KPI(s) | Why this KPI is the first signal |
|---|---|---|---|
| Task 1 | Baseline + kill switch + session runtime observability | `gateway_connect_success_rate`, `gateway_reconnect_count` | Defines expected normal and rollback lever; reconnect/connect shifts show gateway instability first |
| Task 3 | `pull_after_seq` incremental gap repair on client/server | `pull_after_seq_repair_count` | Gap repair frequency rises when seq continuity is unhealthy |
| Task 4 | SQLite indexes and pagination hardening | `sqlite_page_query_p95_ms` | Directly measures query tail latency impacted by index/pagination behavior |
| Task 5 | Chat timeline virtualization + conversation patch path | `conversation_list_patch_apply_p95_ms` | Measures cost of applying realtime conversation updates in UI state path |
| Task 6 | Realtime gateway module split + protocol handling boundaries | `gateway_connect_success_rate`, `gateway_reconnect_count`, `control_frame_decode_error_count` | Gateway split issues typically surface as connect failures, reconnect storms, or decode failures |

## 8. Owner Checklist

### Before rollout

- [ ] Baseline doc captured and attached
- [ ] CI or staging verification attached for required tests/analyze commands
- [ ] Production readiness commands completed (`docker compose ps`, `smoke_test.py`, `perf_probe.py`)
- [ ] Fixed KPI dashboard verified
- [ ] Next-phase cohort snapshot archived (`eligible_count`, `enabled_count`, `enabled_pct`)
- [ ] Rollback operator and approver on call

### Per phase

- [ ] Start timestamp recorded
- [ ] Monitoring window completed
- [ ] No rollback trigger breached
- [ ] Promotion approved by commander

### If rollback

- [ ] Rollback declared in channel
- [ ] Rollout frozen
- [ ] Stable backend rollback executed and metadata verified
- [ ] Client hotfix decision recorded
- [ ] Recovery window validated
- [ ] Incident notes archived

### After 100%

- [ ] 180-minute heightened watch completed
- [ ] Final KPI snapshot archived
- [ ] Release marked `DONE` or `DONE_WITH_CONCERNS`
