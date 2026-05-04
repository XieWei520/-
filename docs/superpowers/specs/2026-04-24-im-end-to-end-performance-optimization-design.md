# IM End-to-End Performance Optimization Design

Date: 2026-04-24

## Decision

Adopt a staged optimization strategy: first make the IM stack measurable and safe to tune, then apply low-risk client/server hot-path optimizations, and only after baseline evidence run extreme-load tuning. This avoids blind production changes while still moving quickly on clear bottlenecks found during the read-only review.

The first implementation cycle will optimize in this order:

1. Observability and guardrails.
2. Flutter hot-path reductions for startup, conversation list, and chat timeline.
3. Backend/API and Nginx low-risk tuning.
4. Load-test baseline and measured follow-up tuning.

## Context

The product is a Flutter IM client backed by a custom TangSengDaoDao/WuKongIM-style backend and an admin/production deployment on `ubuntu@42.194.218.158`.

Read-only review on 2026-04-24 found:

- The production host is a single node with 4 vCPU and 7.5 GiB RAM.
- Docker services include Nginx, tsdd-api, WuKongIM, MySQL, Redis, MinIO, LiveKit, and coturn.
- WuKongIM runs standalone; its startup log reports one gnet event loop.
- Backend source is on the server under `/opt/wukongim-prod/src` and is not a git checkout.
- Local Flutter workspace has many existing uncommitted changes. Implementation must avoid overwriting unrelated work.
- MySQL table volume is currently small. Several relevant indexes are already present, including `message_extra(channel_id, channel_type, version)` and message channel/sequence indexes in source migrations.
- Slow-query evidence is insufficient for aggressive database changes.
- Prometheus-oriented documentation exists, but concrete metrics exposure was not found in the backend code path reviewed.
- Flutter client has established realtime/session code and telemetry buffering, but UI/data hot paths still contain avoidable work.

## Goals

### Product goals

- Improve perceived startup speed and chat responsiveness without changing user-visible behavior.
- Reduce unnecessary network/database work during login, conversation list rendering, and chat history paging.
- Make server-side bottlenecks visible before high-risk tuning.
- Preserve reliable message delivery, unread state, read receipts, pinned messages, reminders, customer-service routing, and call gateway behavior.

### Engineering goals

- Every production-side change must have an explicit rollback path.
- Every optimization must be covered by tests or measurable runtime evidence.
- Avoid broad refactors unrelated to performance-critical paths.
- Preserve compatibility with existing mobile, desktop, and web builds.

### Performance goals for the first cycle

The first cycle should establish and improve these metrics:

- Flutter cold login to conversation-list-ready time.
- Conversation row build/update cost and redundant per-row API calls.
- Chat page latest-page, older-page, and around-anchor SQLite query latency.
- Backend p50/p95/p99 latency and error rate for core IM endpoints.
- WebSocket connect success rate, reconnect count, and long-connection stability.
- File upload latency and Nginx upstream error count.

Exact thresholds will be finalized from the baseline because current production traffic and data volume are small.

## Non-goals for the first cycle

- Do not convert WuKongIM to a multi-node cluster in this pass.
- Do not split MySQL, Redis, MinIO, or WuKongIM across hosts yet.
- Do not replace the messaging protocol or SDK.
- Do not apply unverified MySQL schema/index changes solely from static code reading.
- Do not rotate secrets as part of performance implementation, though credential rotation should be handled separately because sensitive values were present in production files.

## Recommended Architecture

### Current flow

```text
Flutter client
  -> HTTPS API through Nginx
  -> tsdd-api
  -> MySQL / Redis / MinIO / WuKongIM HTTP API

Flutter client
  -> WuKongIM TCP or WSS route
  -> WuKongIM standalone long-connection gateway
  -> webhook/grpc callback to tsdd-api

Flutter client
  -> realtime session WSS under /v1/realtime/session/events/ws
  -> tsdd-api session compatibility gateway
  -> Redis session state/event history
```

### Optimized first-cycle flow

```text
Flutter client
  -> local coalescing/cache + less row-level async fan-out
  -> signed HTTPS API through Nginx
  -> tsdd-api with request metrics + structured latency logging
  -> MySQL/Redis with observed query/runtime counters

Flutter client
  -> existing WuKongIM route selection
  -> WuKongIM with measured connection health and varz/health probes

Operations
  -> baseline scripts collect host, container, Nginx, API, Redis, MySQL, and client metrics
  -> Locust/smoke suites validate changes before production rollout
```

