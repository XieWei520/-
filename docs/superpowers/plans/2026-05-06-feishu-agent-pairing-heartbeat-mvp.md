# Feishu Agent Pairing and Heartbeat MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first executable Agent connectivity slice: management console creates a Windows Agent pairing code, a Dart CLI Agent pairs with that code, sends heartbeats, and the Feishu monitor center can show the Agent online.

**Architecture:** The production cloud backend source is on `ubuntu@42.194.218.158` at `/opt/wukongim-prod/src` and runs in Docker as `wukongim_prod-tsdd-api-1`. This plan first adds a real Go `monitor` backend module on the server with MySQL persistence and token-based Agent auth, then updates the Flutter contract and adds a Dart CLI Agent. A local mock server remains optional for fast Agent development, but the acceptance path is the real cloud endpoint.

**Tech Stack:** Go backend in TangSengDaoDaoServer, MySQL migration SQL, Docker Compose production service, Flutter/Dart, Dio, `flutter_test`, Dart CLI, JSON file local Agent store, TDD, targeted commits/backups.

---

## Scope

This plan implements the MVP from `docs/superpowers/specs/2026-05-06-feishu-agent-pairing-heartbeat-design.md` across the production Go backend and this Flutter/Dart repository:

- Add production Go backend Monitor endpoints on `ubuntu@42.194.218.158` under `/opt/wukongim-prod/src/modules/monitor`.
- Add MySQL tables for pairing codes, Agents, and monitor events.
- Update the Flutter monitor API contract so pairing code creation sends `platform: windows`.
- Add Agent-side data models and JSON-safe parsing.
- Add a Dart CLI Windows Agent with `pair --server https://infoequity.qingyunshe.top --code A7K9Q2` and `run --once`.
- Add local Agent config storage with token redaction in logs.
- Add tests for API contract, Agent pair flow, Agent heartbeat flow, and backend endpoint behavior.
- Keep an optional local Mock Monitor API server only if Agent development needs an offline fallback.

This plan does **not** implement Playwright, Feishu Web monitoring, Wukong IM forwarding, Windows tray UI, installer, or auto-update. Production backend persistence **is in scope**.

## File structure

### Production Go backend on `ubuntu@42.194.218.158`

- Create: `/opt/wukongim-prod/src/modules/monitor/1module.go`
  - Register the new `monitor` module.
- Create: `/opt/wukongim-prod/src/modules/monitor/api.go`
  - Register `/v1/monitor/*` routes and implement handlers.
- Create: `/opt/wukongim-prod/src/modules/monitor/db.go`
  - MySQL persistence for pairing codes, Agents, and events.
- Create: `/opt/wukongim-prod/src/modules/monitor/model.go`
  - DB models and response DTOs.
- Create: `/opt/wukongim-prod/src/modules/monitor/api_test.go`
  - Backend endpoint tests using the existing test server pattern.
- Create: `/opt/wukongim-prod/src/modules/monitor/sql/monitor-20260506-01.sql`
  - Migration for monitor tables and indexes.
- Modify: `/opt/wukongim-prod/src/internal/modules.go`
  - Add blank import for `modules/monitor`.
- Deploy from: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
  - Rebuild and restart only `tsdd-api` after backend tests pass.

### Flutter/Dart repository

- Modify: `lib/service/api/monitor_api.dart`
  - Add `platform: windows` to pairing-code creation.
- Modify: `test/service/api/monitor_api_test.dart`
  - Assert the new request payload.
- Create: `tools/feishu_monitor_agent/pubspec.yaml`
  - Standalone Dart Agent package.
- Create: `tools/feishu_monitor_agent/bin/feishu_monitor_agent.dart`
  - CLI entrypoint.
- Create: `tools/feishu_monitor_agent/lib/src/agent_models.dart`
  - Pair request/response, heartbeat request/response, Agent config model.
- Create: `tools/feishu_monitor_agent/lib/src/agent_api.dart`
  - Low-level HTTP client using `dart:io`.
- Create: `tools/feishu_monitor_agent/lib/src/agent_store.dart`
  - JSON config persistence.
- Create: `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`
  - One-shot and loop heartbeat behavior.
- Create: `tools/feishu_monitor_agent/lib/src/agent_cli.dart`
  - Argument parsing and command orchestration.
- Create tests under `tools/feishu_monitor_agent/test/`.
- Create: `tools/monitor_mock_server/pubspec.yaml`
- Create: `tools/monitor_mock_server/bin/monitor_mock_server.dart`
- Create: `tools/monitor_mock_server/lib/src/mock_monitor_server.dart`
- Create: `tools/monitor_mock_server/test/mock_monitor_server_test.dart`
- Create: `tools/feishu_monitor_agent/README.md`
- Create: `scripts/ops/run_feishu_agent_pairing_smoke.ps1`

---


### Task 1: Back up and prepare production Go backend workspace

**Files:**
- Remote read/write: `/opt/wukongim-prod/src`
- Remote backup destination example: `/home/ubuntu/wukong-deploy-backups/monitor-agent-pairing-20260506-210000`

- [ ] **Step 1: Confirm server state without changing it**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && pwd && ls -la modules internal && docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'"
```

Expected: output includes `/opt/wukongim-prod/src` and container `wukongim_prod-tsdd-api-1`.

- [ ] **Step 2: Create a timestamped backup before edits**

Run:

```powershell
ssh ubuntu@42.194.218.158 "set -e; ts=\$(date +%Y%m%d-%H%M%S); backup=/home/ubuntu/wukong-deploy-backups/monitor-agent-pairing-\$ts; mkdir -p \$backup; tar -C /opt/wukongim-prod -czf \$backup/src-before-monitor-agent-pairing.tar.gz src; cp /opt/wukongim-prod/src/internal/modules.go \$backup/modules.go.before; echo \$backup"
```

Expected: prints backup directory path. Save it in the implementation notes.

- [ ] **Step 3: Confirm backend source is not git-managed**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git status --short --branch 2>/dev/null || echo not-a-git-repo"
```

Expected: `not-a-git-repo`. Because there is no git safety net on the server, do not edit without the tar backup from Step 2.

---

### Task 2: Add Go monitor database migration and models

**Files:**
- Create remote: `/opt/wukongim-prod/src/modules/monitor/sql/monitor-20260506-01.sql`
- Create remote: `/opt/wukongim-prod/src/modules/monitor/model.go`

- [ ] **Step 1: Create migration SQL**

Create `/opt/wukongim-prod/src/modules/monitor/sql/monitor-20260506-01.sql`:

