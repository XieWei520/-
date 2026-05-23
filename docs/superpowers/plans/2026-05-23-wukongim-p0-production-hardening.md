# WuKongIM P0 Production Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current single-node WuKongIM production deployment into a gate-checked, backup-evidenced, observability-ready baseline before any larger performance or HA work.

**Architecture:** Keep production mutations explicit and reversible: local scripts default to dry-run, remote checks are read-only unless a task explicitly requires `-Run -AllowProductionWrites`, and every production action leaves evidence under a timestamped directory. P0 work is split into release gates, backup evidence, and observability bootstrap so each piece can be tested and committed independently.

**Tech Stack:** PowerShell ops scripts, SSH to Ubuntu production host, Docker Compose, Bash, MySQL `mysqldump`, Redis `redis-cli --rdb`, Prometheus, Grafana, node-exporter, cAdvisor, Flutter test harness for script contract tests.

---

## File Structure

- `scripts/ops/p0_production_readiness_gate.ps1`: Read-only P0 production readiness gate. It must not mutate production and must fail on missing P0 prerequisites.
- `scripts/ops/p0_create_backup_evidence.ps1`: Explicit production backup evidence creator. It must default to dry-run and require `-Run -AllowProductionWrites` before writing remote backup files.
- `scripts/ops/p0_observability_preflight.ps1`: Static and remote read-only observability preflight. It must validate local config and inspect remote state without starting services.
- `deploy/production/docker-compose.observability.yaml`: Optional Docker Compose overlay for Prometheus, Grafana, node-exporter, and cAdvisor.
- `deploy/production/monitoring/prometheus.yml`: Prometheus scrape configuration for host, Docker, WuKongIM, and Nginx-adjacent metrics targets.
- `test/scripts/ops/p0_production_readiness_gate_test.dart`: Contract tests for P0 ops scripts and config safety.
- `docs/superpowers/plans/2026-05-23-wukongim-p0-production-hardening.md`: This execution plan and checkpoint record.

## Current Checkpoint

Already completed before this plan was formalized:

- [x] Commit `73618dbc chore: harden p0 production readiness gate`
  - Fixed Windows PowerShell 5.1 SSH process argument compatibility.
  - Made P0 gate fail on dirty local worktree, missing recent backup evidence, and missing Prometheus/Grafana inventory.
  - Verified with `flutter test test\scripts\ops\p0_production_readiness_gate_test.dart`.
- [x] Commit `2a1edd62 chore: add p0 backup and observability ops`
  - Added backup evidence script, observability compose overlay, Prometheus config, and observability preflight.
  - Verified dry-run behavior and script contract tests.

Production state from Task 4 P0 gate:

- [x] Local worktree clean.
- [x] Containers healthy enough for smoke and WSS checks.
- [x] `/v1/ping` returns `{"status":200}`.
- [x] `/ws` handshake returns `101 Switching Protocols`.
- [x] Recent backup evidence exists under `/opt/wukongim-prod/backups`.
- [x] Sysctl backup evidence exists under `/var/backups/wukongim-sysctl`.
- [ ] Observability stack missing on production.
- [ ] `scripts/ops/p0_observability_preflight.ps1 -Run` now checks remote `data/prometheus` and `data/grafana` directory ownership/writeability against the container UIDs before any rollout.

---

### Task 1: P0 Gate Compatibility And Strictness

**Files:**
- Modify: `scripts/ops/p0_production_readiness_gate.ps1`
- Modify: `test/scripts/ops/p0_production_readiness_gate_test.dart`

- [x] **Step 1: Write failing test for PowerShell 5.1 SSH argument compatibility**

Add to `test/scripts/ops/p0_production_readiness_gate_test.dart`:

```dart
test('p0 production readiness gate uses Windows PowerShell compatible ssh arguments', () {
  final script = File('scripts/ops/p0_production_readiness_gate.ps1');

  expect(script.existsSync(), isTrue);

  final content = script.readAsStringSync();
  expect(content, contains(r'$startInfo.Arguments ='));
  expect(content, isNot(contains(r'$startInfo.ArgumentList.Add')));
});
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
```

Expected before implementation: FAIL because the script uses `$startInfo.ArgumentList.Add(...)`.

- [x] **Step 3: Implement compatible SSH argument construction**

In `scripts/ops/p0_production_readiness_gate.ps1`, replace `ArgumentList.Add(...)` calls with:

