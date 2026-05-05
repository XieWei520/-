# Phase 5 Release Preflight

This runbook is the Phase 5 quality gate for production releases. Operators should use the one-key preflight command below and keep its evidence directory with the release record. A release is blocked unless every required gate passes.

## One-key command

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1
```

For local script verification without production SSH probes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1 -SkipRemote
```

The command writes evidence to:

```text
build/phase5-preflight/<timestamp>/
```

## Required local evidence

The evidence directory must include:

- `local_git_status.txt`
- `flutter_analyze.txt`
- `flutter_phase5_tests.txt`

## Required remote production evidence

The evidence directory must include:

- `remote_docker_compose_config.txt`
- `remote_nginx_syntax.txt`
- `remote_smoke_test.txt`
- `remote_public_web_smoke.txt`
- `remote_websocket_handshake.txt`
- `server_sql_gate.txt`

The `server_sql_gate.txt` file is produced by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_server_sql_gate.ps1
```

It is a read-only SQL/slow-query gate against `/opt/wukongim-prod/src`. It blocks release on high-risk SQL construction findings or missing slow-query evidence.

## Failure handling

- Analyzer failure blocks merge and release.
- Flutter Phase 5 test failure blocks merge and release.
- Docker Compose config failure blocks production deploy.
- Nginx syntax failure blocks production deploy.
- Smoke or websocket failure blocks production deploy until a fresh passing preflight directory is captured.
- SQL gate failure blocks production deploy until findings are triaged in the backend source or the gate is intentionally adjusted with reviewed evidence.
- The script writes `failed-gates.txt`; if it contains anything other than `PASS`, the release is blocked.

## Safety boundary

The Phase 5 preflight is read-only. It must not restart containers, reload Nginx, mutate backend files, or deploy artifacts.
