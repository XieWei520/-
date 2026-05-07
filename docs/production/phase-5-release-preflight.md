# Phase 5 Release Preflight

This runbook is the Phase 5 quality gate for production releases. A release is not ready if any required evidence below is missing.

## Required local evidence

Run from the repository root:

```powershell
flutter analyze
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected result:

- `flutter analyze` prints `No issues found!`.
- Cache tests print `All tests passed!`.

## Required remote production evidence

Current production host context: `ubuntu@42.194.218.158`.

Validate Docker Compose rendering:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose config >/tmp/wukongim-compose-rendered.yml && test -s /tmp/wukongim-compose-rendered.yml"
```

Validate Nginx syntax:

```powershell
ssh ubuntu@42.194.218.158 "docker exec wukongim-prod-nginx nginx -t"
```

Validate public web and websocket smoke checks by running the existing baseline collector with remote checks enabled:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/collect_im_performance_baseline.ps1 -SkipFlutterBuild
```

The generated `build/performance-baseline/<timestamp>` directory must include:

- `flutter_analyze.txt`
- `flutter_test_smoke.txt`
- `remote_docker_status.txt`
- `remote_nginx_config.txt`
- `remote_public_web_smoke.txt`
- `remote_websocket_handshake.txt`
- `remote_recent_nginx_log.txt`
- `remote_recent_api_log.txt`

## Failure handling

- Analyzer failure blocks merge and release.
- Cache test failure blocks merge and release.
- Docker Compose or Nginx syntax failure blocks production deploy.
- Smoke failure blocks production deploy until the failure is triaged and a fresh passing baseline directory is captured.
- Telemetry upload failures must not break the IM runtime, but release evidence must include the failed upload symptom and fallback behavior.

## Phase 5 follow-up backlog

After this gate is green, continue Phase 5 with separate slices for:

1. Motion token naming alignment (`fast`, `normal`, `pressedScale`).
2. Send-state visual semantics (clock, single gray check, double gray check, double blue check).
3. Frame timing/Jank telemetry and dashboard queries.