## Component Design

### 1. Observability and guardrails

Add a small backend metrics layer before tuning behavior.

Backend metrics should cover:

- HTTP request count, latency histogram, and status code by normalized route.
- Realtime session connect attempts/successes, reconnect-related events, control-frame decode errors, and pull-after-seq repairs.
- Message sync/channel sync/message extra sync latency and error counts.
- File upload request count, size buckets if available, and latency.
- Redis and MySQL operation failures when visible from the touched code paths.

Metrics exposure should be safe by default:

- Prefer an internal-only endpoint or Nginx-protected path.
- Do not expose tokens, request bodies, message payloads, or user content.
- Keep labels low-cardinality: route template, method, status class, operation name, and result.

Client metrics should be kept lightweight:

- Continue using existing realtime telemetry transport for session metrics.
- Add debug/test-only instrumentation for startup milestones and UI build hot spots where useful.
- Avoid sending message content or user identifiers beyond already-supported session IDs.

Operational guardrails:

- Capture `docker ps`, `docker stats`, host `free/df/ss`, Nginx error count, backend latency samples, Redis info, and MySQL status before and after changes.
- Keep deployment changes small and reversible.
- Avoid service restarts unless the changed artifact requires them.

### 2. Flutter startup and network fan-out

The current client initializes IM, binds realtime session, syncs reminders/sensitive words/prohibit words/conversation extras/offline commands, fetches friend/group/customer-service metadata, and renders conversation rows. This is correct functionally but can create a burst of parallel network and local DB work.

Design changes:

- Introduce a startup performance coordinator that records milestones without changing business flow: app launch, auth ready, IM setup started, WKIM sync completed, first conversation list loaded, first frame after list loaded.
- Coalesce duplicate user/group metadata fetches during conversation-list rendering. Existing `ConversationListItemLoader` only deduplicates identical row request keys; add a bounded metadata cache/in-flight map by `uid` and `groupNo` so multiple rows or rebuilds do not refetch the same user/group.
- Prefer already-loaded friend, group, and customer-service maps for row title/avatar/category. Network fallback remains only when local/preferred data is missing.
- Ensure telemetry flush and low-priority sync work do not block initial visible UI readiness.
- Keep runtime endpoint override and Windows tunnel behavior unchanged.

Expected result: fewer duplicate `/v1/users/:uid`, group info, and metadata calls during the first conversation screen and rebuilds.

### 3. Flutter conversation list rendering

The conversation list already uses row-key providers, but each row still resolves channel, cached message, fresh message, reminders, optional user info, optional group info, and member info. Some of these are independent and can be parallelized or cached.

Design changes:

- Add a `ConversationMetadataResolver` boundary responsible for user/group/channel display metadata, in-flight dedupe, and small LRU/TTL caching.
- Keep row fallback rendering immediate, then update row data asynchronously.
- Parallelize independent row reads where safe: channel, cached message, fresh message, reminders, member info, and metadata fallback.
- Avoid refresh-token invalidation that reloads all expensive row data when only one lightweight field changed.
- Add unit tests around request-key stability, metadata coalescing, fallback behavior, and no-fetch cases for system/file-helper/current-user conversations.

Expected result: smoother list scrolling and reduced rebuild-triggered async work.

### 4. Flutter chat timeline and local message merge

The chat timeline uses local SQLite pages and then merges/refines messages. Current merge and upsert helpers scan lists repeatedly and can degrade as visible message count grows.

Design changes:

- Replace repeated linear duplicate detection in message merge/upsert with an identity-indexed merge helper.
- Preserve current precedence semantics: client sequence, client message number, message ID, message sequence, order sequence, then richer message state/extra version.
- Keep state immutable from the provider perspective, but avoid repeated full-list scans inside one merge operation.
- Bound work during `loadMore` and incoming-message apply so a single new message does not repeatedly compare against every visible item when an index can answer the match.
- Continue recording SQLite page query telemetry by mode.

Expected result: lower CPU cost when opening busy conversations, loading older pages, or applying bursty incoming messages.

### 5. Backend/API low-risk performance work