```powershell
$startInfo.Arguments = "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -- $RemoteHost bash -s"
```

- [x] **Step 4: Write failing test for strict release prerequisites**

Add to `test/scripts/ops/p0_production_readiness_gate_test.dart`:

```dart
test('p0 production readiness gate fails on missing release prerequisites', () {
  final script = File('scripts/ops/p0_production_readiness_gate.ps1');

  expect(script.existsSync(), isTrue);

  final content = script.readAsStringSync();
  expect(content, contains('local_worktree_dirty=true'));
  expect(content, contains('git status --porcelain'));
  expect(content, contains('backup_artifacts_missing=true'));
  expect(content, contains('backup_path_missing='));
  expect(content, contains('observability_stack_missing=true'));
  expect(content, contains('prometheus'));
  expect(content, contains('grafana'));
});
```

- [x] **Step 5: Implement strict gate failures**

In `scripts/ops/p0_production_readiness_gate.ps1`:

```powershell
Invoke-ReadOnlyGate -Name 'local_git_status' -Command {
  git status --short --branch
  $dirty = git status --porcelain
  if (-not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))) {
    'local_worktree_dirty=true'
    $global:LASTEXITCODE = 1
  }
}
```

In the remote backup gate, fail when backup directories are missing or no recent file exists:

```bash
missing=0
for path in /opt/wukongim-prod/backups /var/backups/wukongim-sysctl; do
  if [ -d "$path" ]; then
    echo "backup_path=$path"
    recent_count=$(find "$path" -maxdepth 2 -type f -mtime -14 | wc -l)
    echo "backup_recent_file_count=$recent_count"
    find "$path" -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort | tail -20
    if [ "$recent_count" -eq 0 ]; then
      echo "backup_recent_artifacts_missing=$path"
      missing=1
    fi
  else
    echo "backup_path_missing=$path"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo 'backup_artifacts_missing=true'
  exit 1
fi
```

In the remote observability gate, fail when Prometheus or Grafana is missing:

```bash
observability_services=$(docker compose ps | grep -Ei 'prometheus|grafana|node-exporter|cadvisor' || true)
printf '%s\n' "$observability_services"
printf '%s\n' "$observability_services" | grep -qi 'prometheus' || missing_prometheus=1
printf '%s\n' "$observability_services" | grep -qi 'grafana' || missing_grafana=1
if [ "${missing_prometheus:-0}" -ne 0 ] || [ "${missing_grafana:-0}" -ne 0 ]; then
  echo 'observability_stack_missing=true'
  exit 1
fi
```

- [x] **Step 6: Verify gate script and tests**

Run:

```powershell
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_production_readiness_gate.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_production_readiness_gate.ps1 -Run
```

Expected after implementation:

- Flutter test PASS.
- Dry-run prints `Dry run only. Add -Run to execute read-only P0 production readiness gate.`
- Production gate fails only on real P0 gaps.

- [x] **Step 7: Commit**

Run:

```powershell
git add scripts\ops\p0_production_readiness_gate.ps1 test\scripts\ops\p0_production_readiness_gate_test.dart
git diff --cached --check
git diff --cached | python scripts\ops\secret_log_scan.py --source staged-p0-gate-diff
git commit -m "chore: harden p0 production readiness gate"
```

Expected: commit `73618dbc`.

---

### Task 2: P0 Backup Evidence Script

**Files:**
- Create: `scripts/ops/p0_create_backup_evidence.ps1`
- Modify: `test/scripts/ops/p0_production_readiness_gate_test.dart`

- [x] **Step 1: Write failing test for backup evidence script contract**

Add:

