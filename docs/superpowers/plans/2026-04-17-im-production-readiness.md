# WuKongIM Production Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build repo-tracked stress testing, monitoring, security hardening, and release automation assets that move WuKongIM from a manually operated deployment to a production-ready IM system.

**Architecture:** Keep the current single-host Docker Compose production topology, but add an `ops/` and `scripts/ops/` control plane in the repo. Load is generated externally with Locust, monitoring is layered in with Prometheus/Grafana/Node Exporter, Flutter gets a small error-reporting bootstrap, and backend release safety is codified through firewall and deployment scripts plus runbooks. Because the current workspace is not an active git worktree, each task ends with a verification checkpoint instead of a mandatory commit.

**Tech Stack:** Flutter, Dart, Riverpod, PowerShell, Bash, Python, Locust, Docker Compose, Prometheus, Grafana, UFW, iptables, GitHub Actions, SSH

---

## File Structure And Ownership

### Repo Operations Bundle

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\requirements.txt`
  Responsibility: Python dependencies for websocket load generation.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\locustfile.py`
  Responsibility: 10k-connection Locust user model, heartbeat loop, message send/receive metrics.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\README.md`
  Responsibility: Runbook for local dry-runs and distributed controller/worker execution.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\apply_im_sysctl.sh`
  Responsibility: Apply Linux kernel, conntrack, file-descriptor, and Docker nofile tuning for IM load.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\rollback_im_sysctl.sh`
  Responsibility: Restore backed-up sysctl and limits files after tuning tests.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\observe_im_host.sh`
  Responsibility: Unified host observation loop for pressure testing and rollout windows.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\docker-compose.yml`
  Responsibility: Fallback same-host monitoring stack for Prometheus, Grafana, Node Exporter.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\prometheus\prometheus.yml`
  Responsibility: Scrape configuration for node and IM application metrics.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\grafana\provisioning\datasources\prometheus.yml`
  Responsibility: Grafana datasource provisioning.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\grafana\provisioning\dashboards\default.yml`
  Responsibility: Dashboard provisioning entrypoint.

### Documentation And Runbooks

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\README.md`
  Responsibility: Index page for all production-readiness assets and operator entrypoints.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\implementation-log.md`
  Responsibility: Per-task changed-file and validation checkpoint log for this non-git workspace.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\load-test-host-tuning.md`
  Responsibility: Explain sysctl choices, expected metrics, and rollback guidance.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\realtime-dashboard-queries.md`
  Responsibility: KPI-to-panel mapping aligned with `deploy/dashboard/realtime-kpis.md`.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\backend-prometheus-instrumentation.md`
  Responsibility: Go code snippets for message delivery success and latency metrics plus `/metrics` exposure.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\abuse-control-reference.md`
  Responsibility: Registration throttling, token bucket / leaky bucket pseudocode, and Redis-backed anti-brush strategy.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\sensitive-word-filtering.md`
  Responsibility: Trie-based sensitive-word interception pipeline and moderation handling.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\backend-release-runbook.md`
  Responsibility: Zero/low-downtime release expectations, smoke tests, and rollback steps.

### Flutter Client Integration

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\pubspec.yaml`
  Responsibility: Add `sentry_flutter` dependency.
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\main.dart`
  Responsibility: Route application startup through an error-reporting bootstrap.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\app\bootstrap\error_reporting.dart`
  Responsibility: Conditional Sentry bootstrap and global exception hooks.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\app\bootstrap\error_reporting_test.dart`
  Responsibility: Guard small bootstrap behavior and configuration parsing.

