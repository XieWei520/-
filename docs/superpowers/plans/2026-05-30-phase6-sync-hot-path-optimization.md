# Phase 6 Sync Hot Path Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Phase 5 production lessons into release guardrails, then optimize the remaining high-volume sync hot paths with small backend-only batches and mechanical production gates.

**Architecture:** Phase 6 has two tracks. The first track hardens release safety: SQL migration linting, backend switch smoke checks, and repeatable Prometheus gate reporting. The second track targets the remaining hot sync routes in order of observed production volume and implementation risk: first query/response fast paths, then conversation sync enrichment batching, then rollout packaging. No task should require a Windows, web, or Android client rebuild unless a later production bottleneck proves a client-side sync cadence change is needed.

**Tech Stack:** Go backend snapshot under `.codex-backend-work/src`, MySQL migrations using `sql-migrate`, PowerShell production scripts, Flutter/Dart script tests, Prometheus HTTP API, Docker Compose production deployment.

---

## Production Context

Phase 5 is already deployed and stable. The last clean 30-minute production gate showed:

- API target up: `up{job="wukongim_api"} = 1`.
- No 5xx.
- Unknown route traffic was zero.
- `GET /v1/message/prohibit_words/sync` p95/p99 were about 5 ms.
- `tsdd-api`, `callgateway`, and `nginx` were healthy.
- External `/v1/ping` returned `{"status":200}`.

Phase 5 also exposed two release risks that must be closed before deeper optimization:

- A migration without `-- +migrate Up` / `-- +migrate Down` can pass file review but fail production startup.
- `nginx -s reload` did not reliably refresh Docker upstream resolution after backend container recreation; the release path must restart nginx after `nginx -t`.

## Phase 6 Scope

In scope:

- Local SQL migration lint for new backend SQL files.
- Backend service switch and rollout gate standardization.
- Prometheus gate report script for immediate and 30-minute windows.
- `POST /v1/message/sync` focused profiling and low-risk query fast paths.
- `POST /v1/conversation/extra/sync` and `POST /v1/conversation/sync` focused profiling, pagination/index checks, and enrichment batching.
- A guarded Phase 6 patch/prepare/runbook if backend code changes are made.

Out of scope:

- Client release packaging.
- Protocol changes to WuKongIM message delivery.
- WebSocket push architecture changes.
- Data-destructive migrations.
- Rewriting the main IM sync service.

## File Structure

- Create `scripts/ops/phase6_sql_migration_lint.ps1`: scans backend SQL migrations for `sql-migrate` annotations and additive-index idempotency markers.
- Test `test/scripts/ops/phase6_sql_migration_lint_test.dart`: verifies lint detection, dry-run behavior, and the Phase 5 regression case.
- Modify `scripts/ops/phase6_backend_service_switch.ps1`: keep nginx restart behavior and add any missing internal/external ping evidence fields.
- Test `test/scripts/ops/phase6_backend_service_switch_test.dart`: extends current assertions for internal ping, external ping, and nginx recent 502 gate.
- Create `scripts/ops/phase6_prometheus_gate_report.ps1`: read-only gate reporter for 5-minute and 30-minute windows.
- Test `test/scripts/ops/phase6_prometheus_gate_report_test.dart`: verifies PromQL strings, threshold text, and dry-run output.
- Modify `.codex-backend-work/src/modules/message/api.go`: only if profiling shows a safe `message/sync` helper extraction or early-empty fast path.
- Modify `.codex-backend-work/src/modules/message/api_conversation.go`: only for conversation extra/sync helper extraction, bounds, or batching.
- Modify `.codex-backend-work/src/modules/message/db_conversation_extra.go`: only if adding explicit ordering/limit helpers for `conversation_extra`.
- Create or modify Go tests under `.codex-backend-work/src/modules/message/*_test.go`: focused tests before changing sync semantics.
- Create `deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch`: reviewed backend patch if backend code changes.
- Create `scripts/ops/phase6_sync_hot_path_prepare.ps1`: guarded source sync/build script if backend code changes.
- Create `docs/production/phase6-sync-hot-path-optimization-rollout.md`: production rollout and rollback runbook for the chosen Phase 6 batch.

