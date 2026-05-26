# Phase 3 Production Bottleneck Analysis

**Reader:** future WuKongIM engineer preparing the next production optimization batch.

**Post-read action:** choose the first Phase 3 backend optimization batch and verify it against production Prometheus baselines.

**Data window:** production Prometheus sampled on 2026-05-26 around 16:16 Asia/Shanghai, after Phase 2 backend metrics had been deployed for more than 48 hours.

## Executive Summary

The production data is sufficient for Phase 3 planning. The `wukongim_api` Prometheus target has a complete 24-hour sample window, and the API handled about 5.0 million HTTP requests in the last 24 hours. The high-volume sync APIs are currently fast at the HTTP layer, with p95 around 5 ms for the hottest routes. That means Phase 3 should not begin with risky rewrites of the main sync protocol.

The best first backend batch is low-risk efficiency and guardrail work:

- add a short TTL route cache for `/v1/users/:uid/im`;
- reduce `conversation/syncack` CPU and DB round trips by replacing nested dedupe with map-based dedupe and adding post-ack cache cleanup;
- add object-storage phase metrics and reuse MinIO client/bucket readiness;
- add hard Phase 3 PromQL gates before any production switch.

The largest deeper opportunity remains `conversation/sync`, where code review found per-conversation message extra/reaction queries. That is likely an important scaling risk, but the current production HTTP p95 is already low, so it should be implemented after guardrails and narrower low-risk changes are in place.

## Production Baseline

Prometheus readiness:

- Current `up{job="wukongim_api"}`: `1`
- 24-hour `min_over_time(up[24h])`: `1`
- 24-hour `avg_over_time(up[24h])`: `1`
- 24-hour samples: `5760`, matching a 15-second scrape interval
- 48-hour samples: `11520`
- 48-hour minimum included an earlier down state from rollout/recreate, so the stable decision window should use the latest clean 24 hours
- Current scrape samples: about `1564`
- Current scrape duration: about `7 ms`

Traffic:

- HTTP requests in 24 hours: about `5,035,358` 2xx, `4,341` 3xx, and `55` 4xx
- HTTP requests in 48 hours: about `9.1 million`
- 24-hour 5xx: none observed
- 24-hour 4xx: about `55`, mostly login/appversion/websocket/config/register/user-state style client or auth errors
- `route="unknown"` in 24 hours: `0`
- Current request rate around sampling time: about `21.5 requests/second`

Hot routes in the 24-hour window:

| Route | 24h Requests | Notes |
|---|---:|---|
| `POST /v1/message/sync` | about 852k | hottest message sync operation |
| `POST /v1/conversation/extra/sync` | about 843k | high-volume incremental metadata sync |
| `GET /v1/users/:uid/im` | about 572k | high-volume route lookup, upstream dependent |
| `POST /v1/conversation/sync` | about 544k | important stateful sync path |
| `POST /v1/conversation/syncack` | about 541k | high-volume ack path |
| `GET /v1/message/sync/sensitivewords` | about 525k | low-complexity static response path |
| `GET /v1/message/prohibit_words/sync` | about 522k | DB-backed incremental sync |
| `POST /v1/message/reminder/sync` | about 514k | DB-backed reminder sync |

Latency:

| Route / Operation | 24h p95 | 24h p99 | Interpretation |
|---|---:|---:|---|
| `POST /v1/message/sync` | about 4.78 ms | about 4.98 ms | healthy under current load |
| `POST /v1/conversation/extra/sync` | about 4.75 ms | about 4.95 ms | healthy under current load |
| `GET /v1/users/:uid/im` | about 4.75 ms | about 4.95 ms | healthy, but high-volume and upstream-dependent |
| `POST /v1/file/upload` | about 456 ms | about 491 ms | slower, but only about 14 HTTP samples in 24h |
| `file_upload` operation | about 456 ms | not enough samples | needs phase-level metrics before optimizing deeply |

## Code Path Findings

### High-volume sync paths

`POST /v1/message/sync` calls the upstream WuKongIM message sync API, then enriches returned messages through local message extra, user extra, channel offset, and channel setting queries. The production p95 is currently low, so this is not the first candidate for behavior changes. The risk is that larger sync responses can amplify DB work because message extras include related read-state lookups.

`POST /v1/conversation/extra/sync` reads conversation extra rows by user and version. It is currently fast, but old clients can still request a large version gap. This path should eventually get bounded page size semantics and confirmed `(uid, version)` indexing.

`GET /v1/users/:uid/im` performs an upstream route lookup for every request. It has no local short TTL cache or stale fallback. It is high-volume and safe to cache for a few seconds because route targets should not change per request in normal operation. This is the strongest low-risk Phase 3 candidate.