```sql
-- +migrate Up

CREATE TABLE IF NOT EXISTS `monitor_agent_pairing_code` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `code` VARCHAR(32) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `device_name` VARCHAR(100) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'windows',
  `expires_at` TIMESTAMP NOT NULL,
  `used_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_pairing_code_code_uidx` ON `monitor_agent_pairing_code` (`code`);
CREATE INDEX `monitor_pairing_code_uid_created_idx` ON `monitor_agent_pairing_code` (`uid`, `created_at`);

CREATE TABLE IF NOT EXISTS `monitor_agent` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `agent_token` VARCHAR(128) NOT NULL DEFAULT '',
  `device_name` VARCHAR(100) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'windows',
  `version` VARCHAR(40) NOT NULL DEFAULT '',
  `status` VARCHAR(32) NOT NULL DEFAULT 'offline',
  `last_heartbeat_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at` TIMESTAMP NULL DEFAULT NULL
);

CREATE UNIQUE INDEX `monitor_agent_agent_id_uidx` ON `monitor_agent` (`agent_id`);
CREATE UNIQUE INDEX `monitor_agent_token_uidx` ON `monitor_agent` (`agent_token`);
CREATE INDEX `monitor_agent_uid_status_idx` ON `monitor_agent` (`uid`, `status`, `updated_at`);

CREATE TABLE IF NOT EXISTS `monitor_event` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `event_id` VARCHAR(80) NOT NULL DEFAULT '',
  `uid` VARCHAR(40) NOT NULL DEFAULT '',
  `platform` VARCHAR(32) NOT NULL DEFAULT 'feishu',
  `agent_id` VARCHAR(80) NOT NULL DEFAULT '',
  `route_id` VARCHAR(80) NOT NULL DEFAULT '',
  `type` VARCHAR(64) NOT NULL DEFAULT '',
  `message` VARCHAR(255) NOT NULL DEFAULT '',
  `metadata` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX `monitor_event_event_id_uidx` ON `monitor_event` (`event_id`);
CREATE INDEX `monitor_event_uid_platform_created_idx` ON `monitor_event` (`uid`, `platform`, `created_at`);

-- +migrate Down

DROP TABLE IF EXISTS `monitor_event`;
DROP TABLE IF EXISTS `monitor_agent`;
DROP TABLE IF EXISTS `monitor_agent_pairing_code`;
```

- [ ] **Step 2: Create Go models**

Create `/opt/wukongim-prod/src/modules/monitor/model.go`:

```go
package monitor

import "time"

type pairingCodeModel struct {
	Id         int64      `db:"id"`
	Code       string     `db:"code"`
	UID        string     `db:"uid"`
	DeviceName string     `db:"device_name"`
	Platform   string     `db:"platform"`
	ExpiresAt  time.Time  `db:"expires_at"`
	UsedAt     *time.Time `db:"used_at"`
	CreatedAt  time.Time  `db:"created_at"`
	UpdatedAt  time.Time  `db:"updated_at"`
}

type agentModel struct {
	Id              int64      `db:"id"`
	AgentID         string     `db:"agent_id"`
	UID             string     `db:"uid"`
	AgentToken      string     `db:"agent_token"`
	DeviceName      string     `db:"device_name"`
	Platform        string     `db:"platform"`
	Version         string     `db:"version"`
	Status          string     `db:"status"`
	LastHeartbeatAt *time.Time `db:"last_heartbeat_at"`
	CreatedAt       time.Time  `db:"created_at"`
	UpdatedAt       time.Time  `db:"updated_at"`
	RevokedAt       *time.Time `db:"revoked_at"`
}

type eventModel struct {
	Id        int64     `db:"id"`
	EventID   string    `db:"event_id"`
	UID       string    `db:"uid"`
	Platform  string    `db:"platform"`
	AgentID   string    `db:"agent_id"`
	RouteID   string    `db:"route_id"`
	Type      string    `db:"type"`
	Message   string    `db:"message"`
	Metadata  string    `db:"metadata"`
	CreatedAt time.Time `db:"created_at"`
}

type createPairingCodeReq struct {
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

type pairAgentReq struct {
	PairingCode  string `json:"pairing_code"`
	DeviceName   string `json:"device_name"`
	Platform     string `json:"platform"`
	AgentVersion string `json:"agent_version"`
}

type heartbeatReq struct {
	AgentID      string   `json:"agent_id"`
	Status       string   `json:"status"`
	DeviceName   string   `json:"device_name"`
	Platform     string   `json:"platform"`
	AgentVersion string   `json:"agent_version"`
	Capabilities []string `json:"capabilities"`
	ObservedAt   string   `json:"observed_at"`
}
```

- [ ] **Step 3: Run Go package test and confirm compile failure until API/DB exist**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/monitor"
```

Expected: FAIL if module is not complete yet. Proceed to Task 3.

---

### Task 3: Add Go monitor DB repository

**Files:**
- Create remote: `/opt/wukongim-prod/src/modules/monitor/db.go`

- [ ] **Step 1: Create DB repository**

Create `/opt/wukongim-prod/src/modules/monitor/db.go`:

```go
package monitor

import (
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/gocraft/dbr/v2"
)

type DB struct {
	session *dbr.Session
}

func NewDB(ctx *config.Context) *DB {
	return &DB{session: ctx.DB()}
}

func (d *DB) insertPairingCode(m *pairingCodeModel) error {
	_, err := d.session.InsertInto("monitor_agent_pairing_code").
		Columns("code", "uid", "device_name", "platform", "expires_at").
		Record(m).Exec()
	return err
}

func (d *DB) queryPairingCode(code string) (*pairingCodeModel, error) {
	var model *pairingCodeModel
	_, err := d.session.Select("*").From("monitor_agent_pairing_code").Where("code=?", code).Load(&model)
	return model, err
}

func (d *DB) markPairingCodeUsed(code string, usedAt time.Time) error {
	_, err := d.session.Update("monitor_agent_pairing_code").Set("used_at", usedAt).Where("code=?", code).Exec()
	return err
}

func (d *DB) insertAgent(m *agentModel) error {
	_, err := d.session.InsertInto("monitor_agent").
		Columns("agent_id", "uid", "agent_token", "device_name", "platform", "version", "status").
		Record(m).Exec()
	return err
}

func (d *DB) queryAgentByID(agentID string) (*agentModel, error) {
	var model *agentModel
	_, err := d.session.Select("*").From("monitor_agent").Where("agent_id=?", agentID).Load(&model)
	return model, err
}