### Security And Release Automation

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\firewall_apply_ufw.sh`
  Responsibility: Default allowlist firewall application for SSH, HTTP(S), IM, TURN, and LiveKit.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\firewall_apply_iptables.sh`
  Responsibility: Equivalent iptables rules for hosts without UFW.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\.github\workflows\flutter-android-ci.yml`
  Responsibility: Push-to-main Flutter test and Android APK build pipeline.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\deploy_backend_remote.ps1`
  Responsibility: Operator workstation entrypoint for remote backup, rebuild, health verification, and rollback validation.
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\remote_redeploy.sh`
  Responsibility: Server-side redeploy helper executed over SSH.

## Task 1: Scaffold The Production Ops Bundle

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\README.md`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\implementation-log.md`

- [ ] **Step 1: Snapshot the missing-asset baseline**

Run:

```powershell
@(
  '.github\workflows\flutter-android-ci.yml',
  'ops\stress\locustfile.py',
  'ops\monitoring\docker-compose.yml',
  'scripts\ops\apply_im_sysctl.sh',
  'scripts\ops\firewall_apply_ufw.sh',
  'scripts\ops\deploy_backend_remote.ps1',
  'docs\production\README.md'
) | ForEach-Object {
  '{0} => {1}' -f $_, (Test-Path -LiteralPath $_)
}
```

Expected:
- Every listed path prints `False`.

- [ ] **Step 2: Create the production documentation index**

```markdown
# WuKongIM Production Assets

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

## Validation Order

1. Create and dry-run the Locust suite with a small local sample.
2. Validate sysctl and firewall scripts syntactically before touching the host.
3. Validate monitoring Compose with `docker compose config`.
4. Validate Flutter error-reporting integration with `flutter test` and `dart analyze`.
5. Validate deployment automation with health checks against `42.194.218.158`.
```

- [ ] **Step 3: Create the non-git checkpoint log**

```markdown
# Production Readiness Implementation Log

| Timestamp (Asia/Shanghai) | Task | Changed files | Validation evidence | Notes |
|---|---|---|---|---|
| 2026-04-17 00:00 | Task 1 scaffold | `docs/production/README.md`, `docs/production/implementation-log.md` | pending | initial scaffold |
```

- [ ] **Step 4: Verify the scaffold exists in the expected directories**

Run:

```powershell
Get-ChildItem -Force '.\docs\production'
```

Expected:
- `README.md`
- `implementation-log.md`

- [ ] **Step 5: Record the Task 1 checkpoint**

Run:

```powershell
Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
```

Expected:
- Use the timestamp to replace the placeholder row in `docs\production\implementation-log.md`.

## Task 2: Build The Locust Websocket Stress Harness

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\requirements.txt`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\locustfile.py`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\stress\README.md`

- [ ] **Step 1: Prove the load harness is not present yet**

Run:

```powershell
python -m py_compile .\ops\stress\locustfile.py
```

Expected:
- Fail with `No such file or directory` or equivalent file-not-found error.

- [ ] **Step 2: Create the Locust dependency manifest**

```text
locust==2.37.10
websocket-client==1.8.0
orjson==3.10.18
```

- [ ] **Step 3: Create the websocket Locust user model**

```python
import json
import os
import random
import time
import uuid

from locust import User, between, events, task
from websocket import WebSocketConnectionClosedException, create_connection

TARGET_WS_URL = os.getenv("TARGET_WS_URL", "ws://127.0.0.1:5200")
HEARTBEAT_INTERVAL_S = float(os.getenv("HEARTBEAT_INTERVAL_S", "25"))
MESSAGE_RATE_PER_USER = float(os.getenv("MESSAGE_RATE_PER_USER", "0.05"))
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "replace-me")


class IMWebSocketUser(User):
    wait_time = between(0.5, 1.5)
    abstract = False

    def on_start(self):
        self.session_id = f"locust-{uuid.uuid4().hex[:12]}"
        self.last_heartbeat_at = 0.0
        self.ws = None
        self._connect()

    def on_stop(self):
        if self.ws is not None:
            self.ws.close()

    def _connect(self):
        started = time.perf_counter()
        exc = None
        try:
            self.ws = create_connection(
                TARGET_WS_URL,
                header=[
                    f"Authorization: Bearer {AUTH_TOKEN}",
                    f"X-Session-ID: {self.session_id}",
                ],
                timeout=10,
            )
            self._send_json({"type": "hello", "session_id": self.session_id}, "hello")
        except Exception as error:
            exc = error
        finally:
            events.request.fire(
                request_type="WS",
                name="connect",
                response_time=(time.perf_counter() - started) * 1000,
                response_length=0,
                exception=exc,
                context={"session_id": self.session_id},
            )
        if exc is not None:
            raise exc

    def _send_json(self, payload, metric_name):
        started = time.perf_counter()
        exc = None
        try:
            if self.ws is None:
                self._connect()
            self.ws.send(json.dumps(payload, ensure_ascii=False))
            self.ws.settimeout(2)
            self.ws.recv()
        except WebSocketConnectionClosedException:
            self._connect()
            exc = RuntimeError("websocket reconnected during send")
        except Exception as error:
            exc = error
        finally:
            events.request.fire(
                request_type="WS",
                name=metric_name,
                response_time=(time.perf_counter() - started) * 1000,
                response_length=len(json.dumps(payload)),
                exception=exc,
                context={"session_id": self.session_id},
            )

    @task(10)
    def heartbeat(self):
        now = time.time()
        if now - self.last_heartbeat_at < HEARTBEAT_INTERVAL_S:
            return
        self.last_heartbeat_at = now
        self._send_json(
            {"type": "heartbeat", "ts_ms": int(now * 1000), "session_id": self.session_id},
            "heartbeat",
        )

    @task(1)
    def business_message(self):
        if random.random() > MESSAGE_RATE_PER_USER:
            return
        now_ms = int(time.time() * 1000)
        self._send_json(
            {
                "type": "chat.message",
                "message_id": uuid.uuid4().hex,
                "channel_id": os.getenv("CHANNEL_ID", "stress-room-01"),
                "from_uid": self.session_id,
                "body": {"type": "text", "content": f"stress-{now_ms}"},
                "client_ts_ms": now_ms,
            },
            "chat.message",
        )
```

