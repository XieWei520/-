# Phase 6 Sync Hot Path Optimization Rollout

This runbook deploys the Phase 6 backend-only sync hot path batch. It does not require a Windows, web, or Android client rebuild.

## Preconditions

Run:

```powershell
flutter test test/scripts/ops/phase6_sql_migration_lint_test.dart test/scripts/ops/phase6_backend_service_switch_test.dart test/scripts/ops/phase6_prometheus_gate_report_test.dart test/scripts/ops/phase6_sync_hot_path_prepare_test.dart

Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestPhase6|TestSyncSensitiveWords|TestProhibit|TestBuildUserLastOffsets|TestClearSyncConversationCache'
Pop-Location
```

## Baseline

Run:

```powershell
.\scripts\ops\phase6_prometheus_gate_report.ps1 -Run
```

Record the 5-minute and 30-minute values before switching.

## Dry Run

```powershell
.\scripts\ops\phase6_sql_migration_lint.ps1
.\scripts\ops\phase6_sync_hot_path_prepare.ps1
```

The prepare dry run must print `phase6_sync_hot_path_reviewed_manifest=verified` and `phase6_sync_hot_path_build_context_manifest=verified`.

## Sync Source And Build

```powershell
.\scripts\ops\phase6_sync_hot_path_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Record the backup directory, absent-files manifest, build-context marker, and previous image tag printed by the script.

## Switch Service

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

The switch script recreates `tsdd-api` and `callgateway`, waits for container health, proves internal `/v1/ping`, runs `nginx -t`, restarts nginx, proves external `/v1/ping`, and checks recent nginx 502s.

## Immediate Gate

Run the 5-minute Prometheus gate immediately after switch:

```powershell
.\scripts\ops\phase6_prometheus_gate_report.ps1 -Run
```

Rollback immediately if:

- API target is not up.
- Any 5xx appears.
- `route="unknown"` increases.
- External `/v1/ping` fails.
- nginx logs show 502 after the switch timestamp.

## 30-Minute Gate

Observe the same PromQL for 30 minutes.

Rollback if p95 or p99 for changed hot routes is greater than 1.5x baseline for two consecutive checks. Hold and investigate if the regression is between 1.2x and 1.5x.

## Rollback

Use the exact values recorded during `phase6_sync_hot_path_prepare.ps1`:

- `phase6_sync_hot_path_sync_backup_dir`
- `phase6_sync_hot_path_absent_files_manifest`
- `phase6_sync_hot_path_previous_image_tag`

Restore the source tree on the production host:

```powershell
$backupDir = '<phase6_sync_hot_path_sync_backup_dir>'
$absentManifest = '<phase6_sync_hot_path_absent_files_manifest>'

ssh ubuntu@42.194.218.158 @"
set -euo pipefail
backup_dir='$backupDir'
absent_manifest='$absentManifest'
source_root='/opt/wukongim-prod/src'
test -d "`$backup_dir"
test -f "`$absent_manifest"

cd "`$backup_dir"
find . -type f ! -name '.phase6_sync_hot_path_absent_files' -print0 | while IFS= read -r -d '' file; do
  relative_path="`${file#./}"
  case "`$relative_path" in
    /*|*..*|*'\'*|'')
      echo "unsafe rollback file path: `$relative_path" >&2
      exit 1
      ;;
  esac
  mkdir -p "`$source_root/`$(dirname "`$relative_path")"
  cp -p "`$file" "`$source_root/`$relative_path"
done

while IFS= read -r relative_path; do
  [ -n "`$relative_path" ] || continue
  case "`$relative_path" in
    /*|*..*|*'\'*|'')
      echo "unsafe absent file path: `$relative_path" >&2
      exit 1
      ;;
  esac
  rm -f "`$source_root/`$relative_path"
done < "`$absent_manifest"
"@
```

Restore the previous production image tag:

```powershell
$previousImageTag = '<phase6_sync_hot_path_previous_image_tag>'
ssh ubuntu@42.194.218.158 "docker tag '$previousImageTag' wukongim/tsdd-api:production-local"
```

Switch services back through the guarded script:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

Repeat the immediate and 30-minute Prometheus gates after rollback:

```powershell
.\scripts\ops\phase6_prometheus_gate_report.ps1 -Run
```
