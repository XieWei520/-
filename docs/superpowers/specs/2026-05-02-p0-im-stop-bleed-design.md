# P0 IM Stop-Bleed Design

> Date: 2026-05-02  
> Scope: IM system P0 stop-bleed package for production validation, secret-log safety, coturn reliability, and call fallback throttling.  
> Approved approach: Minimal stop-bleed first.

## 1. Goal

Make the production release path trustworthy and remove the highest-risk operational hazards before deeper IM refactoring begins.

This design covers only P0 work:

1. Release smoke/perf validation must use the public HTTPS path for production checks and must fail with actionable guidance when HTTP/308 is misused.
2. Sensitive logs must be detectable without printing raw secrets; current WuKongIM `actToken` leakage must be captured as a release-blocking risk until the image/source path can be remediated.
3. coturn TLS/DTLS must start cleanly with valid certificate/private-key configuration and no unsupported config warnings.
4. Pending-call HTTP fallback must stop behaving like a permanent 2-second background poll; it should run only after realtime/gateway degradation and then use exponential backoff.

## 2. Non-Goals

This package deliberately does not include:

- Splitting `lib/service/im/im_service.dart`.
- Implementing Web IndexedDB chat storage.
- Adding Redis Streams or backend side-effect workers.
- Implementing large-file multipart upload.
- Replacing or rebuilding the upstream WuKongIM official image unless a separate source/build workflow is approved.
- Reworking LiveKit UI or full call telemetry beyond the fallback loop required for P0 load reduction.

## 3. Current Findings

Local and remote read-only exploration found these P0-relevant facts:

- Remote production runs under `/opt/wukongim-prod/src/deploy/production` on `ubuntu@42.194.218.158`.
- `http://127.0.0.1/` through production Nginx returns `308` to `https://infoequity.qingyunshe.top/`; production gate scripts must not treat HTTP as the canonical public release path.
- Remote `wukongim_prod-wukongim-1` logs still include raw `actToken` fields in token verification failures.
- Remote coturn logs still include `Bad configuration format: no-loopback-peers` and private-key/TLS listener warnings.
- Local `PendingCallRecoveryLoop` already has degradation-aware machinery, but its default `enableSafetyPolling` is still `true` and the default non-degraded interval is still 2 seconds.
- Web cache, SQLite indexes, and message envelope work are partially present elsewhere, but are not part of this P0 design.

## 4. Architecture

### 4.1 Release Validation Layer

Production validation should flow through the public HTTPS endpoint:

```text
operator/runbook
  -> smoke_test.py / perf_probe.py / production_doctor.py
  -> normalize and validate base_url
  -> reject risky production HTTP usage or explain HTTP 308
  -> HTTPS public endpoint
  -> API result and latency summary
```

Design requirements:

- `smoke_test.py` and `perf_probe.py` keep local/container HTTP support only for explicit local health probes.
- Public release validation defaults to `TSDD_BASE_URL` when it is present; production `.env` already uses `https://infoequity.qingyunshe.top`.
- If an operator provides `http://...` for a public production host, the scripts produce an actionable error that includes the HTTPS equivalent.
- If a request receives HTTP `308`, output the attempted URL, the redirect target, and the corrected command shape.
- Local `scripts/ops/remote_redeploy.sh` must not hard-code `http://127.0.0.1` as the production smoke/perf gate.

### 4.2 Sensitive Log Gate

Sensitive log checks should classify dangerous fields without exposing their values:

```text
docker compose logs
  -> secret log scanner
  -> classify allowed metadata vs raw secret leak
  -> report service / field / redacted sample / remediation owner
```

Design requirements:

- A scanner reports fields such as `actToken`, `expectToken`, `password`, `secret`, `Authorization`, `api_key`, and `credential` without printing complete values.
- Samples must be redacted before they are shown in terminal output or written to docs.
- Current WuKongIM `actToken` leakage is treated as a P0 finding even if the running image is upstream and not directly editable from this Flutter repository.
- Controllable local scripts and docs should avoid adding new raw secret output.

### 4.3 coturn Infrastructure Layer

coturn validation should be configuration-first and reversible:

```text
backup current production config
  -> inspect rendered turnserver.conf and compose mounts
  -> update template/rendered config
  -> docker compose config
  -> restart coturn only
  -> scan coturn logs
  -> STUN/TURN/TURNS probe
```

