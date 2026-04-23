# WuKongIM Host Tuning Notes

## Scope

This runbook manages:

- `/etc/sysctl.d/99-wukongim.conf`
- `/etc/security/limits.d/wukongim-nofile.conf`
- `/etc/systemd/system/docker.service.d/99-wukongim-nofile.conf`

The scripts are designed for reversible tuning during load-test preparation.

## Prerequisites

- Linux host with `sudo` privileges.
- `systemd` + Docker deployment (`systemctl` and `docker` available).
- Maintenance window approved. `apply_im_sysctl.sh` and `rollback_im_sysctl.sh` both restart Docker.
- Scripts available on host:
  - `scripts/ops/apply_im_sysctl.sh`
  - `scripts/ops/rollback_im_sysctl.sh`
  - `scripts/ops/observe_im_host.sh`
- Backup directory write access (default: `/var/backups/wukongim-sysctl`).

## Maintenance Warning

Applying or rolling back host tuning triggers:

1. `systemctl daemon-reload`
2. `systemctl restart docker`

Containerized services will be interrupted during Docker restart. Execute only in a maintenance window.

## Pre-Change Baseline (Captured 2026-04-17)

Captured from:

```bash
ssh ubuntu@42.194.218.158 "ulimit -n && sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.ip_local_port_range && free -h"
```

Observed values:

```text
ulimit -n: 1024
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 512
net.netfilter.nf_conntrack_max = 262144
net.ipv4.tcp_keepalive_time = 7200
net.ipv4.ip_local_port_range = 32768 60999
Mem total/used/free/buff-cache/available = 7.5Gi / 1.7Gi / 1.5Gi / 4.6Gi / 5.8Gi
Swap total/used/free = 1.9Gi / 1.9Gi / 20Mi
```

## Apply

From repo root on the target host:

```bash
sudo bash ./scripts/ops/apply_im_sysctl.sh
```

Optional custom backup directory:

```bash
sudo bash ./scripts/ops/apply_im_sysctl.sh /var/backups/wukongim-sysctl
```

Expected side effects:

- Writes tuned sysctl file to `/etc/sysctl.d/99-wukongim.conf`.
- Writes nofile limits to `/etc/security/limits.d/wukongim-nofile.conf`.
- Writes Docker drop-in to `/etc/systemd/system/docker.service.d/99-wukongim-nofile.conf`.
- Applies sysctl via `sysctl -p /etc/sysctl.d/99-wukongim.conf` (targeted file only).
- Restarts Docker and prints `LimitNOFILE`.
- Prints the generated transaction state file path. Keep this path for rollback.

## Rollback

Recommended transaction-pinned rollback (explicit state file from apply output):

```bash
sudo bash ./scripts/ops/rollback_im_sysctl.sh /var/backups/wukongim-sysctl /var/backups/wukongim-sysctl/apply-state.<timestamp>.env
```

If you omit the state file argument:

- rollback is allowed only when exactly one `apply-state.*.env` exists in the backup directory.
- rollback fails when multiple state files exist, and prints candidate paths (no guessing).

Rollback semantics:

- If a backup exists for a managed file, restore it.
- If the managed file did not exist before apply, remove the file created by apply.
- Restores runtime sysctl values for all managed keys from captured state via explicit `sysctl -w`.
- If the managed sysctl file was restored, reapplies it with `sysctl -p` so persisted and runtime state match.
- Docker is reloaded/restarted after rollback, then `LimitNOFILE` is shown.

## Backup And State Files

Each apply run creates timestamped backups and a state file in the backup directory:

- `99-wukongim.conf.bak.<timestamp>`
- `wukongim-nofile.conf.bak.<timestamp>`
- `99-wukongim-nofile.conf.bak.<timestamp>`
- `apply-state.<timestamp>.env`

State file records:

- Whether each managed file existed before apply.
- The backup path used for each managed file (if any).
- Pre-apply runtime values for tuned sysctl keys.

Rollback uses the explicit state file argument (or a single unambiguous state file) to decide restore vs remove behavior.

## Observation Loop During Load Test

Use the host observer in a separate terminal:

```bash
sudo bash ./scripts/ops/observe_im_host.sh 5
```

## Why These Settings Matter

- `nofile`: long-lived IM websocket connections consume file descriptors first; raising this avoids early connection caps.
- `net.core.somaxconn` and `net.ipv4.tcp_max_syn_backlog`: absorb connect bursts and reduce accept/SYN queue pressure during ramp-up.
- `net.netfilter.nf_conntrack_max`: prevents conntrack saturation under high connection churn/NAT traffic.
- `net.ipv4.tcp_keepalive_time`, `net.ipv4.tcp_keepalive_intvl`, `net.ipv4.tcp_keepalive_probes`: detect dead peers faster so stale sessions are reclaimed sooner.

## Post-Checks

Run after apply and after rollback:

- `ulimit -n`
- `sysctl fs.file-max`
- `sysctl net.core.somaxconn`
- `sysctl net.ipv4.tcp_max_syn_backlog`
- `sysctl net.ipv4.ip_local_port_range`
- `sysctl net.ipv4.tcp_fin_timeout`
- `sysctl net.ipv4.tcp_keepalive_time`
- `sysctl net.ipv4.tcp_keepalive_intvl`
- `sysctl net.ipv4.tcp_keepalive_probes`
- `sysctl net.netfilter.nf_conntrack_max`
- `ss -s`
- `free -h`
- `systemctl show docker --property LimitNOFILE`
- `systemctl is-active docker`
- `docker ps --format 'table {{.Names}}\t{{.Status}}'`

Rollback file-state verification (using transaction state file):

- `grep -E 'SYSCTL_FILE_EXISTED|LIMITS_FILE_EXISTED|DOCKER_OVERRIDE_FILE_EXISTED' /var/backups/wukongim-sysctl/apply-state.<timestamp>.env`
- If `SYSCTL_FILE_EXISTED=1`, `/etc/sysctl.d/99-wukongim.conf` should exist; if `0`, it should be absent.
- If `LIMITS_FILE_EXISTED=1`, `/etc/security/limits.d/wukongim-nofile.conf` should exist; if `0`, it should be absent.
- If `DOCKER_OVERRIDE_FILE_EXISTED=1`, `/etc/systemd/system/docker.service.d/99-wukongim-nofile.conf` should exist; if `0`, it should be absent.
- `sudo test -f /etc/sysctl.d/99-wukongim.conf && echo present || echo absent`
- `sudo test -f /etc/security/limits.d/wukongim-nofile.conf && echo present || echo absent`
- `sudo test -f /etc/systemd/system/docker.service.d/99-wukongim-nofile.conf && echo present || echo absent`

If you run WuKongIM with Docker Compose, also verify from the deployment directory:

- `docker compose --env-file .env ps`
