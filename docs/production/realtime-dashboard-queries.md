# Realtime Dashboard Queries

This document maps the fixed KPI contract from `deploy/dashboard/realtime-kpis.md`
to rollout panels and rollback signals in Grafana.

## Fixed KPI Panels

| Panel title | PromQL | Visualization | Guard notes |
|---|---|---|---|
| `gateway_connect_success_rate` | `sum(increase(successful_gateway_connect_count[5m])) / clamp_min(sum(increase(gateway_connect_attempt_total[5m])), 1)` | Single stat + 5-minute trend line | Compare against the captured rollout baseline before promoting the next phase. |
| `gateway_reconnect_count` | `histogram_quantile(0.95, sum(rate(gateway_reconnect_count_bucket[10m])) by (le))` | p50/p95 line + histogram by app version | Keep the panel title aligned to the KPI contract and expose percentile series in the legend. |
| `control_frame_decode_error_count` | `sum(increase(control_frame_decode_error_count[5m]))` | Error count line + protocol split | Pair this panel with the derived `decode_error_rate` signal on the same row. |
| `pull_after_seq_repair_count` | `sum(increase(pull_after_seq_repair_count[10m]))` | Line chart + heatmap by app version/network type | Pair this panel with the derived `gap_repair_rate` signal. |
| `sqlite_page_query_p95_ms` | `histogram_quantile(0.95, sum(rate(sqlite_page_query_seconds_bucket[5m])) by (le)) * 1000` | p95/p99 latency line | Alert against the current phase baseline using the thresholds from the KPI contract. |
| `conversation_list_patch_apply_p95_ms` | `histogram_quantile(0.95, sum(rate(conversation_patch_apply_seconds_bucket[5m])) by (le)) * 1000` | p95 latency line + top-N slow channels table | Track together with `sqlite_page_query_p95_ms` to separate storage regressions from UI patch-apply regressions. |

## Derived Rollback Signals

| Signal | PromQL | Window | Sample and persistence guard | Trigger |
|---|---|---|---|---|
| `decode_error_rate` | `sum(increase(control_frame_decode_error_count[5m])) / clamp_min(sum(increase(inbound_control_frame_count[5m])), 1)` | 5-minute rolling | Evaluate only when `sum(increase(inbound_control_frame_count[5m])) >= 2000` and the breach persists for 2 consecutive windows. | Roll back if `> 0.005` |
| `reconnect_count_p95` | `histogram_quantile(0.95, sum(rate(gateway_reconnect_count_bucket[10m])) by (le))` | 10-minute rolling | Evaluate only when `sum(active_realtime_session_count) >= 200`, require 2 consecutive breach windows, and compare the panel output against the operator-captured baseline using `max(baseline, 1)` in Grafana thresholding or alert-rule templating rather than inline PromQL. | Roll back if `> baseline * 2` |
| `gap_repair_rate` | `sum(increase(pull_after_seq_repair_count[10m])) / clamp_min(sum(increase(successful_gateway_connect_count[10m])), 1)` | 10-minute rolling | Evaluate only when `sum(increase(successful_gateway_connect_count[10m])) >= 500` and the breach persists for 2 consecutive windows. | Roll back if `> 0.05` |

## Runtime Prerequisites

- Create the external Docker network before the first start:
  `docker network create wukongim_monitoring`
- The fallback scrape targets `host.docker.internal:5300` and
  `host.docker.internal:8080` assume the gateway and API metrics listeners are
  reachable from the Docker bridge. If those services bind only to
  `127.0.0.1`, add a bridge-reachable listener or a host-level metrics proxy
  before trusting the dashboard.
- Task 4 provisions the datasource and the `WuKongIM` dashboard folder. Import a
  dashboard JSON or add file-provisioned dashboards before operator handoff if
  you want the folder populated on first boot.

## Panel Layout

1. Release phase marker + current traffic percentage.
2. `gateway_connect_success_rate` and `gateway_reconnect_count`.
3. `control_frame_decode_error_count` and `decode_error_rate`.
4. `pull_after_seq_repair_count` and `gap_repair_rate`.
5. `sqlite_page_query_p95_ms` and `conversation_list_patch_apply_p95_ms`.
6. Rollout annotations for promote, hold, and rollback events.

## Naming Alignment

- Keep dashboard titles aligned with the fixed KPI names in
  `deploy/dashboard/realtime-kpis.md`.
- Treat `decode_error_rate`, `reconnect_count_p95`, and `gap_repair_rate` as
  derived rollback signals, not replacements for the fixed KPI set.
- Do not auto-promote a phase until each derived rollback signal has met its
  sample guard at least once during the current phase window.