- [ ] **Step 4: Create the operator runbook for dry-run and distributed mode**

````markdown
# WuKongIM Locust Stress Runbook

## Local Dry-Run

```powershell
python -m venv .venv
.\.venv\Scripts\pip install -r ops\stress\requirements.txt
$env:TARGET_WS_URL='ws://127.0.0.1:5200'
$env:AUTH_TOKEN='replace-me'
.\.venv\Scripts\locust -f ops\stress\locustfile.py --headless -u 20 -r 5 -t 1m
```

## Distributed 10k Plan

- Controller: `locust -f ops/stress/locustfile.py --master --expect-workers 4`
- Worker x4: `locust -f ops/stress/locustfile.py --worker --master-host <controller-ip>`
- Start with `2k -> 5k -> 10k` connections, not directly 10k.
- Keep aggregate `chat.message` rate near `500 msg/s`.

## Required Dashboards During Run

- `gateway_connect_success_rate`
- `gateway_reconnect_count`
- `message latency p95`
- `CPU / memory / swap / conntrack / socket counts`
````

- [ ] **Step 5: Validate the Python assets**

Run:

```powershell
docker run --rm -v "${PWD}:/work" -w /work python:3.12 sh -lc "pip install -r ops/stress/requirements.txt >/tmp/pip.log && python -m py_compile ops/stress/locustfile.py"
```

Expected:
- `locustfile.py` compiles without syntax errors.

## Task 3: Add Host Tuning And Observation Scripts

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\apply_im_sysctl.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\rollback_im_sysctl.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\observe_im_host.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\load-test-host-tuning.md`

- [ ] **Step 1: Capture the current server baseline before tuning**

Run:

```powershell
ssh ubuntu@42.194.218.158 "ulimit -n && sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_max net.ipv4.tcp_keepalive_time net.ipv4.ip_local_port_range && free -h"
```

Expected:
- Output shows the pre-change values that must be copied into the tuning doc.

- [ ] **Step 2: Create the sysctl apply script**

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-sysctl}"
SYSCTL_FILE="/etc/sysctl.d/99-wukongim.conf"
LIMITS_FILE="/etc/security/limits.d/wukongim-nofile.conf"
DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="${DOCKER_OVERRIDE_DIR}/override.conf"

sudo mkdir -p "${BACKUP_DIR}" "${DOCKER_OVERRIDE_DIR}"
sudo cp -a /etc/sysctl.conf "${BACKUP_DIR}/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)" || true
test -f "${SYSCTL_FILE}" && sudo cp -a "${SYSCTL_FILE}" "${BACKUP_DIR}/99-wukongim.conf.bak.$(date +%Y%m%d%H%M%S)" || true
test -f "${LIMITS_FILE}" && sudo cp -a "${LIMITS_FILE}" "${BACKUP_DIR}/wukongim-nofile.conf.bak.$(date +%Y%m%d%H%M%S)" || true
test -f "${DOCKER_OVERRIDE_FILE}" && sudo cp -a "${DOCKER_OVERRIDE_FILE}" "${BACKUP_DIR}/docker-override.conf.bak.$(date +%Y%m%d%H%M%S)" || true

cat <<'EOF' | sudo tee "${SYSCTL_FILE}" >/dev/null
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

cat <<'EOF' | sudo tee "${LIMITS_FILE}" >/dev/null
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

cat <<'EOF' | sudo tee "${DOCKER_OVERRIDE_FILE}" >/dev/null
[Service]
LimitNOFILE=1048576
EOF

sudo sysctl --system
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show docker --property LimitNOFILE
```

