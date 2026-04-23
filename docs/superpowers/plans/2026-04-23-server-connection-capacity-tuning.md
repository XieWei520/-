# Server Connection Capacity Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tune the production IM host and deployment config so the long-connection gateway has a safer kernel/network baseline and explicit container descriptor limits, without changing the existing client/server protocol contract.

**Architecture:** This plan separates the work into four stages: capture evidence and backups first, apply host kernel tuning second, make the Docker Compose runtime ceiling explicit third, and finish with before/after operational verification plus rollback notes. The implementation is intentionally operational and remote-first; the only local repo artifact is a rollout report that records exact commands, backup paths, and observed improvements.

**Tech Stack:** PowerShell, SSH, Docker Compose, Linux sysctl, WuKongIM deployment YAML

---

## File Structure

- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\server-connection-capacity-tuning\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md`
  Responsibility: capture the exact baseline, backup paths, applied values, and before/after verification evidence for this remote slice
- Modify remotely: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
  Responsibility: declare explicit `ulimits.nofile` for the network-facing services so the current high runtime ceiling is configuration-backed
- Create remotely: `/etc/sysctl.d/99-wukongim-connection-capacity.conf`
  Responsibility: apply the socket backlog, conntrack, keepalive, and ephemeral port-range tuning values

### Task 1: Capture Baseline And Create Rollout Evidence

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\server-connection-capacity-tuning\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md`

- [ ] **Step 1: Create the rollout report scaffold**

```markdown
# Server Connection Capacity Tuning Rollout Report

## Baseline

### Host Limits

### Container Limits

### Compose Status

## Backups

## Applied Changes

## Post-Change Verification

## Rollback Notes
```

- [ ] **Step 2: Capture the current host baseline**

Run:

```powershell
ssh ubuntu@42.194.218.158 "ulimit -n; echo '---'; sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.ip_local_port_range; echo '---'; free -h; echo '---'; ss -s"
```

Expected:
- host `ulimit -n` prints `1024`
- `tcp_max_syn_backlog` prints `512`
- `tcp_keepalive_time` prints `7200`
- `ss -s` shows the current TCP socket summary

- [ ] **Step 3: Capture the current container descriptor limits and compose health**

Run:

```powershell
ssh ubuntu@42.194.218.158 "docker exec wukongim_prod-wukongim-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-nginx-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-tsdd-api-1 sh -lc 'ulimit -n' && echo '---' && cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
```

Expected:
- the three container `ulimit -n` values print `1048576`
- `docker compose ps` shows `wukongim`, `nginx`, `tsdd-api`, and `callgateway` healthy/up

- [ ] **Step 4: Record the exact baseline outputs in the rollout report**

Run:

```powershell
$report = '.\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md'
$hostBaseline = ssh ubuntu@42.194.218.158 "ulimit -n; echo '---'; sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.ip_local_port_range; echo '---'; free -h; echo '---'; ss -s"
$containerBaseline = ssh ubuntu@42.194.218.158 "docker exec wukongim_prod-wukongim-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-nginx-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-tsdd-api-1 sh -lc 'ulimit -n'"
$composePs = ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
Add-Content -Path $report -Value @"

### Host Limits
```text
$hostBaseline
```

### Container Limits
```text
$containerBaseline
```

### Compose Status
```text
$composePs
```
"@
```

- [ ] **Step 5: Commit the baseline report scaffold and captured evidence**

```powershell
git add .\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md
git commit -m "docs: capture connection tuning baseline"
```

### Task 2: Back Up And Apply Host Sysctl Tuning