```dart
test('p0 backup evidence script is explicit, scoped, and checksummed', () {
  final script = File('scripts/ops/p0_create_backup_evidence.ps1');

  expect(script.existsSync(), isTrue);

  final content = script.readAsStringSync();
  expect(content, contains(r'[switch]$Run'));
  expect(content, contains(r'[switch]$AllowProductionWrites'));
  expect(content, contains('Dry run only.'));
  expect(content, contains('Refusing to write production backups without -AllowProductionWrites'));
  expect(content, contains('/opt/wukongim-prod/backups'));
  expect(content, contains('/var/backups/wukongim-sysctl'));
  expect(content, contains('backup_manifest.txt'));
  expect(content, contains('sha256sum'));
  expect(content, contains('mysqldump'));
  expect(content, contains('redis-cli'));
  expect(content, contains('tar'));
  expect(content, contains('docker compose --env-file .env exec -T mysql'));
  expect(content, contains('docker compose --env-file .env exec -T redis'));
  expect(content, contains(r'"`$1"'));
  expect(content, contains(r'sh "`$MYSQL_DATABASE"'));
  expect(content, contains(r'REDISCLI_AUTH="`$REDIS_PASSWORD"'));
  expect(content, isNot(contains('redis-cli -a')));
  expect(content, contains('Validate-RemoteHostToken'));
  expect(content, contains('Quote-Bash'));
  expect(content, contains('BatchMode=yes'));

  expect(content, isNot(contains('DROP ')));
  expect(content, isNot(contains('DELETE ')));
  expect(content, isNot(contains('UPDATE ')));
  expect(content, isNot(contains('INSERT ')));
  expect(content, isNot(contains('ALTER ')));
  expect(content, isNot(contains('CREATE DATABASE')));
  expect(content, isNot(contains('TRUNCATE ')));
});
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
```

Expected before implementation: FAIL because `scripts/ops/p0_create_backup_evidence.ps1` does not exist.

- [x] **Step 3: Create backup evidence script**

Create `scripts/ops/p0_create_backup_evidence.ps1` with:

```powershell
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$BackupRoot = '/opt/wukongim-prod/backups',
  [string]$SysctlBackupRoot = '/var/backups/wukongim-sysctl',
  [string]$SshKeyPath = '',
  [switch]$Run,
  [switch]$AllowProductionWrites
)
```

The implementation must:

- Default to dry-run.
- Refuse writes unless both `-Run` and `-AllowProductionWrites` are present.
- Use safe SSH host token validation.
- Quote Bash parameters with `Quote-Bash`.
- Use `mysqldump` with database name passed as `"$1"`.
- Use Redis `REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --rdb -`, not `redis-cli -a`.
- Write timestamped artifacts under a path shaped like `/opt/wukongim-prod/backups/p0-readiness-YYYYmmddTHHMMSSZ`, where the timestamp is generated by `date -u +%Y%m%dT%H%M%SZ`.
- Write sysctl evidence under `/var/backups/wukongim-sysctl`.
- Write `backup_manifest.txt` and `.sha256` files.

- [x] **Step 4: Write failing dry-run regression for shell parameter preservation**

Add:

```dart
test('p0 backup evidence dry run preserves remote shell parameters', () {
  final result = Process.runSync(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'scripts/ops/p0_create_backup_evidence.ps1',
    ],
  );

  expect(result.exitCode, 0);
  final output = '${result.stdout}\n${result.stderr}';
  expect(output, contains(r'"$1"'));
  expect(output, isNot(contains(r'-p"$MYSQL_ROOT_PASSWORD" ""')));
  expect(output, contains(r'REDISCLI_AUTH="$REDIS_PASSWORD"'));
  expect(output, isNot(contains('redis-cli -a')));
});
```

- [x] **Step 5: Verify dry-run and tests**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_create_backup_evidence.ps1
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
```

Expected:

- Dry-run prints remote script without executing production writes.
- Output contains `"$1"` in the `mysqldump` command.
- Output contains `REDISCLI_AUTH="$REDIS_PASSWORD"`.
- Flutter test PASS.

- [x] **Step 6: Execute production backup evidence after explicit approval**

Only run this step after the user explicitly approves production writes.

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_create_backup_evidence.ps1 -Run -AllowProductionWrites
```

Expected:

- A new `/opt/wukongim-prod/backups/p0-readiness-YYYYmmddTHHMMSSZ` directory exists; copy the exact directory from the script output line that starts with `backup_manifest.txt=`.
- MySQL dump file exists and has a `.sha256`.
- Redis RDB file exists and has a `.sha256`.
- Runtime config archive exists and has a `.sha256`.
- WuKongIM data archive exists and has a `.sha256`.
- `/var/backups/wukongim-sysctl/p0-readiness-YYYYmmddTHHMMSSZ.txt` exists and has a `.sha256`; use the same timestamp emitted by the script output.
- Output includes a concrete `backup_manifest.txt=/opt/wukongim-prod/backups/p0-readiness-YYYYmmddTHHMMSSZ/backup_manifest.txt` line.

- [x] **Step 7: Verify backup evidence with P0 gate**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_production_readiness_gate.ps1 -Run
```