- [ ] **Step 3: Create the rollback script**

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-sysctl}"
LATEST_SYSCTL="$(ls -1t "${BACKUP_DIR}"/99-wukongim.conf.bak.* 2>/dev/null | head -n 1 || true)"
LATEST_LIMITS="$(ls -1t "${BACKUP_DIR}"/wukongim-nofile.conf.bak.* 2>/dev/null | head -n 1 || true)"
LATEST_DOCKER="$(ls -1t "${BACKUP_DIR}"/docker-override.conf.bak.* 2>/dev/null | head -n 1 || true)"

test -n "${LATEST_SYSCTL}" && sudo cp -a "${LATEST_SYSCTL}" /etc/sysctl.d/99-wukongim.conf
test -n "${LATEST_LIMITS}" && sudo cp -a "${LATEST_LIMITS}" /etc/security/limits.d/wukongim-nofile.conf
test -n "${LATEST_DOCKER}" && sudo cp -a "${LATEST_DOCKER}" /etc/systemd/system/docker.service.d/override.conf

sudo sysctl --system
sudo systemctl daemon-reload
sudo systemctl restart docker
```

- [ ] **Step 4: Create the observation loop and the tuning explainer**

```bash
#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${1:-5}"

while true; do
  date '+%F %T'
  echo '== sockets =='
  ss -s
  echo '== conntrack =='
  sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
  echo '== memory =='
  free -h
  echo '== top docker =='
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'
  echo '== vmstat =='
  vmstat 1 2 | tail -n 1
  echo '== disk =='
  df -h /
  echo
  sleep "${INTERVAL}"
done
```

```markdown
# WuKongIM Host Tuning Notes

## Why These Settings Matter

- `nofile`: websocket-heavy IM gateways are file-descriptor bound before they are CPU bound.
- `somaxconn` and `tcp_max_syn_backlog`: reduce connection drops during connect bursts.
- `nf_conntrack_max`: avoids NAT / conntrack exhaustion during 10k-client tests.
- `tcp_keepalive_*`: detects dead mobile sessions faster than the Linux defaults.

## Validation Commands

- `ulimit -n`
- `sysctl net.core.somaxconn`
- `sysctl net.netfilter.nf_conntrack_max`
- `ss -s`
- `free -h`
```

- [ ] **Step 5: Validate the shell scripts syntactically**

Run:

```powershell
docker run --rm -v "${PWD}:/work" -w /work bash:5.2 bash -lc "bash -n scripts/ops/apply_im_sysctl.sh && bash -n scripts/ops/rollback_im_sysctl.sh && bash -n scripts/ops/observe_im_host.sh"
```

Expected:
- No syntax errors from any of the three scripts.

## Task 4: Materialize The Monitoring Stack

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\docker-compose.yml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\prometheus\prometheus.yml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\grafana\provisioning\datasources\prometheus.yml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\ops\monitoring\grafana\provisioning\dashboards\default.yml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\realtime-dashboard-queries.md`

- [ ] **Step 1: Confirm the monitoring bundle is still absent**

Run:

```powershell
docker compose -f .\ops\monitoring\docker-compose.yml config
```

Expected:
- Fail because the compose file does not exist yet.

- [ ] **Step 2: Create the monitoring Compose bundle**