func (d *DB) queryAgentByToken(token string) (*agentModel, error) {
	var model *agentModel
	_, err := d.session.Select("*").From("monitor_agent").Where("agent_token=? and revoked_at is null", token).Load(&model)
	return model, err
}

func (d *DB) queryAgents(uid string, limit uint64) ([]*agentModel, error) {
	var list []*agentModel
	_, err := d.session.Select("*").From("monitor_agent").Where("uid=? and revoked_at is null", uid).OrderDir("updated_at", false).Limit(limit).Load(&list)
	return list, err
}

func (d *DB) updateAgentHeartbeat(agentID, deviceName, version string, now time.Time) error {
	_, err := d.session.Update("monitor_agent").SetMap(map[string]interface{}{
		"device_name":        deviceName,
		"version":            version,
		"status":             "online",
		"last_heartbeat_at":  now,
	}).Where("agent_id=?", agentID).Exec()
	return err
}

func (d *DB) insertEvent(m *eventModel) error {
	_, err := d.session.InsertInto("monitor_event").
		Columns("event_id", "uid", "platform", "agent_id", "route_id", "type", "message", "metadata").
		Record(m).Exec()
	return err
}

func (d *DB) queryEvents(uid, platform string, limit uint64) ([]*eventModel, error) {
	var list []*eventModel
	_, err := d.session.Select("*").From("monitor_event").Where("uid=? and platform=?", uid, platform).OrderDir("created_at", false).Limit(limit).Load(&list)
	return list, err
}
```

- [ ] **Step 2: Run gofmt**

```powershell
ssh ubuntu@42.194.218.158 "gofmt -w /opt/wukongim-prod/src/modules/monitor/db.go /opt/wukongim-prod/src/modules/monitor/model.go"
```

Expected: no output.

---

### Task 4: Add Go monitor module and API routes

**Files:**
- Create remote: `/opt/wukongim-prod/src/modules/monitor/1module.go`
- Create remote: `/opt/wukongim-prod/src/modules/monitor/api.go`
- Modify remote: `/opt/wukongim-prod/src/internal/modules.go`

- [ ] **Step 1: Register monitor module**

Create `/opt/wukongim-prod/src/modules/monitor/1module.go`:

```go
package monitor

import (
	"embed"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/register"
)

//go:embed sql
var sqlFS embed.FS

func init() {
	register.AddModule(func(ctx interface{}) register.Module {
		api := NewAPI(ctx.(*config.Context))
		return register.Module{
			Name: "monitor",
			SetupAPI: func() register.APIRouter {
				return api
			},
			SQLDir: register.NewSQLFS(sqlFS),
		}
	})
}
```

The register import path above matches `/opt/wukongim-prod/src/modules/extra/1module.go`.

- [ ] **Step 2: Add blank import to internal modules**

In `/opt/wukongim-prod/src/internal/modules.go`, add:

```go
_ "github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/monitor"
```

near the other module imports.

- [ ] **Step 3: Create API handlers**

Create `/opt/wukongim-prod/src/modules/monitor/api.go` with handlers for:

```text
POST /v1/monitor/agent-pairing-codes     user auth
POST /v1/monitor/agents/pair             no user auth, pairing code auth
POST /v1/monitor/agents/heartbeat        Agent bearer token auth
GET  /v1/monitor/agents                  user auth
GET  /v1/monitor/events                  user auth
GET  /v1/monitor/platforms/feishu/stats  user auth
GET  /v1/monitor/routes                  user auth, empty MVP list
```

The implementation must:

- Use `c.GetLoginUID()` for user-auth endpoints.
- Generate pairing codes with 6 safe uppercase characters.
- Set pairing expiry to `time.Now().Add(10 * time.Minute)`.
- Generate `agent_id` as `agent_` plus UUID.
- Generate `agent_token` as `monitor_agent_` plus UUID.
- Never log `agent_token` or raw Authorization header.
- Return JSON using the same response style as existing modules where possible.

Response body examples must match the design doc.

- [ ] **Step 4: Run gofmt**

```powershell
ssh ubuntu@42.194.218.158 "gofmt -w /opt/wukongim-prod/src/modules/monitor /opt/wukongim-prod/src/internal/modules.go"
```

Expected: no output.

---

### Task 5: Add Go backend tests

**Files:**
- Create remote: `/opt/wukongim-prod/src/modules/monitor/api_test.go`

- [ ] **Step 1: Create API tests**

Create `/opt/wukongim-prod/src/modules/monitor/api_test.go` following the existing pattern from `modules/extra/api_test.go`.

Tests must cover:

```text
POST /v1/monitor/agent-pairing-codes returns pairing_code and expires_at
POST /v1/monitor/agents/pair consumes code and returns agent_id/agent_token
Second pair with same code returns non-2xx status
POST /v1/monitor/agents/heartbeat with token marks Agent online
GET /v1/monitor/agents?platform=feishu returns the online Agent
GET /v1/monitor/events?platform=feishu returns an agent_paired event
```

Use `testutil.Token` for user-auth endpoints and no user token for Agent pair/heartbeat endpoints.

- [ ] **Step 2: Run monitor package tests**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/monitor"
```

Expected: PASS.

- [ ] **Step 3: Run affected backend package tests**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/monitor ./modules/extra ./modules/common"
```

Expected: PASS.

---

### Task 6: Update Flutter pairing-code API contract

**Files:**
- Modify: `lib/service/api/monitor_api.dart`
- Modify: `test/service/api/monitor_api_test.dart`

- [ ] **Step 1: Update the existing failing expectation first**

In `test/service/api/monitor_api_test.dart`, change the `createPairingCode posts device name and parses code` expectation from:

```dart
expect(adapter.lastBody, <String, dynamic>{'device_name': 'COLORFUL-PC'});
```

to:

```dart
expect(adapter.lastBody, <String, dynamic>{
  'device_name': 'COLORFUL-PC',
  'platform': 'windows',
});
```

- [ ] **Step 2: Run the focused test and confirm red**

```powershell
flutter test test/service/api/monitor_api_test.dart
```

Expected: FAIL because `MonitorApi.createPairingCode` still posts only `device_name`.

- [ ] **Step 3: Implement the minimal API change**

In `lib/service/api/monitor_api.dart`, update `createPairingCode` to:

```dart
Future<MonitorPairingCode> createPairingCode(String deviceName) async {
  final response = await _client.post(
    '/v1/monitor/agent-pairing-codes',
    data: <String, dynamic>{
      'device_name': deviceName.trim(),
      'platform': 'windows',
    },
    options: _plainTextOptions,
  );
  return MonitorPairingCode.fromJson(_resolveObjectPayload(response.data));
}
```

- [ ] **Step 4: Run the focused test and confirm green**

```powershell
flutter test test/service/api/monitor_api_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/service/api/monitor_api.dart test/service/api/monitor_api_test.dart
git commit -m "feat: send windows platform for monitor pairing codes"
```

---

### Task 7: Create Agent package and domain models

**Files:**
- Create: `tools/feishu_monitor_agent/pubspec.yaml`
- Create: `tools/feishu_monitor_agent/lib/src/agent_models.dart`
- Create: `tools/feishu_monitor_agent/test/agent_models_test.dart`

- [ ] **Step 1: Create package manifest**

Create `tools/feishu_monitor_agent/pubspec.yaml`:

```yaml
name: feishu_monitor_agent
description: Local Windows Agent MVP for Feishu monitor pairing and heartbeat.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.11.1

