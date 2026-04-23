# WuKongIM Locust Stress Runbook

## Local Dry-Run

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r ops/stress/requirements.txt
```

Set required environment variables before starting the run:

```powershell
$env:TARGET_WS_URL="ws://127.0.0.1:5200"
$env:AUTH_TOKEN="replace-with-real-token"
$env:MESSAGE_RATE_PER_USER="0.05"
```

Run Locust in headless mode:

```powershell
locust -f ops/stress/locustfile.py --headless --users 200 --spawn-rate 50 --run-time 10m
```

Important env vars (defaults come from `locustfile.py`):

- `TARGET_WS_URL`, `AUTH_TOKEN`: required for controller and workers.
- `CHANNEL_ID`: required business-message destination channel id when business traffic is enabled.
- `MESSAGE_RATE_PER_USER`: per-user business send rate in messages/second.
- `HEARTBEAT_INTERVAL_S`: per-user heartbeat interval.
- `WS_CONNECT_TIMEOUT_S`, `WS_RECV_TIMEOUT_S`: connect/recv timeout controls.
- `WS_SEND_RETRY_MAX`, `WS_SEND_RETRY_BACKOFF_S`: bounded retry controls.
- `CONNECT_HELLO_EXPECT_RESPONSE`, `HEARTBEAT_EXPECT_RESPONSE`, `BUSINESS_EXPECT_RESPONSE`: toggle whether each send path waits for a response frame.
- `CONNECT_EXPECTED_TYPE`, `HEARTBEAT_EXPECTED_TYPE`, `BUSINESS_EXPECTED_TYPE`: optional response type checks for expected-response paths.

Accuracy sign-off note: set `CONNECT_EXPECTED_TYPE` and `HEARTBEAT_EXPECTED_TYPE` (and `BUSINESS_EXPECTED_TYPE` when business responses are enabled) for accuracy-sensitive runs. `BUSINESS_EXPECT_RESPONSE=0` validates only the send path and does not validate delivery/ack semantics. Current response validation is a top-level, frame-level heuristic and is not request-correlated; if type checks are unset, both non-error JSON and non-JSON frames can still count as success.

## Distributed 10k Plan

Export required environment variables on the controller and every worker before starting Locust:

```powershell
$env:TARGET_WS_URL="ws://<gateway-host>:5200"
$env:AUTH_TOKEN="replace-with-real-token"
$env:MESSAGE_RATE_PER_USER="0.05"
$env:CHANNEL_ID="stress-room-01"
```

Workers (run on 4 nodes):

```powershell
locust -f ops/stress/locustfile.py --worker --master-host <controller-ip>
```

Controller command (run once per stage):

```powershell
locust -f ops/stress/locustfile.py --master --headless --expect-workers 4 --users <users> --spawn-rate 200 --run-time <duration>
```

Progressive ramp and duration:

- Stage 1: 2k users for 10m
- Stage 2: 5k users for 10m
- Stage 3: 10k users for 20m

Business traffic uses a time-based per-user schedule: each user attempts one send every `1 / MESSAGE_RATE_PER_USER` seconds.
At 10k users with `MESSAGE_RATE_PER_USER=0.05`, each user sends every 20s, for an aggregate around 500 msg/s.

Pass/fail guidance:

- Pass if `gateway_connect_success_rate` stays at or above 99%.
- Pass if `gateway_reconnect_count` only spikes during ramps and settles in steady-state windows.
- Pass if message latency p95 stays within the pre-agreed SLO for all stages.
- Fail if CPU / memory / swap / conntrack / socket counts show sustained resource exhaustion during any stage.

## Required Dashboards During Run

- `gateway_connect_success_rate`
- `gateway_reconnect_count`
- message latency p95
- CPU / memory / swap / conntrack / socket counts