```yaml
services:
  prometheus:
    image: prom/prometheus:v2.54.1
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=3d
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:11.1.3
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: change-me-now
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    ports:
      - "3000:3000"
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:v1.8.2
    restart: unless-stopped
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/)
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"

volumes:
  prometheus-data:
  grafana-data:
```

- [ ] **Step 3: Create the Prometheus and Grafana provisioning files**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: node-exporter
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: wukongim-tsdd
    static_configs:
      - targets: ['host.docker.internal:9102']

  - job_name: wukongim-callgateway
    static_configs:
      - targets: ['host.docker.internal:9103']
```

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

```yaml
apiVersion: 1

providers:
  - name: WuKongIM
    orgId: 1
    folder: WuKongIM
    type: file
    disableDeletion: false
    options:
      path: /etc/grafana/provisioning/dashboards
```

- [ ] **Step 4: Create the KPI-to-panel mapping document**

```markdown
# Realtime Dashboard Queries

## Core Panels

- `gateway_connect_success_rate`
  - Query: `sum(rate(gateway_connect_success_total[5m])) / sum(rate(gateway_connect_attempt_total[5m]))`
- `gateway_reconnect_count p95`
  - Query: `histogram_quantile(0.95, sum(rate(gateway_reconnect_bucket[10m])) by (le))`
- `control_frame_decode_error_count`
  - Query: `sum(rate(control_frame_decode_error_total[5m]))`
- `pull_after_seq_repair_count`
  - Query: `sum(rate(pull_after_seq_repair_total[10m]))`
- `sqlite_page_query_p95_ms`
  - Query: `histogram_quantile(0.95, sum(rate(sqlite_page_query_seconds_bucket[5m])) by (le)) * 1000`
- `conversation_list_patch_apply_p95_ms`
  - Query: `histogram_quantile(0.95, sum(rate(conversation_patch_apply_seconds_bucket[5m])) by (le)) * 1000`

## Derived Rollback Signals

- `decode_error_rate`
- `reconnect_count_p95`
- `gap_repair_rate`

Keep the naming aligned with `deploy/dashboard/realtime-kpis.md`.
```

- [ ] **Step 5: Validate the monitoring bundle**

Run:

```powershell
docker compose -f .\ops\monitoring\docker-compose.yml config
```

Expected:
- Compose renders without schema or path errors.

## Task 5: Integrate Flutter Error Reporting With Sentry

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\pubspec.yaml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\main.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\app\bootstrap\error_reporting.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\app\bootstrap\error_reporting_test.dart`

- [ ] **Step 1: Write the failing bootstrap test first**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/bootstrap/error_reporting.dart';

void main() {
  test('normalizeDsn trims blanks and disables empty values', () {
    expect(ErrorReportingConfig.normalizeDsn(null), isNull);
    expect(ErrorReportingConfig.normalizeDsn('   '), isNull);
    expect(
      ErrorReportingConfig.normalizeDsn(' https://example@sentry.io/1 '),
      'https://example@sentry.io/1',
    );
  });
}
```

- [ ] **Step 2: Run the test to confirm the helper file is missing**

Run:

```powershell
flutter test .\test\app\bootstrap\error_reporting_test.dart
```

Expected:
- Fail because `lib/app/bootstrap/error_reporting.dart` does not exist yet.

- [ ] **Step 3: Add the dependency and create the bootstrap helper**

```yaml
dependencies:
  sentry_flutter: ^8.5.0