dev_dependencies:
  test: ^1.26.0
```

- [ ] **Step 2: Write failing model tests**

Create `tools/feishu_monitor_agent/test/agent_models_test.dart`:

```dart
import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:test/test.dart';

void main() {
  group('Agent models', () {
    test('PairAgentRequest serializes pairing payload', () {
      const request = PairAgentRequest(
        pairingCode: 'A7K9Q2',
        deviceName: 'COLORFUL-PC',
        platform: 'windows',
        agentVersion: '0.1.0',
      );

      expect(request.toJson(), <String, dynamic>{
        'pairing_code': 'A7K9Q2',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'agent_version': '0.1.0',
      });
    });

    test('PairAgentResponse parses token without exposing it in display text', () {
      final response = PairAgentResponse.fromJson(const <String, dynamic>{
        'agent_id': 'agent_1',
        'agent_token': 'secret-token',
        'heartbeat_interval_seconds': 20,
        'server_time': '2026-05-06T10:15:03Z',
      });

      expect(response.agentId, 'agent_1');
      expect(response.agentToken, 'secret-token');
      expect(response.heartbeatIntervalSeconds, 20);
      expect(response.toString(), isNot(contains('secret-token')));
    });

    test('HeartbeatRequest serializes heartbeat payload', () {
      const request = HeartbeatRequest(
        agentId: 'agent_1',
        status: 'online',
        deviceName: 'COLORFUL-PC',
        platform: 'windows',
        agentVersion: '0.1.0',
        capabilities: <String>['feishu_web_group'],
        observedAt: '2026-05-06T10:15:20Z',
      );

      expect(request.toJson(), <String, dynamic>{
        'agent_id': 'agent_1',
        'status': 'online',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'agent_version': '0.1.0',
        'capabilities': <String>['feishu_web_group'],
        'observed_at': '2026-05-06T10:15:20Z',
      });
    });
  });
}
```

- [ ] **Step 3: Run tests and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_models_test.dart
cd ..\..
```

Expected: FAIL because `agent_models.dart` does not exist.

- [ ] **Step 4: Implement Agent models**

Create `tools/feishu_monitor_agent/lib/src/agent_models.dart`:

```dart
class PairAgentRequest {
  const PairAgentRequest({
    required this.pairingCode,
    required this.deviceName,
    required this.platform,
    required this.agentVersion,
  });

  final String pairingCode;
  final String deviceName;
  final String platform;
  final String agentVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pairing_code': pairingCode.trim(),
    'device_name': deviceName.trim(),
    'platform': platform.trim(),
    'agent_version': agentVersion.trim(),
  };
}

class PairAgentResponse {
  const PairAgentResponse({
    required this.agentId,
    required this.agentToken,
    required this.heartbeatIntervalSeconds,
    required this.serverTime,
  });

  final String agentId;
  final String agentToken;
  final int heartbeatIntervalSeconds;
  final String serverTime;

  factory PairAgentResponse.fromJson(Map<String, dynamic> json) {
    return PairAgentResponse(
      agentId: _string(json['agent_id']),
      agentToken: _string(json['agent_token']),
      heartbeatIntervalSeconds:
          _int(json['heartbeat_interval_seconds'], fallback: 20),
      serverTime: _string(json['server_time']),
    );
  }

  @override
  String toString() {
    return 'PairAgentResponse(agentId: $agentId, heartbeatIntervalSeconds: $heartbeatIntervalSeconds, serverTime: $serverTime)';
  }
}

class HeartbeatRequest {
  const HeartbeatRequest({
    required this.agentId,
    required this.status,
    required this.deviceName,
    required this.platform,
    required this.agentVersion,
    required this.capabilities,
    required this.observedAt,
  });

  final String agentId;
  final String status;
  final String deviceName;
  final String platform;
  final String agentVersion;
  final List<String> capabilities;
  final String observedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'agent_id': agentId.trim(),
    'status': status.trim(),
    'device_name': deviceName.trim(),
    'platform': platform.trim(),
    'agent_version': agentVersion.trim(),
    'capabilities': capabilities,
    'observed_at': observedAt.trim(),
  };
}

class HeartbeatResponse {
  const HeartbeatResponse({
    required this.agentId,
    required this.status,
    required this.nextHeartbeatAfterSeconds,
    required this.serverTime,
  });

  final String agentId;
  final String status;
  final int nextHeartbeatAfterSeconds;
  final String serverTime;

  factory HeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return HeartbeatResponse(
      agentId: _string(json['agent_id']),
      status: _string(json['status']),
      nextHeartbeatAfterSeconds:
          _int(json['next_heartbeat_after_seconds'], fallback: 20),
      serverTime: _string(json['server_time']),
    );
  }
}

class AgentConfig {
  const AgentConfig({
    required this.serverUrl,
    required this.agentId,
    required this.agentToken,
    required this.deviceName,
    required this.agentVersion,
    required this.pairedAt,
    required this.heartbeatIntervalSeconds,
  });

  final String serverUrl;
  final String agentId;
  final String agentToken;
  final String deviceName;
  final String agentVersion;
  final String pairedAt;
  final int heartbeatIntervalSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'server_url': serverUrl,
    'agent_id': agentId,
    'agent_token': agentToken,
    'device_name': deviceName,
    'agent_version': agentVersion,
    'paired_at': pairedAt,
    'heartbeat_interval_seconds': heartbeatIntervalSeconds,
  };

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      serverUrl: _string(json['server_url']),
      agentId: _string(json['agent_id']),
      agentToken: _string(json['agent_token']),
      deviceName: _string(json['device_name']),
      agentVersion: _string(json['agent_version']),
      pairedAt: _string(json['paired_at']),
      heartbeatIntervalSeconds:
          _int(json['heartbeat_interval_seconds'], fallback: 20),
    );
  }

  @override
  String toString() {
    return 'AgentConfig(serverUrl: $serverUrl, agentId: $agentId, deviceName: $deviceName, agentVersion: $agentVersion, pairedAt: $pairedAt, heartbeatIntervalSeconds: $heartbeatIntervalSeconds)';
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

int _int(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
```