Expected after Step 6:

- `remote_backup_artifact_audit` no longer fails.
- `remote_observability_inventory` may still fail until Task 5 is executed.

- [x] **Step 8: Commit local script and tests**

Run:

```powershell
git add test\scripts\ops\p0_production_readiness_gate_test.dart scripts\ops\p0_create_backup_evidence.ps1
git diff --cached --check
git diff --cached | python scripts\ops\secret_log_scan.py --source staged-p0-backup-diff
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
git commit -m "chore: add p0 backup and observability ops"
```

Expected: included in commit `2a1edd62`.

---

### Task 3: Observability Stack Config And Preflight

**Files:**
- Create: `deploy/production/docker-compose.observability.yaml`
- Create: `deploy/production/monitoring/prometheus.yml`
- Create: `scripts/ops/p0_observability_preflight.ps1`
- Modify: `test/scripts/ops/p0_production_readiness_gate_test.dart`

- [x] **Step 1: Write failing test for observability config**

Add:

```dart
test('p0 observability stack config is private and preflighted', () {
  final compose = File('deploy/production/docker-compose.observability.yaml');
  final prometheus = File('deploy/production/monitoring/prometheus.yml');
  final script = File('scripts/ops/p0_observability_preflight.ps1');

  expect(compose.existsSync(), isTrue);
  expect(prometheus.existsSync(), isTrue);
  expect(script.existsSync(), isTrue);

  final composeContent = compose.readAsStringSync();
  expect(composeContent, contains('prometheus'));
  expect(composeContent, contains('grafana'));
  expect(composeContent, contains('node-exporter'));
  expect(composeContent, contains('cadvisor'));
  expect(composeContent, contains('127.0.0.1:9090:9090'));
  expect(composeContent, contains('127.0.0.1:3000:3000'));
  expect(composeContent, isNot(contains('0.0.0.0:9090')));
  expect(composeContent, isNot(contains('0.0.0.0:3000')));

  final prometheusContent = prometheus.readAsStringSync();
  expect(prometheusContent, contains('host.docker.internal:5001'));
  expect(prometheusContent, contains('cadvisor:8080'));
  expect(prometheusContent, contains('node-exporter:9100'));

  final scriptContent = script.readAsStringSync();
  expect(scriptContent, contains(r'[switch]$Run'));
  expect(scriptContent, contains('Dry run only.'));
  expect(scriptContent, contains('docker compose'));
  expect(scriptContent, contains('config'));
  expect(scriptContent, contains('local_docker_cli_missing=true'));
  expect(scriptContent, contains('local_compose_config_skipped=true'));
  expect(scriptContent, contains('StrictHostKeyChecking=accept-new'));
  expect(scriptContent, contains('Validate-RemoteHostToken'));
  expect(scriptContent, isNot(contains('docker compose up')));
  expect(scriptContent, isNot(contains('docker compose restart')));
  expect(scriptContent, isNot(contains('systemctl restart')));
});
```

- [x] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
```

Expected before implementation: FAIL because observability files do not exist.

- [x] **Step 3: Add observability compose overlay**

Create `deploy/production/docker-compose.observability.yaml` with services:

```yaml
services:
  prometheus:
    image: prom/prometheus:v2.55.1
    ports:
      - "127.0.0.1:9090:9090"

  grafana:
    image: grafana/grafana:11.3.1
    ports:
      - "127.0.0.1:3000:3000"

  node-exporter:
    image: prom/node-exporter:v1.8.2

  cadvisor:
    image: ghcr.io/google/cadvisor:0.55.1
```

The actual file must include persistent volumes and exporter mount points, but must not expose Prometheus or Grafana on `0.0.0.0`.

- [x] **Step 4: Add Prometheus config**

Create `deploy/production/monitoring/prometheus.yml` with scrape jobs:

```yaml
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: [prometheus:9090]
  - job_name: node-exporter
    static_configs:
      - targets: [node-exporter:9100]
  - job_name: cadvisor
    static_configs:
      - targets: [cadvisor:8080]
  - job_name: wukongim
    metrics_path: /varz
    static_configs:
      - targets: [host.docker.internal:5001]