```

```dart
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorReportingConfig {
  const ErrorReportingConfig({required this.dsn});

  final String? dsn;

  bool get enabled => dsn != null;

  static String? normalizeDsn(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

Future<void> runWithErrorReporting({
  required ErrorReportingConfig config,
  required Future<void> Function() startup,
  required VoidCallback runAppCallback,
}) async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(Sentry.captureException(details.exception, stackTrace: details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(Sentry.captureException(error, stackTrace: stack));
    return true;
  };
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final values = pair as List<dynamic>;
    await Sentry.captureException(values.first, stackTrace: values.last as StackTrace?);
  }).sendPort);

  if (!config.enabled) {
    await startup();
    runAppCallback();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = config.dsn;
      options.tracesSampleRate = 0.1;
      options.attachStacktrace = true;
    },
    appRunner: () async {
      await startup();
      runAppCallback();
    },
  );
}
```

- [ ] **Step 4: Route `main.dart` through the new bootstrap**

```dart
import 'app/bootstrap/error_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.detect();

  if (environment.usesSqfliteFfi) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startup = AppStartupRunner(
    logger: const AppLogger('startup'),
    steps: <AppStartupStep>[
      AppStartupStep('storage', StorageUtils.init),
      AppStartupStep('drafts', () => DraftManager().loadAllDrafts(syncRemote: false)),
      AppStartupStep('network_warmup', () async {
        WkHttpClient.instance.warmUp();
      }),
      AppStartupStep('push', PushService.instance.ensureInitialized),
    ],
  );

  final config = ErrorReportingConfig(
    dsn: ErrorReportingConfig.normalizeDsn(
      const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
    ),
  );

  await runWithErrorReporting(
    config: config,
    startup: startup.ensureStarted,
    runAppCallback: () => runApp(const ProviderScope(child: WuKongApp())),
  );
}
```

- [ ] **Step 5: Validate the Flutter integration**

Run:

```powershell
flutter test .\test\app\bootstrap\error_reporting_test.dart
dart analyze .\lib\main.dart .\lib\app\bootstrap\error_reporting.dart .\test\app\bootstrap\error_reporting_test.dart
```

Expected:
- The test passes.
- `dart analyze` reports no errors.

## Task 6: Write The Backend Metrics And Abuse-Control References

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\backend-prometheus-instrumentation.md`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\abuse-control-reference.md`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\sensitive-word-filtering.md`

- [ ] **Step 1: Snapshot the accepted KPI contract before writing examples**

Run:

```powershell
Get-Content .\deploy\dashboard\realtime-kpis.md
```

Expected:
- Use the exact metric names from this file in every documentation example.

- [ ] **Step 2: Create the backend Prometheus instrumentation reference**

````markdown
# Backend Prometheus Instrumentation

## Metric Definitions

```go
var (
    messageDeliveryTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "message_delivery_total",
            Help: "Count of backend message delivery attempts by result",
        },
        []string{"result", "channel_type"},
    )

    messageDeliveryLatencySeconds = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "message_delivery_latency_seconds",
            Help:    "Observed backend delivery latency in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"channel_type"},
    )
)

func recordMessageDelivery(channelType string, startedAt time.Time, err error) {
    result := "success"
    if err != nil {
        result = "failure"
    }
    messageDeliveryTotal.WithLabelValues(result, channelType).Inc()
    messageDeliveryLatencySeconds.WithLabelValues(channelType).Observe(time.Since(startedAt).Seconds())
}
```

## Expose `/metrics`

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

func registerMetricsEndpoint(mux *http.ServeMux) {
    mux.Handle("/metrics", promhttp.Handler())
}
```

## KPI Alignment

- `gateway_connect_success_rate`
- `gateway_reconnect_count`
- `control_frame_decode_error_count`
- `pull_after_seq_repair_count`
````

- [ ] **Step 3: Create the anti-brush and rate-limit reference**

````markdown
# Abuse Control Reference

## Registration Guard

```go
func allowRegistration(ip string, deviceID string, redis redis.Cmdable) (bool, error) {
    key := fmt.Sprintf("register:%s:%s", ip, deviceID)
    n, err := redis.Incr(ctx, key).Result()
    if err != nil {
        return false, err
    }
    if n == 1 {
        redis.Expire(ctx, key, 15*time.Minute)
    }
    return n <= 5, nil
}
```

## Token Bucket With Redis

```lua
local tokens_key = KEYS[1]
local ts_key = KEYS[2]
local rate = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])
```

Use dimensions:

- account ID
- device ID
- IP
- endpoint name
````

- [ ] **Step 4: Create the sensitive-word filtering reference**

````markdown
# Sensitive Word Filtering

## Hot Path Pipeline

1. Normalize unicode width, case, and whitespace.
2. Strip punctuation used for bypass patterns.
3. Scan with trie / DFA matcher.
4. Return `allow`, `replace`, or `block`.

## Pseudocode

```go
func moderateText(raw string, trie *Trie) (Decision, []string) {
    normalized := normalize(raw)
    hits := trie.FindAll(normalized)
    if len(hits) == 0 {
        return DecisionAllow, nil
    }
    return DecisionBlock, hits
}
```

## Storage

- Keep the word list in Redis or MySQL with a version number.
- Refresh an in-memory trie on version change.
````

- [ ] **Step 5: Validate the reference docs include the expected keywords**

Run:

```powershell
Select-String -Path .\docs\production\backend-prometheus-instrumentation.md -Pattern 'message_delivery_total','/metrics','gateway_connect_success_rate'
Select-String -Path .\docs\production\abuse-control-reference.md -Pattern 'Token Bucket','device ID','IP'
Select-String -Path .\docs\production\sensitive-word-filtering.md -Pattern 'Trie','DecisionBlock','normalize'
```

Expected:
- Each `Select-String` call returns matches from the new docs.

## Task 7: Add Firewall Automation

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\firewall_apply_ufw.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\firewall_apply_iptables.sh`