- [ ] **Step 5: Run tests and confirm green**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_models_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add tools/feishu_monitor_agent/pubspec.yaml tools/feishu_monitor_agent/lib/src/agent_models.dart tools/feishu_monitor_agent/test/agent_models_test.dart
git commit -m "feat: add feishu monitor agent models"
```

---

### Task 8: Add Agent local config store

**Files:**
- Create: `tools/feishu_monitor_agent/lib/src/agent_store.dart`
- Create: `tools/feishu_monitor_agent/test/agent_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Create `tools/feishu_monitor_agent/test/agent_store_test.dart`:

```dart
import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/agent_store.dart';
import 'package:test/test.dart';

void main() {
  test('AgentStore saves and loads config JSON', () async {
    final root = await Directory.systemTemp.createTemp('agent_store_test_');
    addTearDown(() async => root.delete(recursive: true));
    final store = AgentStore(root.path);

    const config = AgentConfig(
      serverUrl: 'http://127.0.0.1:8787',
      agentId: 'agent_1',
      agentToken: 'secret-token',
      deviceName: 'COLORFUL-PC',
      agentVersion: '0.1.0',
      pairedAt: '2026-05-06T10:15:03Z',
      heartbeatIntervalSeconds: 20,
    );

    await store.save(config);
    final loaded = await store.load();

    expect(loaded!.agentId, 'agent_1');
    expect(loaded.agentToken, 'secret-token');
    expect(await store.configFile.exists(), isTrue);
  });

  test('AgentStore returns null when config does not exist', () async {
    final root = await Directory.systemTemp.createTemp('agent_store_empty_');
    addTearDown(() async => root.delete(recursive: true));
    final store = AgentStore(root.path);

    expect(await store.load(), isNull);
  });
}
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_store_test.dart
cd ..\..
```

Expected: FAIL because `agent_store.dart` does not exist.

- [ ] **Step 3: Implement local store**

Create `tools/feishu_monitor_agent/lib/src/agent_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'agent_models.dart';

class AgentStore {
  AgentStore(String rootDirectory) : _root = Directory(rootDirectory);

  final Directory _root;

  File get configFile =>
      File('${_root.path}${Platform.pathSeparator}config.json');

  Future<AgentConfig?> load() async {
    final file = configFile;
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Agent config must be a JSON object.');
    }
    return AgentConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(AgentConfig config) async {
    await _root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString('${encoder.convert(config.toJson())}\n');
  }
}

String defaultAgentStoreDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (Platform.isWindows && appData != null && appData.trim().isNotEmpty) {
    return '${appData.trim()}${Platform.pathSeparator}InfoEquity${Platform.pathSeparator}FeishuMonitorAgent';
  }
  final home = Platform.environment['HOME'] ?? Directory.current.path;
  return '$home${Platform.pathSeparator}.infoequity${Platform.pathSeparator}feishu_monitor_agent';
}
```

- [ ] **Step 4: Run tests and confirm green**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_store_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/agent_store.dart tools/feishu_monitor_agent/test/agent_store_test.dart
git commit -m "feat: persist feishu monitor agent config"
```

---

### Task 9: Add Agent API client

**Files:**
- Create: `tools/feishu_monitor_agent/lib/src/agent_api.dart`
- Create: `tools/feishu_monitor_agent/test/agent_api_test.dart`

- [ ] **Step 1: Write failing API tests with local HttpServer**

Create `tools/feishu_monitor_agent/test/agent_api_test.dart` with a local `HttpServer` that:

- Responds to `POST /v1/monitor/agents/pair` with:

```json
{
  "data": {
    "agent_id": "agent_1",
    "agent_token": "secret-token",
    "heartbeat_interval_seconds": 20,
    "server_time": "2026-05-06T10:15:03Z"
  }
}
```

- Responds to `POST /v1/monitor/agents/heartbeat` with:

```json
{
  "data": {
    "agent_id": "agent_1",
    "status": "online",
    "next_heartbeat_after_seconds": 20,
    "server_time": "2026-05-06T10:15:20Z"
  }
}
```

The tests must assert:

```dart
expect(response.agentId, 'agent_1');
expect(response.agentToken, 'secret-token');
expect(lastRequest.path, '/v1/monitor/agents/pair');
expect(lastRequest.body, containsPair('pairing_code', 'A7K9Q2'));
expect(lastRequest.authorization, 'Bearer secret-token');
expect(heartbeatResponse.status, 'online');
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_api_test.dart
cd ..\..
```

Expected: FAIL because `agent_api.dart` does not exist.

- [ ] **Step 3: Implement Agent API client**

Create `tools/feishu_monitor_agent/lib/src/agent_api.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'agent_models.dart';

class AgentApiException implements Exception {
  const AgentApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() =>
      'AgentApiException(statusCode: $statusCode, code: $code, message: $message)';
}

class AgentApi {
  AgentApi({required String serverUrl, HttpClient? client})
    : _serverUrl = _normalizeServerUrl(serverUrl),
      _client = client ?? HttpClient();

  final String _serverUrl;
  final HttpClient _client;

  Future<PairAgentResponse> pair(PairAgentRequest request) async {
    final data = await _postJson(
      '/v1/monitor/agents/pair',
      body: request.toJson(),
    );
    return PairAgentResponse.fromJson(data);
  }

  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  }) async {
    final data = await _postJson(
      '/v1/monitor/agents/heartbeat',
      body: request.toJson(),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $agentToken',
      },
    );
    return HeartbeatResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final uri = Uri.parse('$_serverUrl$path');
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.write(jsonEncode(body));
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final normalized = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    if (response.statusCode >= 400) {
      final error = normalized['error'];
      final errorMap = error is Map
          ? Map<String, dynamic>.from(error)
          : const <String, dynamic>{};
      throw AgentApiException(
        response.statusCode,
        errorMap['code']?.toString() ?? 'http_error',
        errorMap['message']?.toString() ?? 'Request failed',
      );
    }
    final data = normalized['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('API response data must be a JSON object.');
  }

  void close() => _client.close(force: true);
}