```

- [x] **Step 5: Add read-only preflight script**

Create `scripts/ops/p0_observability_preflight.ps1` that:

- Validates local files exist.
- Fails if `0.0.0.0:9090` or `0.0.0.0:3000` appears.
- Runs local `docker compose config` when Docker CLI exists.
- Prints `local_docker_cli_missing=true` and `local_compose_config_skipped=true` when Docker CLI is unavailable.
- Defaults to dry-run.
- With `-Run`, checks remote production files and current listening ports but does not start services.

- [x] **Step 6: Verify preflight**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_observability_preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_observability_preflight.ps1 -Run
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
```

Expected:

- Local dry-run passes even if Docker CLI is absent.
- Remote `-Run` reports `remote_observability_compose_missing=true` until deployment files are copied.
- Flutter test PASS.

Observed after permission-risk hardening:

- `-Run` also checks `data/prometheus` for UID/GID `65534:65534` and `data/grafana` for UID/GID `472:0` using `stat -c '%u %g %a'`.
- The directory check is for actual writeability: it uses POSIX owner/group/other precedence, and the selected class must have write + execute/search permission before the path is treated as usable.
- If either directory exists and is not writable by the target container identity, the preflight exits non-zero and prints a readable `remote_observability_data_permissions=...:fail` reason.
- If both directories do not exist yet, the preflight may additionally print `remote_observability_data_permissions_skipped=true`, but it still prints the unified success marker `remote_observability_data_permissions=ok`.

- [x] **Step 7: Commit local config and tests**

Run:

```powershell
git add deploy\production\docker-compose.observability.yaml deploy\production\monitoring\prometheus.yml scripts\ops\p0_observability_preflight.ps1 test\scripts\ops\p0_production_readiness_gate_test.dart
git diff --cached --check
git diff --cached | python scripts\ops\secret_log_scan.py --source staged-p0-observability-diff
flutter test test\scripts\ops\p0_production_readiness_gate_test.dart
git commit -m "chore: add p0 backup and observability ops"
```

Expected: included in commit `2a1edd62`.

---

### Task 4: Production Backup Evidence Execution

**Files:**
- No local file changes expected.
- Remote writes under `/opt/wukongim-prod/backups` and `/var/backups/wukongim-sysctl`.

- [x] **Step 1: Confirm explicit production write approval**

Ask the user:

```text
是否允许我执行生产备份证据生成？这会通过 SSH 在生产服务器写入备份文件，但不会重启服务或修改配置。
```

Required answer before continuing: explicit approval.

- [x] **Step 2: Run production backup evidence script**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_create_backup_evidence.ps1 -Run -AllowProductionWrites
```

Expected:

- Exit code `0`.
- Output includes:
  - `mysql_backup_done=...`
  - `redis_backup_done=...`
  - `runtime_config_archive_done=...`
  - `wukongim_data_archive_done=...`
  - `sysctl_backup_done=...`
  - `backup_manifest.txt=...`

- [x] **Step 3: Re-run P0 readiness gate**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_production_readiness_gate.ps1 -Run
```

Expected:

- `remote_backup_artifact_audit` is absent from `failed-gates`.
- `remote_observability_inventory` may still fail.

- [x] **Step 4: Record evidence in plan**

Update this file under "Execution Evidence" with:

```markdown
- Backup evidence generated at the exact path copied from the `backup_manifest.txt=` output line.
- P0 gate evidence directory copied from the `Evidence:` line printed by `scripts\ops\p0_production_readiness_gate.ps1 -Run`.
- Remaining failed gates copied from the `failed-gates:` line printed by `scripts\ops\p0_production_readiness_gate.ps1 -Run`.
```

- [x] **Step 5: Commit plan evidence**

Run:

```powershell
git add docs\superpowers\plans\2026-05-23-wukongim-p0-production-hardening.md
git commit -m "docs: record p0 backup evidence"
```

Expected: one documentation-only commit.

---

### Task 5: Observability Deployment Rollout

**Files:**
- Local source already prepared:
  - `deploy/production/docker-compose.observability.yaml`
  - `deploy/production/monitoring/prometheus.yml`
- Remote files need to be copied to `/opt/wukongim-prod/src/deploy/production`.

- [ ] **Step 1: Confirm explicit observability deployment approval**

Ask the user:

```text
是否允许我把观测栈配置复制到生产服务器并启动 Prometheus/Grafana/node-exporter/cAdvisor？Prometheus 和 Grafana 会绑定 127.0.0.1:9090/3000，不对公网暴露。
```