---

### Task 1: SQL Migration Lint Gate

**Files:**
- Create: `scripts/ops/phase6_sql_migration_lint.ps1`
- Create: `test/scripts/ops/phase6_sql_migration_lint_test.dart`

- [ ] **Step 1: Write the failing script test**

Create `test/scripts/ops/phase6_sql_migration_lint_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/ops/phase6_sql_migration_lint.ps1');

  test('phase6 SQL migration lint script exists and checks annotations', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('-- +migrate Up'));
    expect(content, contains('-- +migrate Down'));
    expect(content, contains('information_schema.STATISTICS'));
    expect(content, contains('CREATE INDEX'));
    expect(content, contains('phase6_sql_migration_lint=pass'));
    expect(content, contains('phase6_sql_migration_lint=fail'));
  });

  test('phase6 SQL migration lint dry-run passes current changed SQL set', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_sql_migration_lint.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString(), contains('phase6_sql_migration_lint=pass'));
    expect(result.stdout.toString(), contains('phase6_sql_migration_lint_files='));
  }, skip: !Platform.isWindows);

  test('phase6 SQL migration lint catches the phase5 unannotated regression', () async {
    final temp = await Directory.systemTemp.createTemp('phase6-sql-lint-');
    try {
      final sqlDir = Directory('${temp.path}/modules/message/sql');
      sqlDir.createSync(recursive: true);
      File('${sqlDir.path}/message-20260529-01.sql').writeAsStringSync(
        'CREATE INDEX idx_prohibit_words_version ON prohibit_words (version);\n',
      );

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase6_sql_migration_lint.ps1',
          '-BackendRoot',
          temp.path,
          '-All',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, isNot(0));
      expect(result.stdout.toString(), contains('missing -- +migrate Up'));
      expect(result.stdout.toString(), contains('missing -- +migrate Down'));
      expect(result.stdout.toString(), contains('phase6_sql_migration_lint=fail'));
    } finally {
      temp.deleteSync(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('phase6 SQL migration lint accepts annotated idempotent index migrations', () async {
    final temp = await Directory.systemTemp.createTemp('phase6-sql-lint-');
    try {
      final sqlDir = Directory('${temp.path}/modules/message/sql');
      sqlDir.createSync(recursive: true);
      File('${sqlDir.path}/message-20260529-01.sql').writeAsStringSync('''
-- +migrate Up
SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'prohibit_words'
    AND INDEX_NAME = 'idx_prohibit_words_version'
);
SET @idx_sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_prohibit_words_version ON prohibit_words (version)',
  'SELECT 1'
);
PREPARE idx_stmt FROM @idx_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;

-- +migrate Down
DROP INDEX idx_prohibit_words_version ON prohibit_words;
''');

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase6_sql_migration_lint.ps1',
          '-BackendRoot',
          temp.path,
          '-All',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('modules/message/sql/message-20260529-01.sql'),
      );
      expect(result.stdout.toString(), contains('phase6_sql_migration_lint=pass'));
    } finally {
      temp.deleteSync(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase6_sql_migration_lint_test.dart
```

Expected: FAIL because `scripts/ops/phase6_sql_migration_lint.ps1` does not exist.

- [ ] **Step 3: Implement the lint script**

Create `scripts/ops/phase6_sql_migration_lint.ps1`:

