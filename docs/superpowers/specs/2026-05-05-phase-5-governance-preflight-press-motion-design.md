# Phase 5 Governance Preflight and Press Motion Design

## Context

Phase 5 is the continuing visual-experience, monitoring, and long-term-governance phase for the IM system. The previous Phase 5 slices already delivered motion token naming, outgoing send-state visual semantics, and chat frame jank telemetry on the Flutter client. The remaining gap is the operational side of the Phase 5 quality lifeline: release checks are documented, but there is no single local command that fails the release when SQL safety, slow-query evidence, docker-compose rendering, Nginx syntax, and smoke checks are missing or broken.

A small visual gap also remains in the chat composer. The send button already has an inline press scale path and a `ChatMotionDurations.pressedScale` token exists, but the implementation still uses an ad-hoc duration and the regression test only checks that the scale is below one. Phase 5 should make that micro-interaction explicit and governed by the motion token system.

## Goals

1. Add a repeatable Phase 5 server SQL/slow-query gate that can run from this Flutter repository while inspecting the production Go backend checkout over SSH.
2. Add a single release preflight command that runs local Flutter gates plus remote docker-compose, Nginx, smoke, websocket, and SQL gates, then stores durable evidence under `build/phase5-preflight/<timestamp>`.
3. Tighten the chat send-button press micro-interaction so the enabled pressed state scales to exactly `0.92` and uses `ChatMotionDurations.pressedScale` for duration.
4. Keep all production-server interactions read-only unless the operator explicitly runs a separate deployment command outside this slice.

## Non-Goals

- Do not directly patch Go backend source on the production host.
- Do not restart containers, reload Nginx, or mutate production files.
- Do not introduce a new observability backend or dashboard.
- Do not broaden send-button redesign beyond the existing compact icon button.
- Do not make the SQL scanner a full SQL parser. It should be a conservative release gate with actionable evidence and a clear allowlist path if needed later.

## Recommended Approach

Use **local orchestration with remote read-only probes**.

Two PowerShell scripts should be added under `scripts/ops`:

1. `phase5_server_sql_gate.ps1`
   - Connects to `ubuntu@42.194.218.158` by default.
   - Inspects `/opt/wukongim-prod/src` by default.
   - Runs a remote Bash probe that scans Go files for high-risk raw SQL construction patterns such as `fmt.Sprintf` around SQL keywords, string concatenation adjacent to SQL keywords, and direct `db.Exec` / `db.Query` calls using suspicious dynamic SQL variables.
   - Checks for slow-query evidence by looking for documented/configured slow-query thresholds or MySQL slow-log settings in deploy/config files and, when available, read-only container/config output.
   - Writes `server_sql_gate.txt` and exits non-zero on high-risk findings or missing slow-query evidence.

2. `phase5_release_preflight.ps1`
   - Creates `build/phase5-preflight/<timestamp>` unless an output directory is supplied.
   - Captures each gate into a separate text file with start/end timestamps and exit codes.
   - Runs local gates:
     - `git status --short --branch`
     - `flutter analyze`
     - targeted Phase 5 Flutter tests, including release-script tests and send-button motion tests
   - Runs remote gates:
     - `docker compose config` in the production deploy directory
     - `docker exec wukongim-prod-nginx nginx -t`
     - existing `scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10`
     - public web smoke and websocket handshake probes similar to the existing performance baseline collector
     - `phase5_server_sql_gate.ps1`
   - Fails with a non-zero exit code if any required gate fails.

The existing `scripts/ops/collect_im_performance_baseline.ps1` should remain as a broader evidence collector. The new preflight script is the stricter release blocker.

## UI Motion Design

The active chat composer send button should keep its current structure and hit target. The only behavior changes are:

- Enabled + unpressed scale: `1.0`.
- Enabled + pointer down scale: `0.92`.
- Disabled scale: retain existing disabled compact state unless tests show a conflict.
- Duration: `ChatMotionDurations.pressedScale.resolve(disableAnimations: MediaQuery.disableAnimationsOf(context))`.
- Curve: keep the existing responsive curve unless implementation discovers an existing Phase 5 curve better suited for press feedback.
- Pointer cancel/up must restore the scale to `1.0`.

Tests should assert the exact pressed value and the exact token duration, not just a loose `< 1` predicate.

## Failure Modes and Signals

The preflight scripts must optimize for a future agent diagnosing a failed release:

- Every gate writes a named evidence file.
- Each file includes start time, finish time, and exit code.
- The top-level script prints the output directory and a concise failed-gate summary.
- Remote commands are quoted safely and do not interpolate secrets into logs.
- SQL findings include file path and line number from the remote backend checkout.
- Smoke failures preserve enough HTTP output to identify redirect, TLS, or websocket-handshake failures.

## Testing Strategy

Use TDD for all behavior changes.

- Add/extend Dart tests that read the PowerShell scripts as text and assert the required gates are wired.
- Add/extend widget tests for the chat send button to assert:
  - disabled/empty composer remains compact,
  - enabled unpressed scale is `1.0`,
  - pointer down scale is exactly `0.92`,
  - duration equals `ChatMotionDurations.pressedScale.value`,
  - reduced motion resolves to `Duration.zero` if feasible in the existing test harness.
- Run targeted tests for scripts and chat motion.
- Run `flutter analyze` on touched Dart/Flutter areas.
- Optionally run the new preflight with a skip mode if implementation provides one for local-only verification; do not require mutating production.

## Rollout

1. Land the scripts and tests in the isolated Phase 5 worktree.
2. Run local tests/analyze and keep generated platform registrant files clean.
3. Run the one-key preflight against the production host if SSH remains available and commands are read-only.
4. Document the new command in `docs/production/phase-5-release-preflight.md`.

## Open Decisions Resolved

- The SQL gate is a release blocker, not an automatic backend code fixer.
- Production SSH usage is read-only for this slice.
- The send-button visual scale is exactly `0.92` because the original Phase 5 plan specified that value.
- The implementation will prefer local PowerShell orchestration because the operator is running from Windows and the existing ops scripts already use PowerShell.