**Files:**
- Modify remotely: `/etc/sysctl.d/99-wukongim-connection-capacity.conf`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\server-connection-capacity-tuning\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md`

- [ ] **Step 1: Create a timestamped rollback directory and back up any overlapping server files**

Run:

```powershell
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = "/opt/wukongim-prod/rollback_snapshots/task2_connection_capacity_$ts"
ssh ubuntu@42.194.218.158 "sudo mkdir -p $backupDir && sudo cp -a /opt/wukongim-prod/src/deploy/production/docker-compose.yaml $backupDir/docker-compose.yaml.bak && if [ -f /etc/sysctl.d/99-wukongim-connection-capacity.conf ]; then sudo cp -a /etc/sysctl.d/99-wukongim-connection-capacity.conf $backupDir/99-wukongim-connection-capacity.conf.bak; fi && echo $backupDir"
```

Expected:
- command prints the created rollback directory path
- `docker-compose.yaml.bak` exists inside that directory

- [ ] **Step 2: Write the host sysctl tuning file**

Run:

```powershell
ssh ubuntu@42.194.218.158 @"
sudo tee /etc/sysctl.d/99-wukongim-connection-capacity.conf >/dev/null <<'EOF'
fs.file-max = 1048576
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 524288
EOF
"@
```

- [ ] **Step 3: Apply the sysctl file and verify the new values are live**

Run:

```powershell
ssh ubuntu@42.194.218.158 "sudo sysctl --system >/tmp/wk-sysctl-apply.log && sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.ip_local_port_range"
```

Expected:
- `net.core.somaxconn = 65535`
- `net.ipv4.tcp_max_syn_backlog = 16384`
- `net.netfilter.nf_conntrack_max = 524288`
- `net.ipv4.tcp_keepalive_time = 120`
- `net.ipv4.tcp_keepalive_intvl = 30`
- `net.ipv4.tcp_keepalive_probes = 5`
- `net.ipv4.ip_local_port_range = 10240 65535`

- [ ] **Step 4: Record the backup path and applied sysctl values in the rollout report**

Run:

```powershell
$report = '.\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md'
if (-not $backupDir) { throw 'backupDir must still be set from Step 1.' }
Add-Content -Path $report -Value @"

## Backups
- rollback directory: $backupDir
- backed up:
  - /opt/wukongim-prod/src/deploy/production/docker-compose.yaml
  - /etc/sysctl.d/99-wukongim-connection-capacity.conf (if it existed)

## Applied Changes

### Host Sysctl File
```text
fs.file-max = 1048576
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 524288
```
"@
```

- [ ] **Step 5: Commit the report update for host tuning**

```powershell
git add .\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md
git commit -m "docs: record host connection tuning changes"
```

### Task 3: Make The High Descriptor Ceiling Explicit In Compose

**Files:**
- Modify remotely: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\server-connection-capacity-tuning\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md`

- [ ] **Step 1: Confirm the current compose file does not explicitly declare `ulimits` for the target services**

Run:

```powershell
ssh ubuntu@42.194.218.158 "grep -n 'ulimits:' /opt/wukongim-prod/src/deploy/production/docker-compose.yaml || true"
```

Expected:
- no relevant `ulimits:` block is printed for `nginx`, `wukongim`, `tsdd-api`, or `callgateway`

- [ ] **Step 2: Patch `docker-compose.yaml` so the network-facing services declare `nofile = 1048576`**

Run:

```powershell
ssh ubuntu@42.194.218.158 @"
python3 - <<'PY'
from pathlib import Path
path = Path('/opt/wukongim-prod/src/deploy/production/docker-compose.yaml')
text = path.read_text()
targets = {
    '  nginx:\\n': "  nginx:\\n    ulimits:\\n      nofile:\\n        soft: 1048576\\n        hard: 1048576\\n",
    '  wukongim:\\n': "  wukongim:\\n    ulimits:\\n      nofile:\\n        soft: 1048576\\n        hard: 1048576\\n",
    '  tsdd-api:\\n': "  tsdd-api:\\n    ulimits:\\n      nofile:\\n        soft: 1048576\\n        hard: 1048576\\n",
    '  callgateway:\\n': "  callgateway:\\n    ulimits:\\n      nofile:\\n        soft: 1048576\\n        hard: 1048576\\n",
}
for old, new in targets.items():
    if new in text:
        continue
    if old not in text:
        raise SystemExit(f'missing service marker: {old!r}')
    text = text.replace(old, new, 1)
path.write_text(text)
PY
"@
```