```powershell
[CmdletBinding()]
param(
  [string]$BackendRoot = '',
  [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-BackendRoot {
  if (-not [string]::IsNullOrWhiteSpace($BackendRoot)) {
    return (Resolve-Path -LiteralPath $BackendRoot).Path
  }
  $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
  return (Resolve-Path -LiteralPath (Join-Path $repoRoot '.codex-backend-work\src')).Path
}

$root = Resolve-BackendRoot
$sqlRoot = Join-Path $root 'modules'
$allFiles = Get-ChildItem -LiteralPath $sqlRoot -Recurse -File -Filter '*.sql' |
  Where-Object { $_.FullName -match '\\sql\\' } |
  Sort-Object FullName

$files = $allFiles
if (-not $All) {
  Push-Location -LiteralPath $root
  try {
    $changed = @(& git diff --name-only --diff-filter=ACM -- 'modules/**/sql/*.sql')
    $untracked = @(& git ls-files --others --exclude-standard -- 'modules/**/sql/*.sql')
    $targets = @($changed + $untracked | Sort-Object -Unique)
    $files = $allFiles | Where-Object {
      $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
      $targets -contains $relative
    }
  } finally {
    Pop-Location
  }
}

$failures = New-Object System.Collections.Generic.List[string]
foreach ($file in $files) {
  $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
  $content = Get-Content -LiteralPath $file.FullName -Raw

  if ($content -notmatch '(?m)^-- \+migrate Up\s*$') {
    $failures.Add("$relative missing -- +migrate Up")
  }
  if ($content -notmatch '(?m)^-- \+migrate Down\s*$') {
    $failures.Add("$relative missing -- +migrate Down")
  }

  if ($relative -match '^modules/.+/sql/.+-20[0-9]{6}-[0-9]{2}\.sql$' -and
      $content -match '(?i)\bCREATE\s+(UNIQUE\s+)?INDEX\b' -and
      $content -notmatch '(?i)information_schema\.STATISTICS' -and
      $content -notmatch '(?i)IF\s+NOT\s+EXISTS') {
    $failures.Add("$relative creates an index without an idempotency check")
  }
}

Write-Host "phase6_sql_migration_lint_files=$($files.Count)"
foreach ($file in $files) {
  Write-Host ($file.FullName.Substring($root.Length + 1).Replace('\', '/'))
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Host "phase6_sql_migration_lint_failure=$failure"
  }
  Write-Host 'phase6_sql_migration_lint=fail'
  exit 1
}

Write-Host 'phase6_sql_migration_lint=pass'
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```powershell
flutter test test/scripts/ops/phase6_sql_migration_lint_test.dart
```

Expected: PASS. By default this lints only changed or untracked SQL files, because historical migrations in this backend snapshot are not all annotated or idempotent. Use `-All` only for inventory/reporting, not as a blocking gate until historical migrations have been normalized.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add scripts/ops/phase6_sql_migration_lint.ps1 test/scripts/ops/phase6_sql_migration_lint_test.dart
git commit -m "test: add phase6 sql migration lint gate"
```

---

### Task 2: Backend Switch Gate Evidence

**Files:**
- Modify: `scripts/ops/phase6_backend_service_switch.ps1`
- Modify: `test/scripts/ops/phase6_backend_service_switch_test.dart`

- [ ] **Step 1: Extend the failing switch test**

In `test/scripts/ops/phase6_backend_service_switch_test.dart`, add assertions to the first test:

```dart
expect(content, contains('internal_ping='));
expect(content, contains(r'docker exec "$tsdd_container_id" wget'));
expect(content, contains('external_ping='));
expect(content, contains('nginx_recent_502_count='));
expect(content, contains('phase6_backend_service_switch=blocked_internal_ping'));
expect(content, contains('phase6_backend_service_switch=blocked_external_ping'));
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase6_backend_service_switch_test.dart
```

Expected: FAIL if the switch script does not yet print or gate internal ping evidence.

- [ ] **Step 3: Add internal ping gate without changing service scope**

In the remote bash body of `scripts/ops/phase6_backend_service_switch.ps1`, after both backend services pass health and before nginx restart, add:

```bash
tsdd_container_id="$(docker compose --env-file .env ps -q tsdd-api)"
internal_ping="$(docker exec "$tsdd_container_id" wget -q -O - --timeout="$probe_timeout" http://127.0.0.1:8090/v1/ping || true)"
echo "internal_ping=$internal_ping"
if ! printf '%s\n' "$internal_ping" | grep -q '"status":200'; then
  echo 'phase6_backend_service_switch=blocked_internal_ping' >&2
  exit 1
fi
```

Keep the existing `nginx -t`, `docker compose --env-file .env restart nginx`, external `/v1/ping`, and recent nginx 502 gate.

- [ ] **Step 4: Ensure external ping has a specific blocked marker**

Wrap the existing external ping command so curl failure emits:

```bash
if ! external_ping="$(curl -fsS --max-time "$probe_timeout" "$release_base_url/v1/ping")"; then
  echo 'phase6_backend_service_switch=blocked_external_ping' >&2
  exit 1
fi
echo "external_ping=$external_ping"
```

- [ ] **Step 5: Run tests**

Run:

```powershell
flutter test test/scripts/ops/phase6_backend_service_switch_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
git add scripts/ops/phase6_backend_service_switch.ps1 test/scripts/ops/phase6_backend_service_switch_test.dart
git commit -m "fix: add phase6 backend switch ping gates"
```

---

### Task 3: Prometheus Gate Report Script

**Files:**
- Create: `scripts/ops/phase6_prometheus_gate_report.ps1`
- Create: `test/scripts/ops/phase6_prometheus_gate_report_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/scripts/ops/phase6_prometheus_gate_report_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/ops/phase6_prometheus_gate_report.ps1');

  test('phase6 prometheus gate report contains required production queries', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('up{job="wukongim_api"}'));
    expect(content, contains('sum by (status_class) (increase(wukongim_http_requests_total[__WINDOW__]))'));
    expect(content, contains('histogram_quantile(0.95'));
    expect(content, contains('histogram_quantile(0.99'));
    expect(content, contains('sum(increase(wukongim_http_requests_total{route="unknown"}[__WINDOW__]))'));
    expect(content, contains('topk(20'));
    expect(content, contains('p95_regression_threshold=1.5'));
    expect(content, contains('p99_regression_threshold=1.5'));
    expect(content, contains('phase6_prometheus_gate_report=completed'));
  });

  test('phase6 prometheus gate report dry-run prints both windows', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_prometheus_gate_report.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('window=5m'));
    expect(output, contains('window=30m'));
    expect(output, contains('Dry run only'));
  }, skip: !Platform.isWindows);
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase6_prometheus_gate_report_test.dart
```

Expected: FAIL because the report script does not exist.

- [ ] **Step 3: Implement the read-only report script**

Create `scripts/ops/phase6_prometheus_gate_report.ps1`:

```powershell
[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$PrometheusUrl = 'http://127.0.0.1:9090',
  [switch]$Run
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$queryTemplates = @(
  'up{job="wukongim_api"}',
  'sum by (status_class) (increase(wukongim_http_requests_total[__WINDOW__]))',
  'topk(20, sum by (route, method) (increase(wukongim_http_requests_total[__WINDOW__])))',
  'histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[__WINDOW__])))',
  'histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[__WINDOW__])))',
  'sum(increase(wukongim_http_requests_total{route="unknown"}[__WINDOW__]))'
)

Write-Host 'p95_regression_threshold=1.5'
Write-Host 'p99_regression_threshold=1.5'
Write-Host 'rollback_if_5xx_increase=true'
Write-Host 'rollback_if_unknown_route_increase=true'

foreach ($window in @('5m', '30m')) {
  Write-Host "window=$window"
  foreach ($template in $queryTemplates) {
    Write-Host ($template.Replace('__WINDOW__', $window))
  }
}

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to query production Prometheus over SSH.'
  exit 0
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

foreach ($window in @('5m', '30m')) {
  Write-Host "== prometheus window $window =="
  foreach ($template in $queryTemplates) {
    $query = $template.Replace('__WINDOW__', $window)
    $encoded = [System.Web.HttpUtility]::UrlEncode($query)
    $remote = "curl -fsS " + (Quote-Bash -Value "$PrometheusUrl/api/v1/query?query=$encoded")
    Write-Host "query=$query"
    ssh $RemoteHost $remote
  }
}

Write-Host 'phase6_prometheus_gate_report=completed'
```

- [ ] **Step 4: Run tests**

Run:

```powershell
flutter test test/scripts/ops/phase6_prometheus_gate_report_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add scripts/ops/phase6_prometheus_gate_report.ps1 test/scripts/ops/phase6_prometheus_gate_report_test.dart
git commit -m "chore: add phase6 prometheus gate report"
```

---

### Checkpoint A: Release Safety Gates

- [ ] Run:

```powershell
flutter test test/scripts/ops/phase6_sql_migration_lint_test.dart test/scripts/ops/phase6_backend_service_switch_test.dart test/scripts/ops/phase6_prometheus_gate_report_test.dart
git diff --check
```

Expected: all tests PASS and `git diff --check` has no output.

Report progress before continuing to Task 4.

---

### Task 4: Message Sync Profiling Harness

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api.go`
- Create: `.codex-backend-work/src/modules/message/phase6_message_sync_test.go`

- [ ] **Step 1: Write focused helper tests before changing sync behavior**

Create `.codex-backend-work/src/modules/message/phase6_message_sync_test.go`:

```go
package message

import (
	"strconv"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/stretchr/testify/require"
)

func TestPhase6MessageIDsFromSyncResponsesSkipsNilAndDedupes(t *testing.T) {
	resps := []*config.MessageResp{
		{MessageID: 11},
		nil,
		{MessageID: 11},
		{MessageID: 12},
	}

	got := phase6MessageIDsFromSyncResponses(resps)

	require.Equal(t, []string{"11", "12"}, got)
}

func TestPhase6MessageExtraMapsByMessageID(t *testing.T) {
	extras := []*messageExtraDetailModel{
		{messageExtraModel: messageExtraModel{MessageID: "11", Version: 3}},
		{messageExtraModel: messageExtraModel{MessageID: "12", Version: 4}},
	}
	userExtras := []*messageUserExtraModel{
		{MessageID: "12", VoiceReaded: 1},
	}

	extraMap, userExtraMap := phase6BuildMessageExtraMaps(extras, userExtras)

	require.Equal(t, int64(3), extraMap["11"].Version)
	require.Equal(t, 1, userExtraMap["12"].VoiceReaded)
	require.Nil(t, userExtraMap["11"])
}