Backend code review showed message sync and extra sync are already mostly batch-oriented, but there are areas that need measurement before refactor.

First-cycle backend changes:

- Add HTTP metrics middleware and route normalization.
- Add operation-level timers around message sync, channel sync, message extra sync, conversation sync, realtime ack/pull, and file upload.
- Add structured warning logs only for slow operations over a configurable threshold. The log must include operation name and duration, not payload content.
- Keep existing SQL behavior unless metrics/slow logs prove a specific query is slow.
- Validate that source migration indexes are applied in production before adding any new migration.

Candidate second-step improvements after measurement:

- Replace correlated member-read subqueries in message-extra queries with joins or pre-aggregated batch reads if they show up in slow metrics.
- Reduce Redis writes for high-frequency realtime telemetry or session ack paths if they become bottlenecks.
- Replace 5-second realtime session polling with event-driven invalidation if session invalidation latency or Redis polling load becomes material.

### 6. Nginx and public edge tuning

Nginx currently handles HTTPS, WSS, API, MinIO, LiveKit, and static admin/web assets. Logs show scanning traffic and some nonstandard WebSocket probes.

Design changes:

- Keep the existing `/ws` and `/v1/realtime/session/` WebSocket proxy behavior but add explicit observability for 101/4xx/5xx counts.
- Add conservative rate limits for login and obvious scanner paths without blocking legitimate app traffic.
- Add static asset caching for immutable Flutter/web/admin assets when paths are safe to cache.
- Keep upload buffering disabled for `/v1/file/upload` and preserve current upload timeout behavior unless measurements prove it problematic.
- Consider restricting direct public WuKongIM TCP/WS ports only after verifying all clients can use the intended route. This is not a first-cycle default because current Flutter config still uses direct `wemx.cc:5100` as preferred TCP route.

### 7. Database and Redis

The current production data volume is small, so database changes must be evidence-driven.

Design changes:

- Add a repeatable read-only index/table-size verification script.
- Keep MySQL slow query logging enabled with a documented threshold.
- Confirm whether `message-20260423-02.sql`-style indexes are applied for all message partitions and `conversation_extra`.
- Do not add indexes until a query is observed slow at realistic volume.
- Record Redis memory, connected clients, ops/sec, keyspace, and slowlog in baseline snapshots.

### 8. Load testing and benchmarks

Use staged load tests after instrumentation exists.

Baseline scenarios:

1. Login and device bind.
2. IM route fetch and conversation sync.
3. Message sync and channel message paging.
4. Message extra sync and read/unread operations.
5. File upload with representative image size.
6. WebSocket connect/hold/reconnect for realtime session and WuKongIM route where tooling supports it.

Load tests must report:

- Request rate, success rate, p50/p95/p99 latency, and error response body class.
- Host CPU, memory, swap, disk IO, network, socket counts, and Docker container stats.
- Redis and MySQL basic health during the run.
- Nginx upstream 4xx/5xx and timeout counts.

## Data Flow Details

### Startup flow

1. Auth state resolves stored API token, IM token, UID, and device session ID.
2. IM setup starts and route resolution fetches `/v1/users/:uid/im` if needed.
3. Session runtime starts `/v1/realtime/session/events/ws` with protobuf control preference.
4. WKIM connects and completes sync.
5. Non-blocking sync tasks run for reminders, sensitive words, prohibit words, conversation extras, and offline commands.
6. Conversation list reads local SDK conversations and row metadata resolver fills display data.

Optimization keeps the order but separates visible readiness from background follow-up work.

### Conversation row flow

1. Row receives stable conversation key and preferred metadata maps.
2. Immediate fallback tile renders.
3. Resolver loads channel/message/reminder/member and metadata in parallel with in-flight dedupe.
4. Row updates only when resolved display data changes.

### Chat timeline flow

1. Latest/older/around-anchor page loads from local history gateway.
2. Messages are filtered for displayable content.
3. Indexed merge resolves duplicates while preserving existing message preference logic.
4. Viewport controller receives incoming/older/refresh decisions and applies minimal updates.

### Backend metrics flow

1. Middleware starts a timer at request entry.
2. Handler executes unchanged business logic.
3. Middleware records route/method/status/duration after response.
4. Operation-specific timers record domain latencies where route-level data is insufficient.
5. Metrics endpoint exposes aggregate counters/histograms without payloads.