String _normalizeServerUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
```

- [ ] **Step 4: Run tests and confirm green**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_api_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/agent_api.dart tools/feishu_monitor_agent/test/agent_api_test.dart
git commit -m "feat: add feishu monitor agent api client"
```

---

### Task 10: Add heartbeat runner and CLI commands

**Files:**
- Create: `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`
- Create: `tools/feishu_monitor_agent/lib/src/agent_cli.dart`
- Create: `tools/feishu_monitor_agent/bin/feishu_monitor_agent.dart`
- Create: `tools/feishu_monitor_agent/test/agent_cli_test.dart`

- [ ] **Step 1: Write failing CLI tests**

Create `tools/feishu_monitor_agent/test/agent_cli_test.dart` with tests that assert:

```dart
expect(exitCode, 0);
expect(output.join('\n'), contains('绑定成功'));
expect(output.join('\n'), isNot(contains('secret-token')));
expect(config!.agentId, 'agent_1');
expect(config.agentToken, 'secret-token');
expect(fakeApi.heartbeatCount, 1);
```

Use a fake API implementing:

```dart
abstract class AgentApiLike {
  Future<PairAgentResponse> pair(PairAgentRequest request);
  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  });
  void close();
}
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_cli_test.dart
cd ..\..
```

Expected: FAIL because CLI files do not exist.

- [ ] **Step 3: Implement heartbeat runner**

Create `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`:

```dart
import 'agent_models.dart';

abstract class AgentApiLike {
  Future<PairAgentResponse> pair(PairAgentRequest request);

  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  });

  void close();
}

class HeartbeatRunner {
  HeartbeatRunner({required this.api, required this.now});

  final AgentApiLike api;
  final DateTime Function() now;

  Future<HeartbeatResponse> sendOnce(AgentConfig config) {
    return api.heartbeat(
      agentToken: config.agentToken,
      request: HeartbeatRequest(
        agentId: config.agentId,
        status: 'online',
        deviceName: config.deviceName,
        platform: 'windows',
        agentVersion: config.agentVersion,
        capabilities: const <String>['feishu_web_group'],
        observedAt: now().toUtc().toIso8601String(),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement CLI orchestration**

Create `tools/feishu_monitor_agent/lib/src/agent_cli.dart`:

```dart
import 'dart:io';

import 'agent_api.dart';
import 'agent_models.dart';
import 'agent_store.dart';
import 'heartbeat_runner.dart';

const agentVersion = '0.1.0';

typedef AgentApiFactory = AgentApiLike Function(String serverUrl);
typedef WriteLine = void Function(String line);
typedef Now = DateTime Function();
typedef DeviceNameProvider = String Function();

Future<int> runAgentCli(
  List<String> args, {
  AgentApiFactory? apiFactory,
  WriteLine? writeLine,
  Now? now,
  DeviceNameProvider? deviceNameProvider,
}) async {
  final out = writeLine ?? stdout.writeln;
  final clock = now ?? DateTime.now;
  final deviceName = deviceNameProvider ?? _defaultDeviceName;
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage(out);
    return args.isEmpty ? 64 : 0;
  }

  final command = args.first;
  final options = _parseOptions(args.skip(1).toList());
  final store = AgentStore(options['store-dir'] ?? defaultAgentStoreDirectory());

  if (command == 'pair') {
    final server = options['server'];
    final code = options['code'];
    if (server == null || code == null) {
      out('pair 需要 --server 和 --code');
      _printUsage(out);
      return 64;
    }
    final api = apiFactory?.call(server) ?? AgentApi(serverUrl: server);
    try {
      final response = await api.pair(PairAgentRequest(
        pairingCode: code,
        deviceName: deviceName(),
        platform: 'windows',
        agentVersion: agentVersion,
      ));
      await store.save(AgentConfig(
        serverUrl: server,
        agentId: response.agentId,
        agentToken: response.agentToken,
        deviceName: deviceName(),
        agentVersion: agentVersion,
        pairedAt: clock().toUtc().toIso8601String(),
        heartbeatIntervalSeconds: response.heartbeatIntervalSeconds,
      ));
      out('绑定成功：Agent ${response.agentId}，心跳间隔 ${response.heartbeatIntervalSeconds} 秒');
      return 0;
    } finally {
      api.close();
    }
  }

  if (command == 'run') {
    final config = await store.load();
    if (config == null) {
      out('未找到 Agent 配置，请先执行 pair 命令绑定设备。');
      return 66;
    }
    final api = apiFactory?.call(config.serverUrl) ?? AgentApi(serverUrl: config.serverUrl);
    final runner = HeartbeatRunner(api: api, now: clock);
    try {
      final response = await runner.sendOnce(config);
      out('心跳成功：${response.status}，服务器时间 ${response.serverTime}');
      return 0;
    } finally {
      api.close();
    }
  }

  out('未知命令：$command');
  _printUsage(out);
  return 64;
}

void _printUsage(WriteLine out) {
  out('用法：');
  out('  feishu_monitor_agent pair --server https://infoequity.qingyunshe.top --code A7K9Q2 [--store-dir C:\\Temp\\feishu-agent]');
  out('  feishu_monitor_agent run [--once] [--store-dir C:\\Temp\\feishu-agent]');
}

Map<String, String> _parseOptions(List<String> args) {
  final result = <String, String>{};
  var index = 0;
  while (index < args.length) {
    final item = args[index];
    if (!item.startsWith('--')) {
      index += 1;
      continue;
    }
    final key = item.substring(2);
    if (index + 1 < args.length && !args[index + 1].startsWith('--')) {
      result[key] = args[index + 1];
      index += 2;
    } else {
      result[key] = 'true';
      index += 1;
    }
  }
  return result;
}