Required answer before continuing: explicit approval.

- [ ] **Step 2: Copy observability files to production**

Run:

```powershell
scp deploy\production\docker-compose.observability.yaml ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/docker-compose.observability.yaml
ssh ubuntu@42.194.218.158 "mkdir -p /opt/wukongim-prod/src/deploy/production/monitoring"
scp deploy\production\monitoring\prometheus.yml ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/monitoring/prometheus.yml
```

Expected:

- Files exist remotely.
- No services restarted yet.

- [ ] **Step 3: Run remote observability preflight**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_observability_preflight.ps1 -Run
```

Expected:

- `remote_observability_compose_config=ok`.
- No `0.0.0.0:9090` or `0.0.0.0:3000` listener.

- [ ] **Step 4: Start observability stack**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose -f docker-compose.yaml -f docker-compose.observability.yaml up -d prometheus grafana node-exporter cadvisor"
```

Expected:

- Four observability containers are running.
- Existing IM/API/MySQL/Redis/MinIO/LiveKit/Coturn containers are not recreated.

- [ ] **Step 5: Verify private listeners**

Run:

```powershell
ssh ubuntu@42.194.218.158 "ss -ltnup | grep -E ':(9090|3000)\b' || true"
```

Expected:

- Prometheus and Grafana listen on `127.0.0.1:9090` and `127.0.0.1:3000`.
- They do not listen on `0.0.0.0`.

- [ ] **Step 6: Re-run P0 readiness gate**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\p0_production_readiness_gate.ps1 -Run
```

Expected after Tasks 4 and 5:

- `p0_readiness=pass`.
- `failed-gates.txt` contains `PASS`.

- [ ] **Step 7: Record evidence and commit docs**

Update this file under "Execution Evidence" with:

```markdown
- Observability stack started at the UTC timestamp printed by `date -u +%Y-%m-%dT%H:%M:%SZ` immediately after `docker compose ... up -d`.
- Private listener evidence copied from the `ss -ltnup | grep -E ':(9090|3000)\b' || true` command output.
- P0 gate evidence directory copied from the `Evidence:` line printed by `scripts\ops\p0_production_readiness_gate.ps1 -Run`.
- Final P0 readiness: pass.
```

Run:

```powershell
git add docs\superpowers\plans\2026-05-23-wukongim-p0-production-hardening.md
git commit -m "docs: record p0 observability rollout"
```

Expected: one documentation-only commit.

---

## Execution Evidence

- 2026-05-23: P0 gate hardening committed as `73618dbc`.
- 2026-05-23: P0 backup and observability ops committed as `2a1edd62`.
- 2026-05-23: Production backup script hardening committed as `3845a559`, `5a5c47e5`, `213155ff`, and `d0b1c590` after production permission, stdin, Redis auth, and protected data archive issues were found during Task 4 execution.
- 2026-05-23: Production backup evidence generated at `/opt/wukongim-prod/backups/p0-readiness-20260523T111507Z/backup_manifest.txt`.
- 2026-05-23: Task 4 P0 gate evidence directory: `C:\Users\COLORFUL\Desktop\WuKong\build\p0-production-readiness\20260523-192039`.
- 2026-05-23: Task 4 P0 gate remaining failed gates: `remote_observability_inventory`; `remote_backup_artifact_audit` no longer failed.
- 2026-05-23: Earlier read-only P0 gate evidence showed remaining failed gates: `remote_backup_artifact_audit`, `remote_observability_inventory`.

---

## Self-Review

**Spec coverage:** Covers the P0 items from the optimization blueprint: release gate, backup evidence, observability baseline, read-only production inspection, and explicit production approval boundaries.

**Red-flag scan:** No implementation task relies on empty future-fill markers. Tasks 4 and 5 are intentionally pending because they require explicit production write/deployment approval.

**Production permission note:** The immediate remediation for the current Prometheus/Grafana bind-mount mismatch is a minimal ownership fix on the remote host: `data/prometheus -> 65534:65534` and `data/grafana -> 472:0`. The preflight now catches this drift before rollout by checking permissions according to POSIX owner/group/other precedence, including the directory execute/search bits needed for actual writes.

**Type and command consistency:** Script names, file paths, and test commands match files already present in the workspace. PowerShell commands use Windows path separators where run locally. Remote commands use Linux paths.
