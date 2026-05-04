# Realtime KPI Dashboard Definition (Task 7)

Last updated: 2026-04-17 (Asia/Shanghai)

## 1. Purpose

Define the production dashboard contract for realtime gray release monitoring.  
This file is the canonical KPI dictionary used by the Task 7 runbook.

## 2. KPI Dictionary

| KPI | Source (where to collect) | Meaning | Suggested visualization | Alert threshold |
|---|---|---|---|---|
| `gateway_connect_success_rate` | Gateway WS handshake/open path in `lib/realtime/session/session_runtime.dart` + backend session gateway endpoint (`/v1/realtime/session/events/ws`) in `.task4_remote_sync/modules/user/api_session_compat.go` | Ratio of successful realtime gateway connections to total connection attempts | Single stat + 5m line (success rate) + attempts volume bar | Warning: below baseline by 1pp for 10m. Critical: below baseline by 2pp for 10m |
| `gateway_reconnect_count` | Client retry scheduling in `SessionRuntime` (`_handleGatewayTermination`, `_scheduleRecovery`) and session reconnect telemetry | Number of reconnect attempts per session/window | p50/p95 line + distribution histogram by device/app version | Rollback trigger: `reconnect_count p95 > baseline * 2` |
| `control_frame_decode_error_count` | Decode failures in `lib/realtime/session/session_event_gateway.dart` (`_decodeFrame`) and backend envelope decode path in `.task4_remote_sync/modules/realtime/control_stream.go` (`DecodeControlEnvelope`) | Count of control frames that fail decode/validation | Error count line + stacked split by protocol (json/protobuf) | Rollback trigger is derived rate: `decode_error_rate > 0.5%` |
| `pull_after_seq_repair_count` | Gap-repair loop in `lib/realtime/session/session_runtime.dart` (`_repairGapIfNeeded`) and backend pull endpoint `/v1/realtime/session/events/pull_after_seq` in `.task4_remote_sync/modules/user/api_session_delta.go` | Number of gap-repair pulls executed | Line chart + heatmap by app version/network type | Rollback trigger is derived rate: `gap_repair_rate > 5%` |
| `sqlite_page_query_p95_ms` | Message pagination query path from `IMSyncApi.pageChannelMessages` in `lib/service/api/im_sync_api.dart` and corresponding DB query timing hook | P95 latency of page-based SQLite/message query path | p95/p99 latency line + percentile table | Warning: > baseline * 1.5 for 15m. Critical: > baseline * 2 for 15m |
| `conversation_list_patch_apply_p95_ms` | Conversation patch application path in `ConversationNotifier.applyPatch` (`lib/data/providers/conversation_provider.dart`) | P95 time to apply a conversation patch and publish updated state | p95 line + top-N slow channels table | Warning: > baseline * 1.5 for 15m. Critical: > baseline * 2 for 15m |

## 3. Derived Rollback Signals (fixed)

These derived signals must be visible on the same dashboard:

| Signal | Formula | Window | Sample/persistence guard | Trigger |
|---|---|---|---|
| `decode_error_rate` | `control_frame_decode_error_count / inbound_control_frame_count` | 5m rolling | Evaluate only when `inbound_control_frame_count >= 2000` and breach persists for 2 consecutive windows | Rollback if `> 0.5%` |
| `reconnect_count_p95` | `p95(gateway_reconnect_count per session)` | 10m rolling | Evaluate only when `active_realtime_session_count >= 200`, breach persists for 2 consecutive windows, and alert math uses `max(captured_baseline_reconnect_p95, 1)` when the raw baseline is zero | Rollback if `> baseline * 2` |
| `gap_repair_rate` | `pull_after_seq_repair_count / successful_gateway_connect_count` | 10m rolling | Evaluate only when `successful_gateway_connect_count >= 500` and breach persists for 2 consecutive windows | Rollback if `> 5%` |

Notes:

- `inbound_control_frame_count` and `successful_gateway_connect_count` are denominator series from gateway telemetry.
- `active_realtime_session_count` is an operational guard metric for `reconnect_count_p95`; it does not replace the fixed KPI set.
- Baseline is captured immediately before rollout using `docs/2026-04-17-realtime-baseline-template.md`.
- A rollback alert is actionable only when both the fixed threshold and the sample/persistence guard are satisfied.
- A phase cannot auto-promote until each rollback signal has met its sample guard at least once during the current phase window.

## 4. Dashboard Layout Recommendation

Panel order (top to bottom):

1. Release phase marker + current traffic percentage.
2. `gateway_connect_success_rate` and `gateway_reconnect_count` (same row).
3. `control_frame_decode_error_count` + `decode_error_rate`.
4. `pull_after_seq_repair_count` + `gap_repair_rate`.
5. `sqlite_page_query_p95_ms` + `conversation_list_patch_apply_p95_ms`.
6. Annotation stream for rollout promotions, holds, rollbacks.

## 5. Alert Routing

- Warnings: route to release commander + owning stream channel.
- Critical/rollback triggers: page on-call SRE and open incident bridge immediately.
- Every trigger alert must include: current value, baseline, denominator volume or active-session count, release phase, consecutive breach count, and last 15-minute trend.