Design requirements:

- Remove or conditionally omit `no-loopback-peers` because the current image reports it as bad configuration format.
- Ensure the configured certificate and private-key paths match container-mounted files.
- Ensure permissions allow the coturn process to read the private key without printing key contents.
- Restart only the coturn service for this change.
- Keep a timestamped backup under `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-YYYYMMDD-HHMMSS` before any remote mutation.

### 4.4 Client Pending-Call Fallback Layer

Pending-call recovery should be degradation-only by default:

```text
realtime/session healthy
  -> no /v1/extra/call/pending loop

gateway degraded for at least 6s
  -> GET /v1/extra/call/pending?fallback=1
  -> delay 2s -> 5s -> 15s -> 30s -> 60s
  -> stop when realtime recovers, app backgrounds, or a call becomes active
```

Design requirements:

- `PendingCallRecoveryLoop.enableSafetyPolling` defaults to `false`.
- The default backoff schedule is `2s, 5s, 15s, 30s, 60s`.
- Foreground-only behavior is preserved.
- The request still passes `fallback=true` so the server can distinguish degradation reads from primary realtime delivery.
- Tests can still inject fast delays and custom schedules.

## 5. Error Handling

### Release validation

- HTTP public URL: fail with a short explanation and suggested HTTPS URL.
- HTTP 308 response: fail with redirect details and corrected command guidance.
- Network failure: preserve existing timeout/status reporting.

### Sensitive log scan

- Scanner never outputs full secret values.
- Scanner exits non-zero when high-risk raw-secret fields are detected.
- Scanner distinguishes current upstream-image leakage from local repo/script leakage so ownership is clear.

### coturn

- Missing certificate or private key: report path and file metadata only.
- Permission problem: report user/group/mode, not file content.
- Bad configuration warning after restart: restore from backup and report failed check.
- Probe failure: classify as port unreachable, TLS handshake failure, or auth failure when possible.

### Client fallback

- Single HTTP failure does not create a tight retry loop.
- App backgrounding stops the loop.
- Active call state stops pending-call polling.
- Realtime recovery resets attempts.

## 6. Testing Strategy

### Flutter tests

Update `test/modules/video_call/call_runtime_recovery_test.dart` to prove:

- Default pending-call recovery no longer uses safety polling.
- Gateway not degraded means zero pending-call fetches.
- Gateway degraded means fetch runs with `fallback=true`.
- Default backoff schedule is exactly `2s, 5s, 15s, 30s, 60s`.

### Script tests

Add or update tests for:

- Base URL normalization and HTTP/308 guidance in smoke/perf tooling.
- Secret log scanner redaction behavior.
- Secret log scanner detects a representative `actToken` log line without printing its raw value.

### Remote checks

Run, capture, and summarize:

- Pre-change secret log scan.
- Pre-change coturn warning scan.
- `docker compose --env-file .env config`.
- Post-change coturn warning scan.
- STUN/TURN/TURNS probe outputs.
- HTTPS smoke/perf command outputs.

## 7. Release and Rollback

### Release sequence

1. Commit local code/script/test changes.
2. Back up remote production config under `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-YYYYMMDD-HHMMSS`.
3. Apply remote production script/config changes.
4. Run `docker compose --env-file .env config`.
5. Restart coturn only when coturn config changed.
6. Run post-change scans and probes.
7. Write a local verification report under `docs/`.

### Rollback

- coturn failure: copy backed-up `turnserver.conf` and related files back, then restart coturn.
- script failure: restore backed-up scripts; this does not affect running API/MySQL/Redis services.
- Flutter fallback regression: revert the local commit; no remote production mutation is needed.

## 8. Acceptance Criteria

The P0 stop-bleed package is accepted when:

1. Release smoke/perf commands use HTTPS by default for production and explain HTTP/308 mistakes clearly.
2. Secret log scanning redacts output and detects the existing WuKongIM `actToken` leakage.
3. coturn logs no longer show `Bad configuration format: no-loopback-peers` after the config change.
4. coturn logs no longer show private-key/TLS listener disabled warnings after the config change.
5. STUN/TURN/TURNS checks produce explicit pass/fail results.
6. Default client pending-call recovery does not poll while realtime/gateway is healthy.
7. Focused Flutter and script tests pass.
8. Remote changes are backed up and reversible.
