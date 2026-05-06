# WuKongIM Production Assets

## Task Tracking
- Implementation checkpoints: `docs/production/implementation-log.md`
- WuKongIM token redaction deployment verification: `docs/production/2026-05-03-wukongim-token-redaction-verification.md`
- Dirty branch cleanup backup record: `docs/production/2026-05-03-dirty-branch-cleanup.md`
- Monitor Agent pairing production note: `docs/production/2026-05-06-monitor-agent-pairing-production-note.md`

## Operator Entry Points
- Stress testing: `ops/stress/README.md`
- Host tuning: `docs/production/load-test-host-tuning.md`
- Monitoring: `ops/monitoring/docker-compose.yml`
- Dashboard mapping: `docs/production/realtime-dashboard-queries.md`
- Backend metrics: `docs/production/backend-prometheus-instrumentation.md`
- Security: `docs/production/abuse-control-reference.md`
- Sensitive-word filtering: `docs/production/sensitive-word-filtering.md`
- Release: `docs/production/backend-release-runbook.md`

## Current Constraints
- The current production host is single-node and small (`4 vCPU / 7.5 GiB RAM`).
- `wukongim` is still a single long-connection gateway instance.
- Same-host monitoring is a fallback mode, not the preferred final topology.

## Recommended Execution Order

1. `scripts/ops/apply_im_sysctl.sh`
2. `scripts/ops/firewall_apply_ufw.sh`
3. `ops/monitoring/docker-compose.yml`
4. `flutter test` and `dart analyze`
5. `.github/workflows/flutter-android-ci.yml`
6. `scripts/ops/deploy_backend_remote.ps1`
7. `ops/stress/README.md`

## Validation Order

Execution note: this workstation does not provide local `docker` or `bash`, so
Compose rendering and shell syntax checks were validated through remote fallback
commands on `42.194.218.158` after staging the repo assets under `/tmp`.

1. Create and dry-run the Locust suite with a small local sample.
2. Validate sysctl and firewall scripts syntactically before touching the host.
3. Validate monitoring Compose with `docker compose config`.
4. Validate Flutter error-reporting integration with `flutter test` and `dart analyze`.
5. Validate deployment automation with health checks against the confirmed environment target host (current production context: `42.194.218.158`; replace/confirm per environment).