`POST /v1/conversation/sync` has the largest code-level scaling risk. For each conversation response, the current response builder queries message user extras, message extras, and message reactions for that conversation's recent messages. This creates a per-conversation query pattern. It also performs slice-based group validity matching and stores sync results in a process map keyed only by user.

`POST /v1/conversation/syncack` is high-volume and has a clear local inefficiency. It reads the last sync result from an in-process map, then deduplicates channel offsets with a nested loop and writes offsets one by one inside a transaction. It also leaves sync result cache entries in memory after ack.

`GET /v1/message/prohibit_words/sync` is DB-backed and unbounded for old versions. It should be paginated and ordered by version after index verification.

`POST /v1/message/reminder/sync` has a query with `(uid=? or uid='')`, optional channel filters, and a limit controlled by request input. It also does reminder/member matching with nested loops. This is a good second-batch optimization after the very low-risk changes.

### File and media paths

`POST /v1/file/upload` performs synchronous multipart parsing, optional signature hashing, object storage upload, and response construction. The MinIO provider creates a client per upload and checks bucket existence on each upload. Other providers buffer whole files in memory in places. The current sample count is too low to claim this is a production bottleneck, but the code path has obvious tail-latency risks.

`GET /v1/users/:uid/avatar` first checks user avatar state through DB for normal users, then either redirects to object storage/CDN or proxies object storage bytes for internal requests. Default or special avatars may be read from local assets.

`GET /v1/groups/:group_no/avatar` usually redirects to object storage/CDN without DB lookup. Org and department avatar branches read local files on each request.

`POST /v1/groups/:group_no/avatar` synchronously parses multipart data, checks group and ownership, uploads object storage, updates DB, then sends a group avatar update command. Object storage and command delivery can both affect tail latency.

## Phase 3 Priorities

### Batch 1: Guarded backend low-risk optimization

1. Route cache for `/v1/users/:uid/im`
   - Cache successful upstream route responses by UID for a short TTL, for example 5 seconds.
   - Preserve manager token forwarding and exact response contract.
   - Add stale fallback for short upstream failures only if the cached value is still recent enough.
   - Expected gain: fewer upstream route calls and less sensitivity to IM route jitter.

2. `conversation/syncack` dedupe and cleanup
   - Replace nested dedupe with a map keyed by channel ID and type.
   - Keep only the max message seq per channel.
   - Delete or expire acked sync cache entries after successful ack.
   - Expected gain: less CPU, shorter DB transaction preparation, bounded memory growth.

3. File storage phase metrics plus MinIO reuse
   - Add operation labels for object storage `put`, `bucket_check`, `download_url`, `read`.
   - Reuse MinIO client inside the service.
   - Cache bucket readiness per bucket after successful check/create.
   - Expected gain: visibility into upload p95 cause and fewer repeated object storage setup calls.

4. Phase 3 production gate
   - Convert the PromQL checks into a repeatable script/report step before and after deployment.
   - Gate on target up, route-level p95/p99, 5xx, 4xx drift, operation failures, CPU/memory, and unknown route count.

### Batch 2: Query shape improvements

1. Refactor `conversation/sync` response assembly to batch message extras, user extras, and reactions across all conversations before building responses.
2. Add pagination/default limits to `conversation/extra/sync`, `prohibit_words/sync`, and `reminder/sync`.
3. Convert reminder member matching to maps and dedupe channel IDs.
4. Verify and add missing DB indexes as additive migrations only.

### Batch 3: File/media deeper work

1. Stream providers that currently buffer entire uploads.
2. Avoid double reading when `signature=1`, if provider constraints allow it.
3. Add cache headers for avatar/default asset responses.
4. Consider asynchronous notification for avatar update commands after DB/object write success.

## Production Gates

Phase 3 should not switch service unless these are true before deployment:

- `up{job="wukongim_api"} == 1`
- 24-hour target samples are present, or a recent clean baseline is explicitly recorded
- current 5xx rate is zero or unchanged from baseline
- `route="unknown"` does not increase
- `/v1/ping` is healthy
- Prometheus can scrape `tsdd-api:8090/metrics`

After deployment, observe at least 30 minutes before declaring a backend batch stable:

- route-level 5xx ratio for changed routes stays zero or at baseline
- route-level p95 does not exceed 1.5x baseline for two consecutive windows
- route-level p99 does not exceed 2x baseline for two consecutive windows
- operation failure rate does not increase
- `tsdd-api` CPU and memory do not show sustained growth
- nginx recent 502 count remains zero after the switch window

## Caveats

- Some early ad hoc queries used `status` instead of `status_class`; the correct Phase 2 label is `status_class`.
- File upload currently has too few production samples for strong statistical claims. Treat upload work as instrumentation plus obvious setup-cost cleanup first.
- Existing client and admin-dashboard worktree changes are unrelated to this backend Phase 3 plan and should not be mixed into the backend deployment batch.