- [ ] **Step 3: Validate the compose file and recreate only the affected services**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env config >/tmp/wk-compose-config.log && docker compose --env-file .env up -d --force-recreate nginx wukongim tsdd-api callgateway && docker compose --env-file .env ps"
```

Expected:
- `docker compose config` succeeds
- `nginx`, `wukongim`, `tsdd-api`, and `callgateway` return to `Up` / `healthy`

- [ ] **Step 4: Verify the container descriptor ceilings after recreation**

Run:

```powershell
ssh ubuntu@42.194.218.158 "docker exec wukongim_prod-wukongim-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-nginx-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-tsdd-api-1 sh -lc 'ulimit -n' && echo '---' && docker exec wukongim_prod-callgateway-1 sh -lc 'ulimit -n'"
```

Expected:
- all four services print `1048576`

- [ ] **Step 5: Record the compose change and post-recreate health in the rollout report**

Run:

```powershell
$report = '.\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md'
$composePsAfter = ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
Add-Content -Path $report -Value @"

### Compose `ulimits`
- `nginx`: `nofile soft/hard 1048576`
- `wukongim`: `nofile soft/hard 1048576`
- `tsdd-api`: `nofile soft/hard 1048576`
- `callgateway`: `nofile soft/hard 1048576`

## Post-Change Verification

### Service Health
```text
$composePsAfter
```
"@
```

- [ ] **Step 6: Commit the report update for compose hardening**

```powershell
git add .\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md
git commit -m "docs: record compose connection hardening"
```

### Task 4: Verify Before/After Improvement And Lock Rollback Notes

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\server-connection-capacity-tuning\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md`

- [ ] **Step 1: Re-run the operational verification matrix**

Run:

```powershell
ssh ubuntu@42.194.218.158 "ulimit -n; echo '---'; sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.ip_local_port_range; echo '---'; cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps; echo '---'; docker exec wukongim_prod-wukongim-1 sh -lc 'ulimit -n'; echo '---'; ss -s; echo '---'; docker logs --tail 100 wukongim_prod-wukongim-1 2>&1"
```

Expected:
- new sysctl values stay active
- `docker compose ps` remains healthy
- `docker exec ... ulimit -n` prints `1048576`
- no new startup/config errors appear in the latest gateway logs

- [ ] **Step 2: Add the before/after comparison and rollback section to the rollout report**

Append:

```markdown
## Post-Change Verification

### Before / After
- host `ulimit -n`: `1024` -> `1024` (interactive shell unchanged; tuning is kernel and container focused)
- `net.core.somaxconn`: `4096` -> `65535`
- `net.ipv4.tcp_max_syn_backlog`: `512` -> `16384`
- `net.netfilter.nf_conntrack_max`: `262144` -> `524288`
- `net.ipv4.tcp_keepalive_time`: `7200` -> `120`
- `net.ipv4.tcp_keepalive_intvl`: `75` -> `30`
- `net.ipv4.tcp_keepalive_probes`: `9` -> `5`
- `net.ipv4.ip_local_port_range`: `32768 60999` -> `10240 65535`
- `wukongim` container `ulimit -n`: `1048576` -> `1048576` (now explicit in Compose)

## Rollback Notes
- restore the backup compose file recorded under `## Backups`
- remove or restore `/etc/sysctl.d/99-wukongim-connection-capacity.conf`
- run `sudo sysctl --system`
- run `docker compose --env-file .env up -d --force-recreate nginx wukongim tsdd-api callgateway`
```

- [ ] **Step 3: Record the explicit non-goals for this slice**

```markdown
## Non-Goals Confirmed
- `/v1/users/{uid}/im` contract was not changed
- no MySQL schema or index changes were made
- no Redis data model changes were made
- ports `5100` and `5200` remain open in this slice
- cluster mode is still disabled
```

- [ ] **Step 4: Commit the final rollout report**

```powershell
git add .\docs\superpowers\artifacts\2026-04-23-server-connection-capacity-tuning-rollout.md
git commit -m "docs: finalize connection tuning rollout report"
```