- [ ] **Step 1: Snapshot the current production firewall state**

Run:

```powershell
ssh ubuntu@42.194.218.158 "sudo ufw status numbered && sudo iptables -S"
```

Expected:
- Save the current rules into the release notes before applying any firewall script.

- [ ] **Step 2: Create the UFW allowlist script**

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5100/tcp
sudo ufw allow 5200/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 49160:49220/udp
sudo ufw allow 50000:50100/udp

sudo ufw --force enable
sudo ufw status verbose
```

- [ ] **Step 3: Create the iptables fallback script**

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5200 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5349 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 49160:49220 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 50000:50100 -j ACCEPT

sudo iptables-save
```

- [ ] **Step 4: Add the safety note to the release docs**

```markdown
## Firewall Safety Notes

- Keep `5100` and `5200` open until all clients are confirmed to ingress through a proxy.
- Do not close TURN or LiveKit UDP ranges if voice/video remains enabled.
- MySQL and Redis must stay loopback-only or Docker-internal.
```

- [ ] **Step 5: Validate the firewall scripts syntactically**

Run:

```powershell
docker run --rm -v "${PWD}:/work" -w /work bash:5.2 bash -lc "bash -n scripts/ops/firewall_apply_ufw.sh && bash -n scripts/ops/firewall_apply_iptables.sh"
```

Expected:
- No shell syntax errors.

## Task 8: Add CI And Backend Release Automation

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\.github\workflows\flutter-android-ci.yml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\deploy_backend_remote.ps1`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\scripts\ops\remote_redeploy.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\backend-release-runbook.md`

- [ ] **Step 1: Prove the workflow does not exist yet**

Run:

```powershell
Get-ChildItem .\.github\workflows -ErrorAction SilentlyContinue
```

Expected:
- No `flutter-android-ci.yml` file is present.

- [ ] **Step 2: Create the GitHub Actions workflow**

