# Windows Desktop Public Endpoint Diagnosis And Tunnel Runbook

Date: 2026-04-24

## Final Diagnosis

- The Windows desktop login/connectivity failure is no longer caused by the Flutter IM route selection code.
- The client now consumes the formal `/v1/users/{uid}/im` contract and keeps an explicit local override when `WK_DEV_WS_ADDR` is set.
- The remaining direct-public-path failure is concentrated on the `wemx.cc` domain route, not on the backend service process or the host IP itself.

## Confirmed Public Endpoint Behavior

- `https://wemx.cc/` from this Windows host resets during TLS handshake.
- `wss://wemx.cc/ws` from Dart fails with `HandshakeException`.
- `http://wemx.cc:5200/` with WebSocket upgrade headers returns `302` and redirects to a DNSPod web-block page.
- `wemx.cc:5100` raw TCP is reachable from this Windows host.
- `https://42.194.218.158/` responds successfully, which proves the host service is reachable by IP.
- `wss://42.194.218.158/ws` fails because the certificate does not match the IP address.
- `http://42.194.218.158:5200/` with WebSocket upgrade headers returns `101 Switching Protocols`.

## Implication

- Server-side IM service availability is not the blocker.
- The blocker for direct Windows desktop public access is the `wemx.cc` domain path and its upstream handling.
- Until a clean public domain and certificate path is provided, the most stable desktop validation path is the SSH tunnel workflow.

## Standard Desktop Tunnel Workflow

Start the tunnel-backed Windows desktop client:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ops\start_windows_tunnel_client.ps1
```

Stop the tunnel-backed Windows desktop client and all related child processes:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ops\stop_windows_tunnel_client.ps1
```

## Expected Healthy Signals

- Local ports `15001`, `15100`, and `15002` are listening after startup.
- The start script resolves current container IPs through remote `docker inspect`
  unless explicit remote targets are provided.
- The single SSH tunnel process contains all three forwards:
  - `15001 -> 172.18.0.9:8090` for the API
  - `15100 -> 172.18.0.6:5100` for IM TCP
  - `15002 -> 172.18.0.2:9000` for MinIO/media files
- The Flutter process is launched with both dev and prod overrides:
  - `WK_DEV_BASE_URL=http://127.0.0.1:15001`
  - `WK_PROD_BASE_URL=http://127.0.0.1:15001`
  - `WK_DEV_WS_ADDR=127.0.0.1:15100`
  - `WK_PROD_WS_ADDR=127.0.0.1:15100`
- The desktop log contains:
  - `POST http://127.0.0.1:15001/...`
  - `info:连接地址--->127.0.0.1:15100`
  - `ConnackPacket`
- After stop, there are no matching tunnel/client processes left and no listeners on `15001`, `15100`, or `15002`.

## Monitoring Files

- Desktop tunnel client log: `ops/monitoring/live/windows_client.tunnel.run.log`
- Tunnel stderr log: `ops/monitoring/live/ssh_tunnel_api_im.err.log`
- Tunnel stdout log: `ops/monitoring/live/ssh_tunnel_api_im.out.log`
- Current three-way tunnel stderr log: `ops/monitoring/live/ssh_tunnel_api_im_minio.err.log`
- Current three-way tunnel stdout log: `ops/monitoring/live/ssh_tunnel_api_im_minio.out.log`
- Server API tail log: `ops/monitoring/live/server_tsdd_api.log`
- Server IM log: `ops/monitoring/live/server_wukongim.log`
- Server Nginx log: `ops/monitoring/live/server_nginx.log`
- Server host observation log: `ops/monitoring/live/server_host.observe.log`

## Script Hardening Completed

- Added shared process utilities in `scripts/ops/windows_tunnel_client_process_utils.ps1`.
- Fixed the original process command-line matcher so it evaluates real process command lines instead of the nested pipeline variable.
- Added recursive child-process collection so `cmd.exe`, `dart.exe`, `dartvm.exe`, `dartaotruntime.exe`, `ssh.exe`, `powershell.exe`, and `wukong_im_app.exe` are cleaned together.
- Updated both `start_windows_tunnel_client.ps1` and `stop_windows_tunnel_client.ps1` to use the shared stop logic.
- Hardened tunnel targets against Docker container IP drift:
  - start script resolves `tsdd-api`, `wukongim`, and `minio` container IPs before creating forwards
  - stop script can match stale tunnel processes by local forwarded ports even if remote container IPs changed
- Hardened the Windows tunnel workflow so desktop tests no longer depend on direct `https://wemx.cc` from the native stack:
  - start script now forwards API, IM, and MinIO in one SSH process
  - start script now passes both development and production API/IM dart-defines
  - auth fallback treats public endpoint `connection reset`/Schannel reset style failures like handshake failures and retries through the desktop tunnel when enabled

## Automated Verification Completed

- Pester test file: `scripts/ops/tests/windows_tunnel_client_process_utils.Tests.ps1`
- Verified behaviors:
  - command-line substring matching
  - recursive descendant process collection
  - tunnel/client stop target selection
  - MinIO local-forward pattern included in the stop-rule set
- Verified live cycle:
  - stop old processes
  - start tunnel and desktop client
  - confirm `127.0.0.1:15001`, `127.0.0.1:15100`, and `127.0.0.1:15002`
  - confirm IM log stays on local address
  - stop again and confirm process and port cleanup

## Recommended Next Step

- Keep SSH tunnel as the standard Windows desktop QA path for now.
- If tunnel-free desktop access is required, create a new clean public domain entry and certificate path for the desktop route instead of continuing to tune the current `wemx.cc` path.