func TestPhase6MessageIDStringsMatchResponseIDs(t *testing.T) {
	resps := []*config.MessageResp{{MessageID: 123456789}}
	got := phase6MessageIDsFromSyncResponses(resps)

	require.Equal(t, strconv.FormatInt(resps[0].MessageID, 10), got[0])
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6Message'
Pop-Location
```

Expected: FAIL because helper functions do not exist.

- [ ] **Step 3: Extract pure helper functions**

Add these helpers near the message sync code in `.codex-backend-work/src/modules/message/api.go`:

```go
func phase6MessageIDsFromSyncResponses(resps []*config.MessageResp) []string {
	messageIDs := make([]string, 0, len(resps))
	seen := make(map[string]struct{}, len(resps))
	for _, message := range resps {
		if message == nil || message.MessageID == 0 {
			continue
		}
		messageID := strconv.FormatInt(message.MessageID, 10)
		if _, ok := seen[messageID]; ok {
			continue
		}
		seen[messageID] = struct{}{}
		messageIDs = append(messageIDs, messageID)
	}
	return messageIDs
}

func phase6BuildMessageExtraMaps(
	messageExtras []*messageExtraDetailModel,
	messageUserExtras []*messageUserExtraModel,
) (map[string]*messageExtraDetailModel, map[string]*messageUserExtraModel) {
	messageExtraMap := make(map[string]*messageExtraDetailModel, len(messageExtras))
	for _, messageExtra := range messageExtras {
		if messageExtra != nil {
			messageExtraMap[messageExtra.MessageID] = messageExtra
		}
	}
	messageUserExtraMap := make(map[string]*messageUserExtraModel, len(messageUserExtras))
	for _, messageUserExtra := range messageUserExtras {
		if messageUserExtra != nil {
			messageUserExtraMap[messageUserExtra.MessageID] = messageUserExtra
		}
	}
	return messageExtraMap, messageUserExtraMap
}
```

Update `sync` to call `phase6MessageIDsFromSyncResponses(resps)` and `phase6BuildMessageExtraMaps(...)` instead of duplicating map construction inline.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6Message|TestPhase4|TestPhase5|TestSync'
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit Task 4**

Run:

```powershell
git add .codex-backend-work/src/modules/message/api.go .codex-backend-work/src/modules/message/phase6_message_sync_test.go
git commit -m "refactor: extract message sync hot path helpers"
```

---

### Task 5: Conversation Extra Sync Boundaries

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api_conversation.go`
- Modify: `.codex-backend-work/src/modules/message/db_conversation_extra.go`
- Create: `.codex-backend-work/src/modules/message/phase6_conversation_extra_test.go`

- [ ] **Step 1: Write tests for request bounds**

Create `.codex-backend-work/src/modules/message/phase6_conversation_extra_test.go`:

```go
package message

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestPhase6ConversationExtraSyncLimit(t *testing.T) {
	require.Equal(t, uint64(200), phase6ConversationExtraSyncLimit(0))
	require.Equal(t, uint64(50), phase6ConversationExtraSyncLimit(50))
	require.Equal(t, uint64(200), phase6ConversationExtraSyncLimit(5000))
}

func TestPhase6ConversationExtraNoChangeResponse(t *testing.T) {
	resp := phase6ConversationExtraNoChangeResponse()
	require.NotNil(t, resp)
	require.Empty(t, resp)
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6ConversationExtra'
Pop-Location
```

Expected: FAIL because helper functions do not exist.

- [ ] **Step 3: Add bounded helper and no-change response**

In `.codex-backend-work/src/modules/message/api_conversation.go`, add:

```go
const phase6ConversationExtraDefaultLimit uint64 = 200

func phase6ConversationExtraSyncLimit(requested uint64) uint64 {
	if requested == 0 || requested > phase6ConversationExtraDefaultLimit {
		return phase6ConversationExtraDefaultLimit
	}
	return requested
}

func phase6ConversationExtraNoChangeResponse() []*conversationExtraResp {
	return make([]*conversationExtraResp, 0)
}
```

Extend the request struct in `conversationExtraSync`:

```go
var req struct {
	Version int64  `json:"version"`
	Limit   uint64 `json:"limit"`
}
```

Call a new DB method with the bounded limit:

```go
conversationExtraModels, err := co.conversationExtraDB.syncWithLimit(
	loginUID,
	req.Version,
	phase6ConversationExtraSyncLimit(req.Limit),
)
```

- [ ] **Step 4: Add ordered DB helper**

In `.codex-backend-work/src/modules/message/db_conversation_extra.go`, keep `sync` as a wrapper and add:

```go
func (c *conversationExtraDB) sync(uid string, version int64) ([]*conversationExtraModel, error) {
	return c.syncWithLimit(uid, version, phase6ConversationExtraDefaultLimit)
}

func (c *conversationExtraDB) syncWithLimit(uid string, version int64, limit uint64) ([]*conversationExtraModel, error) {
	var models []*conversationExtraModel
	_, err := c.session.Select("*").
		From("conversation_extra").
		Where("uid=? and version>?", uid, version).
		OrderAsc("version").
		Limit(limit).
		Load(&models)
	return models, err
}
```

- [ ] **Step 5: Run focused tests**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6ConversationExtra|TestBuildUserLastOffsets|TestClearSyncConversationCache'
Pop-Location
```

Expected: PASS.

- [ ] **Step 6: Commit Task 5**

Run:

```powershell
git add .codex-backend-work/src/modules/message/api_conversation.go .codex-backend-work/src/modules/message/db_conversation_extra.go .codex-backend-work/src/modules/message/phase6_conversation_extra_test.go
git commit -m "feat: bound conversation extra sync results"
```

---

### Task 6: Conversation Sync Enrichment Batching Spike

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api_conversation.go`
- Create: `.codex-backend-work/src/modules/message/phase6_conversation_sync_test.go`

- [ ] **Step 1: Write tests for message ID collection across conversations**

Create `.codex-backend-work/src/modules/message/phase6_conversation_sync_test.go`:

```go
package message

import (
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/stretchr/testify/require"
)

func TestPhase6ConversationRecentMessageIDsDedupesAcrossConversations(t *testing.T) {
	conversations := []*config.SyncUserConversationResp{
		{
			Recents: []*config.MessageResp{
				{MessageID: 101},
				{MessageID: 102},
			},
		},
		{
			Recents: []*config.MessageResp{
				{MessageID: 102},
				nil,
				{MessageID: 103},
			},
		},
	}

	got := phase6ConversationRecentMessageIDs(conversations)

	require.Equal(t, []string{"101", "102", "103"}, got)
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6ConversationRecent'
Pop-Location
```

Expected: FAIL because `phase6ConversationRecentMessageIDs` does not exist.

- [ ] **Step 3: Add only the pure collection helper first**

In `.codex-backend-work/src/modules/message/api_conversation.go`, add:

```go
func phase6ConversationRecentMessageIDs(conversations []*config.SyncUserConversationResp) []string {
	messageIDs := make([]string, 0)
	seen := map[string]struct{}{}
	for _, conversation := range conversations {
		if conversation == nil {
			continue
		}
		for _, recent := range conversation.Recents {
			if recent == nil || recent.MessageID == 0 {
				continue
			}
			messageID := strconv.FormatInt(recent.MessageID, 10)
			if _, ok := seen[messageID]; ok {
				continue
			}
			seen[messageID] = struct{}{}
			messageIDs = append(messageIDs, messageID)
		}
	}
	return messageIDs
}
```

This task intentionally does not yet rewrite `newSyncUserConversationResp`. It creates a tested primitive for the next batch so the risky response-construction change can be reviewed separately.

- [ ] **Step 4: Run tests**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase6ConversationRecent|TestBuildUserLastOffsets|TestClearSyncConversationCache'
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit Task 6**

Run:

```powershell
git add .codex-backend-work/src/modules/message/api_conversation.go .codex-backend-work/src/modules/message/phase6_conversation_sync_test.go
git commit -m "test: add conversation sync batching primitive"
```

---

### Checkpoint B: Backend Hot Path Safety

- [ ] Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestPhase6|TestSyncSensitiveWords|TestProhibit|TestBuildUserLastOffsets|TestClearSyncConversationCache'
Pop-Location
```

Expected: PASS.

Report progress before packaging any production rollout.

---

### Task 7: Phase 6 Patch And Prepare Script

**Files:**
- Create: `deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch`
- Create: `scripts/ops/phase6_sync_hot_path_prepare.ps1`
- Create: `test/scripts/ops/phase6_sync_hot_path_prepare_test.dart`

- [ ] **Step 1: Write failing prepare-script test**

Create `test/scripts/ops/phase6_sync_hot_path_prepare_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 sync hot path prepare script is guarded', () {
    final script = File('scripts/ops/phase6_sync_hot_path_prepare.ps1');
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase6_sync_hot_path'));
    expect(content, contains('0004-phase6-sync-hot-path-optimization.patch'));
    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('BuildImage'));
    expect(content, contains('phase6_sync_hot_path_previous_image_tag'));
    expect(content, contains('phase6_sql_migration_lint.ps1'));
    expect(content, contains('phase6_prometheus_gate_report.ps1'));
  });

  test('phase6 patch contains only reviewed backend hot path files', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch',
    );
    expect(patch.existsSync(), isTrue);
    final content = patch.readAsStringSync();

    expect(content, contains('diff --git a/modules/message/api.go b/modules/message/api.go'));
    expect(content, contains('diff --git a/modules/message/api_conversation.go b/modules/message/api_conversation.go'));
    expect(content, isNot(contains('lib/')));
    expect(content, isNot(contains('android/')));
    expect(content, isNot(contains('web/')));
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase6_sync_hot_path_prepare_test.dart
```

Expected: FAIL because patch and prepare script do not exist.

- [ ] **Step 3: Generate reviewed backend patch**

Run from `.codex-backend-work/src` and include only Phase 6 backend files:

```powershell
Push-Location .codex-backend-work/src
git diff -- modules/message/api.go modules/message/api_conversation.go modules/message/db_conversation_extra.go modules/message/phase6_message_sync_test.go modules/message/phase6_conversation_extra_test.go modules/message/phase6_conversation_sync_test.go > ..\..\deploy\production\backend-optimization\patches\0004-phase6-sync-hot-path-optimization.patch
Pop-Location
```

If the backend snapshot is not a Git checkout, generate the patch against the current production backend source snapshot and inspect that it contains only the intended `modules/message` paths.

- [ ] **Step 4: Create guarded prepare script**

Copy the Phase 5 prepare-script pattern into `scripts/ops/phase6_sync_hot_path_prepare.ps1` and change:

```powershell
$PhaseName = "phase6_sync_hot_path"
$DefaultPatchPath = 'deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch'
$ReleaseFiles = @(
  'modules/message/api.go',
  'modules/message/api_conversation.go',
  'modules/message/db_conversation_extra.go',
  'modules/message/phase6_message_sync_test.go',
  'modules/message/phase6_conversation_extra_test.go',
  'modules/message/phase6_conversation_sync_test.go'
)
```

The script must:

- Dry-run by default.
- Require `-Run -AllowProductionSync` before remote writes.
- Require `-BuildImage -AllowProductionBuild` before image build.
- Run the SQL migration lint before build.
- Print `phase6_sync_hot_path_previous_image_tag`.
- Refuse build-context changes outside the allowlist.

- [ ] **Step 5: Run tests**

Run:

```powershell
flutter test test/scripts/ops/phase6_sync_hot_path_prepare_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 7**