String _defaultDeviceName() {
  final computerName = Platform.environment['COMPUTERNAME'];
  if (computerName != null && computerName.trim().isNotEmpty) {
    return computerName.trim();
  }
  return Platform.localHostname;
}
```

- [ ] **Step 5: Make AgentApi implement AgentApiLike**

In `tools/feishu_monitor_agent/lib/src/agent_api.dart`, add:

```dart
import 'heartbeat_runner.dart';
```

Change:

```dart
class AgentApi {
```

to:

```dart
class AgentApi implements AgentApiLike {
```

- [ ] **Step 6: Add CLI entrypoint**

Create `tools/feishu_monitor_agent/bin/feishu_monitor_agent.dart`:

```dart
import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_cli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runAgentCli(args);
  exit(exitCode);
}
```

- [ ] **Step 7: Run all Agent tests**

```powershell
cd tools/feishu_monitor_agent
dart test
cd ..\..
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add tools/feishu_monitor_agent
git commit -m "feat: add feishu monitor agent cli heartbeat"
```

---

### Task 11: Add optional local Mock Monitor API server

**Files:**
- Create: `tools/monitor_mock_server/pubspec.yaml`
- Create: `tools/monitor_mock_server/lib/src/mock_monitor_server.dart`
- Create: `tools/monitor_mock_server/bin/monitor_mock_server.dart`
- Create: `tools/monitor_mock_server/test/mock_monitor_server_test.dart`

- [ ] **Step 1: Create package manifest**

Create `tools/monitor_mock_server/pubspec.yaml`:

```yaml
name: monitor_mock_server
description: Local mock Monitor API server for Feishu Agent MVP smoke tests.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.11.1

dev_dependencies:
  test: ^1.26.0
```

- [ ] **Step 2: Write failing server tests**

Create `tools/monitor_mock_server/test/mock_monitor_server_test.dart` with tests that:

1. Create a code via `POST /v1/monitor/agent-pairing-codes`.
2. Pair via `POST /v1/monitor/agents/pair`.
3. Send heartbeat via `POST /v1/monitor/agents/heartbeat` with bearer token.
4. Confirm `GET /v1/monitor/agents?platform=feishu` returns one online Agent.
5. Confirm `GET /v1/monitor/events?platform=feishu` contains `已绑定`.
6. Confirm reusing a pairing code returns HTTP 409.

- [ ] **Step 3: Run tests and confirm red**

```powershell
cd tools/monitor_mock_server
dart test
cd ..\..
```

Expected: FAIL because mock server files do not exist.

- [ ] **Step 4: Implement mock server**

Create `tools/monitor_mock_server/lib/src/mock_monitor_server.dart` with an in-memory `MockMonitorServer` that handles:

```text
POST /v1/monitor/agent-pairing-codes
POST /v1/monitor/agents/pair
POST /v1/monitor/agents/heartbeat
GET  /v1/monitor/agents
GET  /v1/monitor/events
GET  /v1/monitor/platforms/feishu/stats
GET  /v1/monitor/routes
```

The response shapes must match the design spec:

```json
{"data":{"pairing_code":"A7K9Q2","expires_at":"2026-05-06T10:25:00Z"}}
```

```json
{"data":{"agent_id":"agent_1","agent_token":"mock_token_agent_1","heartbeat_interval_seconds":20,"server_time":"2026-05-06T10:15:03Z"}}
```

```json
{"data":{"agent_id":"agent_1","status":"online","next_heartbeat_after_seconds":20,"server_time":"2026-05-06T10:15:20Z"}}
```

Errors must use:

```json
{
  "error": {
    "code": "pairing_code_used",
    "message": "绑定码已使用",
    "details": {},
    "request_id": "mock_request"
  }
}
```

- [ ] **Step 5: Add mock server entrypoint**

Create `tools/monitor_mock_server/bin/monitor_mock_server.dart`:

```dart
import 'dart:io';

import 'package:monitor_mock_server/src/mock_monitor_server.dart';

Future<void> main(List<String> args) async {
  final port = _readPort(args) ?? 8787;
  final server = MockMonitorServer();
  await server.start(port: port);
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}

int? _readPort(List<String> args) {
  final index = args.indexOf('--port');
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return int.tryParse(args[index + 1]);
}
```

- [ ] **Step 6: Run tests and confirm green**

```powershell
cd tools/monitor_mock_server
dart test
cd ..\..
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add tools/monitor_mock_server
git commit -m "feat: add monitor mock api server"
```

---

### Task 12: Add cloud/local end-to-end smoke scripts and docs

**Files:**
- Create: `tools/feishu_monitor_agent/README.md`
- Create: `scripts/ops/run_feishu_agent_pairing_smoke.ps1`

- [ ] **Step 1: Create Agent README**

Create `tools/feishu_monitor_agent/README.md`:

```markdown
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
```

- [ ] **Step 2: Create smoke script**

Create `scripts/ops/run_feishu_agent_pairing_smoke.ps1`:

```powershell
param(
  [int]$Port = 8787
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$serverDir = Join-Path $repoRoot 'tools\monitor_mock_server'
$agentDir = Join-Path $repoRoot 'tools\feishu_monitor_agent'
$storeDir = Join-Path $env:TEMP ('feishu-agent-smoke-' + [Guid]::NewGuid().ToString('N'))

Write-Host "Starting mock server on port $Port"
$server = Start-Process -FilePath 'dart' -ArgumentList @('run', 'bin/monitor_mock_server.dart', '--port', "$Port") -WorkingDirectory $serverDir -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

try {
  $codeResponse = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/v1/monitor/agent-pairing-codes" -ContentType 'application/json' -Body (@{ device_name = 'Windows Agent'; platform = 'windows' } | ConvertTo-Json)
  $code = $codeResponse.data.pairing_code
  Write-Host "Pairing code: $code"

  Push-Location $agentDir
  try {
    dart run bin/feishu_monitor_agent.dart pair --server "http://127.0.0.1:$Port" --code $code --store-dir $storeDir
    dart run bin/feishu_monitor_agent.dart run --once --store-dir $storeDir
  } finally {
    Pop-Location
  }

  $agents = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$Port/v1/monitor/agents?platform=feishu"
  if ($agents.data.Count -lt 1 -or $agents.data[0].status -ne 'online') {
    throw 'Expected one online Agent from mock server.'
  }
  Write-Host "Smoke passed: Agent is online."
} finally {
  if ($server -and -not $server.HasExited) {
    Stop-Process -Id $server.Id -Force
  }
  if (Test-Path -LiteralPath $storeDir) {
    Remove-Item -LiteralPath $storeDir -Recurse -Force
  }
}
```

- [ ] **Step 3: Run smoke script**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ops/run_feishu_agent_pairing_smoke.ps1
```

Expected output includes:

```text
Smoke passed: Agent is online.
```

- [ ] **Step 4: Commit**

```powershell
git add tools/feishu_monitor_agent/README.md scripts/ops/run_feishu_agent_pairing_smoke.ps1
git commit -m "docs: add feishu agent pairing smoke workflow"
```

---


### Task 13: Build and deploy backend to the cloud server

**Files:**
- Remote: `/opt/wukongim-prod/src`
- Remote: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`

- [ ] **Step 1: Confirm active compose file**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod && find . -maxdepth 3 -name 'docker-compose*.y*ml' -print"
```

Expected: output includes `./src/deploy/production/docker-compose.yaml`; that file defines `tsdd-api` and currently runs `wukongim_prod-tsdd-api-1`.

- [ ] **Step 2: Build the tsdd-api image or service using existing production workflow**

Prefer the existing deployment script if one exists. Discover it with:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod && find . -maxdepth 4 -type f \( -name '*deploy*' -o -name '*build*' -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) | sort | head -120"
```

If no script is clearly dedicated to `tsdd-api`, use the active compose file to rebuild only the API service:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose -f docker-compose.yaml build tsdd-api"
```

Expected: build succeeds.

- [ ] **Step 3: Restart only the API service**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose -f docker-compose.yaml up -d tsdd-api"
```

Expected: `wukongim_prod-tsdd-api-1` restarts and becomes healthy/running.

- [ ] **Step 4: Run cloud health check**

```powershell
ssh ubuntu@42.194.218.158 "curl -fsS http://127.0.0.1/v1/health || curl -fsS http://127.0.0.1:80/v1/health"
```

Expected: JSON contains `"status":"up"`.

- [ ] **Step 5: Run unauthenticated Agent endpoint smoke against cloud**

Use the Flutter app to create a pairing code, then paste it into this PowerShell smoke command:

```powershell
$pairingCode = Read-Host "请输入管理系统生成的 Agent 绑定码"
cd tools/feishu_monitor_agent
dart run bin/feishu_monitor_agent.dart pair --server https://infoequity.qingyunshe.top --code $pairingCode
dart run bin/feishu_monitor_agent.dart run --once
cd ..\..
```

Expected: pair succeeds, one heartbeat succeeds, and the Feishu monitor center shows the Agent online.

---

### Task 14: Targeted verification

**Files:**
- Modify only files touched above if verification fails.

- [ ] **Step 1: Run Flutter monitor tests**

```powershell
flutter test test/service/api/monitor_api_test.dart test/modules/monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run Agent package tests and analyzer**

```powershell
cd tools/feishu_monitor_agent
dart test
dart analyze
cd ..\..
```

Expected: PASS and no analyzer issues.

- [ ] **Step 3: Run mock server tests and analyzer**

```powershell
cd tools/monitor_mock_server
dart test
dart analyze
cd ..\..
```

Expected: PASS and no analyzer issues.

- [ ] **Step 4: Run Flutter analyzer on touched files**

```powershell
flutter analyze lib/service/api/monitor_api.dart lib/modules/monitor
```

Expected: no issues.

- [ ] **Step 5: Run local smoke script**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ops/run_feishu_agent_pairing_smoke.ps1
```

Expected output includes:

```text
Smoke passed: Agent is online.
```

- [ ] **Step 6: Fix verification failures with focused patches**

Use these fixes for likely failures:

- If package imports cannot resolve, run from the package directory.
- If port `8787` is already in use, rerun smoke with `-Port 8797`.
- If Windows blocks the PowerShell script, use `-ExecutionPolicy Bypass`.
- If analyzer reports line length, split long strings; do not suppress lints.

- [ ] **Step 7: Commit verification fixes if any**

```powershell
git add lib/service/api/monitor_api.dart test/service/api/monitor_api_test.dart tools/feishu_monitor_agent tools/monitor_mock_server scripts/ops/run_feishu_agent_pairing_smoke.ps1
git commit -m "fix: stabilize feishu agent pairing heartbeat mvp"
```

If no files changed, do not create an empty commit.

---

### Task 15: Final contract review

**Files:**
- Modify: `docs/superpowers/specs/2026-05-06-feishu-agent-pairing-heartbeat-design.md` only if implementation names diverge.

- [ ] **Step 1: Confirm contract names**

Run:

```powershell
Select-String -Path lib/service/api/monitor_api.dart,tools/feishu_monitor_agent/**/*.dart,tools/monitor_mock_server/**/*.dart,docs/superpowers/specs/2026-05-06-feishu-agent-pairing-heartbeat-design.md -Pattern '/v1/monitor/agent-pairing-codes','/v1/monitor/agents/pair','/v1/monitor/agents/heartbeat','feishu_web_group','agent_token','windows','feishu'
```

Expected: all names appear in the expected files.

- [ ] **Step 2: Confirm token redaction**

Run:

```powershell
Select-String -Path tools/feishu_monitor_agent/**/*.dart -Pattern 'agentToken|secret-token|Authorization' -Context 1,1
```

Expected:

- `agentToken` exists in models/store/API payload handling.
- CLI output does not print token values.
- Tests assert `secret-token` is not in output.

- [ ] **Step 3: Run final verification commands**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/monitor ./modules/extra ./modules/common"
flutter test test/service/api/monitor_api_test.dart test/modules/monitor/feishu_monitor_center_page_test.dart
flutter analyze lib/service/api/monitor_api.dart lib/modules/monitor
cd tools/feishu_monitor_agent
dart test
dart analyze
cd ..\monitor_mock_server
dart test
dart analyze
cd ..\..
powershell -ExecutionPolicy Bypass -File scripts/ops/run_feishu_agent_pairing_smoke.ps1
```

Expected: all pass, and smoke prints `Smoke passed: Agent is online.`

- [ ] **Step 4: Commit documentation alignment if needed**

Only if the spec changed:

```powershell
git add docs/superpowers/specs/2026-05-06-feishu-agent-pairing-heartbeat-design.md
git commit -m "docs: align feishu agent pairing heartbeat contract"
```

## Self-review checklist

- Spec coverage:
  - Pairing code API: Task 2, Task 4, Task 5, and Task 6.
  - Agent pair API: Task 4, Task 5, Task 9, and Task 10.
  - Agent heartbeat API: Task 4, Task 5, Task 9, and Task 10.
  - Local config persistence: Task 8.
  - Agent CLI pair/run commands: Task 10.
  - Management console visibility contract: Task 4, Task 5, and existing monitor center endpoints.
  - Local end-to-end proof: Task 11 and Task 12.
  - Feishu Web monitoring and forwarding: intentionally deferred.
- Placeholder scan:
  - No placeholder-marker instructions remain.
  - Each code task includes concrete code or exact edits.
  - Each verification step includes commands and expected results.
- Type consistency:
  - `platform` in Agent pair/heartbeat payload is `windows`.
  - Monitor console query platform remains `feishu`.
  - Capability is `feishu_web_group`.
  - Agent token field is `agent_token`.
  - Heartbeat endpoint is `/v1/monitor/agents/heartbeat`.