## Error Handling

- Client metadata resolver failures return null/fallback values and must not block conversation row rendering.
- Client telemetry upload failures keep current buffering semantics and must not break IM connection.
- Backend metrics failures must never fail user requests.
- Backend slow-operation logging must be best-effort and non-blocking.
- Load-test scripts must fail closed if target/base URL or credentials are missing.
- Production deployment scripts must print the exact service/container changed and the rollback command.

## Rollback Design

Flutter rollback:

- Revert the performance patch commit or disable new resolver/cache with a runtime flag if introduced.
- Existing direct API paths remain unchanged, so fallback behavior is the current behavior.

Backend rollback:

- Metrics middleware can be disabled by config/env or reverted in the backend image.
- Nginx changes must be backed up before reload and validated with `nginx -t`.
- No first-cycle schema mutation is planned, avoiding database rollback risk.

Production rollback:

- Do not restart Docker globally for first-cycle app changes unless required.
- For Compose/Nginx changes, keep timestamped backups in the production deployment directory.
- Verify rollback with health checks: `/v1/ping`, WuKongIM `/health`, Nginx HTTPS, and a client login/sync smoke test.

## Testing Strategy

### Flutter tests

- Metadata resolver coalesces duplicate user/group requests.
- Conversation row falls back immediately when metadata fails.
- Existing system/file-helper/current-user no-fetch rules remain intact.
- Indexed message merge matches the existing preference semantics.
- Message list load latest, load more, and refresh behavior remains stable.
- Existing parity tests continue to pass.

### Backend tests

- Metrics middleware records status, method, normalized route, and latency without touching response bodies.
- Metrics endpoint does not expose request payload or secrets.
- Realtime operation metrics count connect attempts/successes, decode errors, and gap repair pulls.
- Slow-operation logger emits only safe fields.

### Ops validation

- Nginx config test before reload.
- Docker Compose config validation if Compose files change.
- Read-only production snapshot before and after deployment.
- Smoke tests for login, device bind, route fetch, conversation sync, message sync, and file upload.
- Load test after instrumentation to establish baseline and post-change comparison.

## Implementation Slices

### Slice 1: Baseline and metrics

- Add backend HTTP metrics middleware and protected metrics exposure.
- Add operation timers for core IM endpoints.
- Add scripts/runbook for read-only production snapshot and baseline capture.
- Validate with backend tests and smoke checks.

### Slice 2: Flutter low-risk hot paths

- Add conversation metadata resolver with in-flight dedupe/cache.
- Parallelize safe row data reads.
- Add indexed message merge/upsert helper.
- Add tests covering behavior equivalence and reduced duplicate fetches.

### Slice 3: Nginx and edge hygiene

- Add conservative scanner/login protections and static caching where safe.
- Preserve WebSocket and upload semantics.
- Validate with `nginx -t`, reload, and smoke tests.

### Slice 4: Load-test closure

- Run baseline scenarios.
- Compare before/after metrics.
- Produce a follow-up recommendation: stay single-node with tuned settings, scale vertically, or plan WuKongIM/backend split.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Hidden dependency on direct TCP/WS route | Do not restrict public ports until client route usage is measured. |
| Metrics label cardinality explosion | Use route templates and operation names only; no UID/channel/message labels. |
| Row metadata cache shows stale names/avatars | Keep TTL small and refresh on explicit conversation/list refresh tokens. |
| Indexed merge changes message ordering | Preserve existing preference functions and add equivalence tests using current edge cases. |
| Production backend source is not git-managed | Patch through local repo or explicit remote backup/deploy scripts; never edit remote blindly. |
| Current workspace has unrelated changes | Stage only files owned by the implementation slice; do not reset or overwrite unrelated work. |
| Load tests affect real users | Run small baseline first, then ramp during approved windows with clear stop criteria. |

## Acceptance Criteria

The first cycle is complete when:

- Backend exposes safe request/operation metrics or equivalent structured metric logs.
- A production baseline report exists with host/container/API/client observations.
- Flutter tests prove duplicate metadata fetches are coalesced and message merge semantics are preserved.
- Conversation list and chat timeline optimizations pass existing relevant tests.
- Nginx/app changes have documented rollback commands.
- A post-change report compares baseline and optimized runs and identifies the next scaling decision.