Run:

```powershell
git add deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch scripts/ops/phase6_sync_hot_path_prepare.ps1 test/scripts/ops/phase6_sync_hot_path_prepare_test.dart
git commit -m "chore: add phase6 sync hot path rollout tooling"
```

---

### Task 8: Phase 6 Production Runbook

**Files:**
- Create: `docs/production/phase6-sync-hot-path-optimization-rollout.md`
- Modify: `docs/production/README.md`

- [ ] **Step 1: Create the runbook**

Create `docs/production/phase6-sync-hot-path-optimization-rollout.md`:

````markdown
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

## Sync Source And Build

```powershell
.\scripts\ops\phase6_sync_hot_path_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Record the backup directory, absent-files manifest, build context marker, and previous image tag printed by the script.

## Switch Service

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

The switch script must restart nginx after syntax test, then prove internal and external `/v1/ping`.

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

Restore source from the recorded backup directory, remove absent files from the manifest, retag the recorded previous image to `wukongim/tsdd-api:production-local`, run the backend service switch script, and repeat the immediate and 30-minute gates.
````

- [ ] **Step 2: Link it from production README**

Add to `docs/production/README.md` under Operator Entry Points:

```markdown
- Phase 6 sync hot path rollout: `docs/production/phase6-sync-hot-path-optimization-rollout.md`
```

- [ ] **Step 3: Verify docs**

Run:

```powershell
Select-String -Path docs/production/phase6-sync-hot-path-optimization-rollout.md -Pattern 'phase6_prometheus_gate_report','phase6_backend_service_switch','1.5x','rollback'
```

Expected: all patterns are present.

- [ ] **Step 4: Commit Task 8**

Run:

```powershell
git add docs/production/phase6-sync-hot-path-optimization-rollout.md docs/production/README.md
git commit -m "docs: add phase6 sync hot path rollout runbook"
```

---

## Final Verification

- [ ] Run all Phase 6 script tests:

```powershell
flutter test test/scripts/ops/phase6_sql_migration_lint_test.dart test/scripts/ops/phase6_backend_service_switch_test.dart test/scripts/ops/phase6_prometheus_gate_report_test.dart test/scripts/ops/phase6_sync_hot_path_prepare_test.dart
```

- [ ] Run backend focused tests:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestPhase6|TestSyncSensitiveWords|TestProhibit|TestBuildUserLastOffsets|TestClearSyncConversationCache'
Pop-Location
```

- [ ] Run patch inspection:

```powershell
Select-String -Path deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch -Pattern '^diff --git'
```

Expected: only intended `modules/message` paths.

- [ ] Run docs and whitespace checks:

```powershell
git diff --check
git status --short --branch
```

Expected: no whitespace errors; status shows only planned files before final commit or clean after final commit.

## Execution Notes

- Execute this plan with `superpowers:subagent-driven-development`.
- After Checkpoint A, report progress and automatically continue to backend hot path tasks unless the gate fails.
- After Checkpoint B, report progress and automatically continue to rollout packaging unless backend tests fail.
- Do not deploy Phase 6 to production until the user explicitly approves the production switch.