```yaml
name: flutter-android-ci

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  android:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Flutter pub get
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Build Android APK
        run: flutter build apk --release --target-platform android-arm64

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: wukongim-android-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 3: Create the remote redeploy scripts**

```powershell
param(
    [string]$Server = 'ubuntu@42.194.218.158',
    [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
    [string]$BuildVersion = ('prod-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

ssh $Server "cd $RemoteRoot && docker compose --env-file .env ps"
ssh $Server "cd $RemoteRoot && cp .env .env.bak.$(date +%Y%m%d%H%M%S)"
ssh $Server "cd $RemoteRoot && BUILD_VERSION=$BuildVersion docker compose --env-file .env build tsdd-api callgateway"
ssh $Server "cd $RemoteRoot && BUILD_VERSION=$BuildVersion docker compose --env-file .env up -d --no-deps tsdd-api callgateway"
ssh $Server "cd $RemoteRoot && docker compose --env-file .env ps"
ssh $Server "cd $RemoteRoot && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10"
ssh $Server "cd $RemoteRoot && python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10"
```

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /opt/wukongim-prod/src/deploy/production
cp .env ".env.bak.$(date +%Y%m%d%H%M%S)"
docker compose --env-file .env ps
docker compose --env-file .env build tsdd-api callgateway
docker compose --env-file .env up -d --no-deps tsdd-api callgateway
python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10
python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10
docker compose --env-file .env ps
```

- [ ] **Step 4: Create the backend release runbook**

```markdown
# Backend Release Runbook

## Current-State Release Promise

- `tsdd-api` and `callgateway`: low-downtime container recreation with health checks.
- `wukongim`: controlled restart only; existing long connections may reconnect.

## Preflight

1. `docker compose --env-file .env ps`
2. Snapshot `.env`
3. Record `BUILD_VERSION` and `BUILD_COMMIT`

## Release

1. Rebuild `tsdd-api` and `callgateway`
2. `up -d --no-deps tsdd-api callgateway`
3. Run `smoke_test.py`
4. Run `perf_probe.py`
5. Inspect recent logs

## Rollback

1. Restore the pinned rollback target
2. Re-run compose health checks
3. Re-run smoke and perf probes
```

- [ ] **Step 5: Validate the workflow and deploy scripts**

Run:

```powershell
docker run --rm -v "${PWD}:/work" -w /work python:3.12 sh -lc "pip install pyyaml >/tmp/pip.log && python - <<'PY'
import pathlib
import yaml
path = pathlib.Path('.github/workflows/flutter-android-ci.yml')
yaml.safe_load(path.read_text(encoding='utf-8'))
print('workflow ok')
PY"
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw '.\scripts\ops\deploy_backend_remote.ps1')) > `$null"
docker run --rm -v "${PWD}:/work" -w /work bash:5.2 bash -lc "bash -n scripts/ops/remote_redeploy.sh"
```

Expected:
- YAML parses successfully.
- PowerShell script parses successfully.
- Bash script parses successfully.

## Task 9: Run The Final Verification Matrix And Update The Log

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\implementation-log.md`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\production\README.md`

- [ ] **Step 1: Run the complete local validation matrix**

Run:

```powershell
docker run --rm -v "${PWD}:/work" -w /work python:3.12 sh -lc "pip install -r ops/stress/requirements.txt >/tmp/pip.log && python -m py_compile ops/stress/locustfile.py"
docker run --rm -v "${PWD}:/work" -w /work bash:5.2 bash -lc "bash -n scripts/ops/apply_im_sysctl.sh && bash -n scripts/ops/rollback_im_sysctl.sh && bash -n scripts/ops/observe_im_host.sh && bash -n scripts/ops/firewall_apply_ufw.sh && bash -n scripts/ops/firewall_apply_iptables.sh && bash -n scripts/ops/remote_redeploy.sh"
docker compose -f .\ops\monitoring\docker-compose.yml config
flutter test .\test\app\bootstrap\error_reporting_test.dart
dart analyze .\lib\main.dart .\lib\app\bootstrap\error_reporting.dart .\test\app\bootstrap\error_reporting_test.dart
```

Expected:
- All commands finish successfully.

- [ ] **Step 2: Run the remote production safety checks**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10"
```

Expected:
- All production readiness checks pass before any live rollout.

- [ ] **Step 3: Update the documentation index with the final execution order**

```markdown
## Recommended Execution Order

1. `scripts/ops/apply_im_sysctl.sh`
2. `scripts/ops/firewall_apply_ufw.sh`
3. `ops/monitoring/docker-compose.yml`
4. `flutter test` and `dart analyze`
5. `.github/workflows/flutter-android-ci.yml`
6. `scripts/ops/deploy_backend_remote.ps1`
7. `ops/stress/README.md`
```

- [ ] **Step 4: Replace every `pending` row in the implementation log with actual evidence**

```markdown
| 2026-04-17 23:30 | Task 9 final verification | local + remote verification matrix | all PASS | ready for operator handoff |
```

- [ ] **Step 5: Hand off with a file inventory**

Run:

```powershell
Get-ChildItem .\docs\production
Get-ChildItem .\ops\stress
Get-ChildItem .\ops\monitoring -Recurse
Get-ChildItem .\scripts\ops
Get-ChildItem .\.github\workflows
```

Expected:
- Every planned asset is present and ready for the next execution phase.
