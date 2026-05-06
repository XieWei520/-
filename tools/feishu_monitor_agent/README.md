# Feishu Monitor Agent MVP

This is the local Windows Agent MVP for Feishu monitor pairing and heartbeat.

It proves only the Agent control-plane link:

1. Pair with a cloud or local mock Monitor API using a short-lived pairing code.
2. Persist Agent id and token locally.
3. Send heartbeat to mark the Agent online.

It does not monitor Feishu Web messages yet.

## Pair with a server

```powershell
dart run bin/feishu_monitor_agent.dart pair --server http://127.0.0.1:8787 --code A7K9Q2
```

## Send one heartbeat

```powershell
dart run bin/feishu_monitor_agent.dart run --once
```

## Run heartbeat loop

```powershell
dart run bin/feishu_monitor_agent.dart run
```

## Local config

On Windows the Agent stores config under `%APPDATA%\InfoEquity\FeishuMonitorAgent` by default.

For tests and local smoke runs, pass a concrete store directory such as `--store-dir C:\Temp\feishu-agent-smoke` to isolate state.

The Agent must never print `agent_token` in logs.
