# Monitor Agent Pairing Production Note (2026-05-06)

## Reader and action

This note is for the internal engineer who will continue the Feishu information monitoring work after the first production smoke test. After reading it, they should be able to verify the current production control-plane deployment, understand what has and has not been shipped, and port the backend delta into the formal backend source repository without relying on the original chat context.

## Current production scope

The production backend now exposes the first Monitor control-plane slice for local Windows Agent binding and heartbeat reporting:

- An authenticated console user can create a short-lived Agent pairing code.
- A local Windows Agent can exchange that pairing code for an Agent identity and Agent token.
- The Agent can send a heartbeat with platform, version, device name, status, capabilities, and observed time.
- The console can list Agents and Monitor events for the Feishu monitoring entry point.
- Monitor events record the Agent bind and online transitions with Chinese operator-facing messages.

This is intentionally only the control plane. Feishu Web message capture, routing rule execution, and forwarding to WuKong IM groups are not part of this slice yet.

## Production deployment facts

- The production API container was rebuilt and restarted after adding the Monitor backend module.
- The production API container was observed healthy after restart.
- The database migration has been applied and created the Monitor Agent, pairing-code, and event tables.
- The pre-change production source backup is stored on the production host under the backup directory named for the Monitor Agent pairing deployment on 2026-05-06.
- The production backend source directory is not currently a git working tree, so the backend implementation must be copied into the formal backend repository before future backend work depends on it.

## Backend delta snapshot

A source snapshot of the deployed Monitor backend delta is included with this documentation under `monitor-cloud-backend-patch-20260506/`.

It contains:

- the deployed Monitor module source;
- the Monitor SQL migration;
- the required backend module registration import.

The snapshot is not a substitute for merging into the backend repository. Treat it as an auditable production patch record and as the source of truth for the next formal backend patch.

## API contract summary

Create pairing code:

```http
POST /v1/monitor/agent-pairing-codes
```

Authenticated by the normal console user token header. Body:

```json
{
  "device_name": "Windows Agent",
  "platform": "windows"
}
```

Pair Agent:

```http
POST /v1/monitor/agents/pair
```

Body:

```json
{
  "pairing_code": "ABC123",
  "device_name": "DESKTOP-NAME",
  "platform": "windows",
  "agent_version": "0.1.0"
}
```

Heartbeat:

```http
POST /v1/monitor/agents/heartbeat
Authorization: Bearer <agent token>
```

Body:

```json
{
  "agent_id": "agent_xxx",
  "status": "online",
  "device_name": "DESKTOP-NAME",
  "platform": "windows",
  "agent_version": "0.1.0",
  "capabilities": ["feishu_web_group"],
  "observed_at": "2026-05-06T10:15:20Z"
}
```

List Agents:

```http
GET /v1/monitor/agents?platform=feishu
```

List events:

```http
GET /v1/monitor/events?platform=feishu&limit=10
```

## Verification evidence from production smoke

A production smoke test was run from a Windows workstation against the public production domain on 2026-05-06.

Observed local Agent output:

```text
绑定成功：Agent agent_<redacted>，心跳间隔 20 秒
心跳成功：online，服务器时间 2026-05-06T13:39:41Z
```

Observed production database state before cleanup:

```text
monitor_agent: platform=windows, device_name=<windows-device>, status=online
monitor_event: Windows Agent <windows-device> 已绑定
monitor_event: Windows Agent <windows-device> 已在线
```

The smoke UID used for that verification was cleaned from Monitor Agent, Monitor event, Monitor pairing-code tables, and the matching temporary Redis token was removed. Post-cleanup counts for that smoke UID were zero in all three Monitor tables.

## Known implementation constraints

- Pairing codes are short-lived and should be regenerated from the management console when expired.
- Agent tokens are secrets. Do not print them in CLI logs, docs, screenshots, or support tickets.
- Production verification helpers must redact console user tokens, Redis passwords, MySQL passwords, and Agent tokens.
- The MySQL timestamp behavior was corrected by formatting database write timestamps in local time before inserting/updating Monitor records. Keep this behavior when porting the backend delta.
- Platform naming is currently split by use case: the local Agent reports `windows`, while console filters use the Feishu monitoring center route. Preserve the current API contract until the UI and backend agree on a more explicit dimension model.

## Next backend actions

1. Port the Monitor module, SQL migration, and module registration import into the formal backend repository.
2. Add the migration to the normal backend migration runner instead of relying on a manually applied production migration.
3. Re-run backend unit tests in the backend repository environment.
4. Re-run the Windows Agent cloud smoke test after the formal backend deployment.
5. Only then start the next slice: Feishu Web session observation and message forwarding route configuration.
