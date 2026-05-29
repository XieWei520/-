# Phase 5 Sync Backend Fast Paths Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce WuKongIM production sync load using backend-only fast paths proven by the current 22-hour Phase 4 production window.

**Architecture:** Phase 5 batch 1 is a narrow backend release built on top of Phase 4. It adds a safe no-change fast path for `prohibit_words`, an idempotent production index for `prohibit_words(version)`, and guarded rollout tooling that syncs only reviewed backend files and SQL. It does not change message delivery semantics, client protocol, service topology, or client builds.

**Tech Stack:** Go backend snapshot under `.codex-backend-work/src`, MySQL migration SQL, PowerShell production rollout scripts, Prometheus metrics, Docker Compose production deployment.

---

## Production Evidence

Collected on `2026-05-29 21:48 +08:00`, about 22 hours after Phase 4 production deployment:

- `tsdd-api` and `callgateway`: healthy for about 22 hours.
- `up{job="wukongim_api"} = 1`.
- nginx 24-hour 5xx count: `0`.
- 30-minute status classes: `2xx≈110,589`, `3xx≈9`, `4xx≈1`, no 5xx.
- 22-hour hot routes:
  - `POST /v1/message/sync`: about `613k`.
  - `POST /v1/conversation/extra/sync`: about `610k`.
  - `GET /v1/users/:uid/im`: about `373k`.
  - `POST /v1/conversation/sync`: about `358k`.
  - `POST /v1/conversation/syncack`: about `356k`.
  - `GET /v1/message/sync/sensitivewords`: about `354k`.
  - `GET /v1/message/prohibit_words/sync`: about `351k`.
  - `POST /v1/message/reminder/sync`: about `348k`.
- Hot route p95/p99 are mostly low; the problem is request frequency and repeated no-change work, not runaway single-request latency.
- Production index check found `prohibit_words` has only `PRIMARY(id)`; it does not have an index on `version`.

## Scope For Batch 1

In scope:

- Extend the Phase 4 no-change cache primitive to allow `prohibit_words`.
- Preserve correctness when manager APIs add/delete/reactivate prohibit words by relying on monotonic `common.ProhibitWordKey` versions.
- Add an idempotent SQL migration for `prohibit_words(version)`.
- Add tests for no-change allowlist and SQL/rollout guardrails.
- Add Phase 5 patch artifact and runbook.

Out of scope:

- Client release packaging.
- Replacing the full sync protocol.
- Conversation sync empty-result fast return. That is the next Phase 5 batch after this lower-risk backend release.
- Message extra/member readed query rewrites.
- Production deployment without separate user approval after local verification.

## File Structure

- Modify `.codex-backend-work/src/modules/message/api.go`: allow no-change cache for `prohibit_words`; add response shape helper for cached empty prohibit-word sync.
- Modify `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`: add Phase 5 tests for `prohibit_words` no-change allowlist and response shape.
- Create `.codex-backend-work/src/modules/message/sql/message-20260529-01.sql`: idempotent `prohibit_words(version)` migration with up/down comments.
- Create `deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch`: reviewed backend patch generated from `.codex-backend-work/src`.
- Create `docs/production/phase5-sync-backend-fastpaths-rollout.md`: production gates, migration, switch, and rollback.
- Create `scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1`: guarded source/migration sync and build script copied from the Phase 4 pattern and narrowed to Phase 5 allowlist.
- Create `test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart`: verifies script allowlist, SQL migration presence, patch path, and production guard flags.

---

### Task 1: Backend Prohibit Words No-Change Fast Path

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api.go`
- Modify: `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`

- [ ] **Step 1: Write failing Phase 5 backend tests**

Append to `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`:

```go
func TestPhase5NoChangeCacheAllowsProhibitWords(t *testing.T) {
	require.True(t, phase4ShouldCacheConfigNoChange("sensitive_words"))
	require.True(t, phase4ShouldCacheConfigNoChange("prohibit_words"))
	require.False(t, phase4ShouldCacheConfigNoChange("conversation_extra"))
}

func TestPhase5ProhibitWordsNoChangeResponsePreservesShape(t *testing.T) {
	resp := phase5ProhibitWordsNoChangeResponse()

	require.NotNil(t, resp)
	require.Empty(t, resp)
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase5'
Pop-Location
```

Expected: FAIL because `phase4ShouldCacheConfigNoChange("prohibit_words")` is false and `phase5ProhibitWordsNoChangeResponse` does not exist.

- [ ] **Step 3: Implement minimal backend fast path helpers**

In `.codex-backend-work/src/modules/message/api.go`, change:

```go
func phase4ShouldCacheConfigNoChange(endpoint string) bool {
	return endpoint == "sensitive_words"
}
```

to:

```go
func phase4ShouldCacheConfigNoChange(endpoint string) bool {
	return endpoint == "sensitive_words" || endpoint == "prohibit_words"
}
```

Add after `phase4SensitiveWordsNoChangeResponse`:

```go
func phase5ProhibitWordsNoChangeResponse() []*ProhibitWordResp {
	return make([]*ProhibitWordResp, 0)
}
```

Update `syncProhibitWords` from:

```go
func (m *Message) syncProhibitWords(c *wkhttp.Context) {
	version := c.Query("version")
	maxVersion, _ := strconv.ParseInt(version, 10, 64)
	list, err := m.db.queryProhibitWordsWithVersion(maxVersion)
	if err != nil {
		m.Error("同步违禁词错误", zap.Error(err))
		c.ResponseError(errors.New("同步违禁词错误"))
		return
	}
	result := make([]*ProhibitWordResp, 0)
	if len(list) > 0 {
		for _, word := range list {
			result = append(result, &ProhibitWordResp{
				Id:        word.Id,
				Content:   word.Content,
				IsDeleted: word.IsDeleted,
				CreatedAt: word.CreatedAt.String(),
				Version:   word.Version,
			})
		}
	}
	c.Response(result)
}
```

to this behavior-equivalent version with the no-change cache:

```go
func (m *Message) syncProhibitWords(c *wkhttp.Context) {
	version := c.Query("version")
	maxVersion, _ := strconv.ParseInt(version, 10, 64)
	endpoint := "prohibit_words"
	cacheKey := phase4ConfigNoChangeKey(endpoint, c.GetLoginUID(), maxVersion)
	now := time.Now()
	if phase4ShouldCacheConfigNoChange(endpoint) && phase4ConfigNoChangeCache.shouldServeNoChange(cacheKey, now) {
		c.Response(phase5ProhibitWordsNoChangeResponse())
		return
	}

	list, err := m.db.queryProhibitWordsWithVersion(maxVersion)
	if err != nil {
		m.Error("同步违禁词错误", zap.Error(err))
		c.ResponseError(errors.New("同步违禁词错误"))
		return
	}
	result := make([]*ProhibitWordResp, 0)
	if len(list) > 0 {
		for _, word := range list {
			result = append(result, &ProhibitWordResp{
				Id:        word.Id,
				Content:   word.Content,
				IsDeleted: word.IsDeleted,
				CreatedAt: word.CreatedAt.String(),
				Version:   word.Version,
			})
		}
	}
	if phase4ShouldCacheConfigNoChange(endpoint) && len(result) == 0 {
		phase4ConfigNoChangeCache.rememberNoChange(cacheKey, now)
	}
	c.Response(result)
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add .codex-backend-work/src/modules/message/api.go .codex-backend-work/src/modules/message/phase4_sync_load_test.go
git commit -m "feat: add prohibit words no-change fast path"
```

---

### Task 2: Prohibit Words Version Index Migration

**Files:**
- Create: `.codex-backend-work/src/modules/message/sql/message-20260529-01.sql`

- [ ] **Step 1: Write migration file**

Create `.codex-backend-work/src/modules/message/sql/message-20260529-01.sql`:

```sql
-- Phase 5: speed up GET /v1/message/prohibit_words/sync no-change checks.
-- The production table previously had only PRIMARY(id), while the hot query is:
-- SELECT * FROM prohibit_words WHERE version > ?

CREATE INDEX idx_prohibit_words_version ON prohibit_words (version);

-- Down:
-- DROP INDEX idx_prohibit_words_version ON prohibit_words;
```

- [ ] **Step 2: Verify SQL file content**

Run:

```powershell
Select-String -Path .codex-backend-work/src/modules/message/sql/message-20260529-01.sql -Pattern 'idx_prohibit_words_version','version'
```

Expected: both patterns are present.

- [ ] **Step 3: Commit Task 2**

Run:

```powershell
git add .codex-backend-work/src/modules/message/sql/message-20260529-01.sql
git commit -m "chore: add prohibit words version index migration"
```

---

### Task 3: Patch Artifact And Prepare Script

**Files:**
- Create: `deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch`
- Create: `scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1`
- Create: `test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart`

- [ ] **Step 1: Write failing script tests**

Create `test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1');

  test('phase5 prepare script exists and names rollout artifacts', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase5_sync_backend_fastpaths'));
    expect(
      content,
      contains('deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch'),
    );
    expect(content, contains('modules/message/api.go'));
    expect(content, contains('modules/message/phase4_sync_load_test.go'));
    expect(content, contains('modules/message/sql/message-20260529-01.sql'));
  });

  test('phase5 prepare script requires explicit production flags', () {
    final content = script.readAsStringSync();

    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('BuildImage'));
    expect(content, contains('phase5_sync_backend_fastpaths_previous_image_tag'));
  });

  test('phase5 patch contains only reviewed backend files', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch',
    );
    expect(patch.existsSync(), isTrue);
    final content = patch.readAsStringSync();

    expect(content, contains('diff --git a/modules/message/api.go b/modules/message/api.go'));
    expect(
      content,
      contains('diff --git a/modules/message/phase4_sync_load_test.go b/modules/message/phase4_sync_load_test.go'),
    );
    expect(
      content,
      contains('diff --git a/modules/message/sql/message-20260529-01.sql b/modules/message/sql/message-20260529-01.sql'),
    );
    expect(content, isNot(contains('lib/service/im')));
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart
```

Expected: FAIL because the Phase 5 script and patch do not exist.

- [ ] **Step 3: Generate backend patch artifact**

From `.codex-backend-work/src`, generate a patch relative to the production backend source baseline. Use the reviewed changed files only:

```powershell
Push-Location .codex-backend-work/src
git diff -- modules/message/api.go modules/message/phase4_sync_load_test.go modules/message/sql/message-20260529-01.sql > ..\..\deploy\production\backend-optimization\patches\0003-phase5-sync-backend-fastpaths.patch
Pop-Location
```

If `.codex-backend-work/src` is not a Git checkout, generate the patch by comparing the Phase 4 backend source snapshot against the edited files and ensure the patch has exactly these three paths:

```text
modules/message/api.go
modules/message/phase4_sync_load_test.go
modules/message/sql/message-20260529-01.sql
```

- [ ] **Step 4: Create guarded prepare script**

Create `scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1` by copying the structure of `scripts/ops/phase4_sync_load_reduction_prepare.ps1` and changing:

```powershell
$PhaseName = "phase5_sync_backend_fastpaths"
$PatchPath = "deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch"
$AllowedFiles = @(
  "modules/message/api.go",
  "modules/message/phase4_sync_load_test.go",
  "modules/message/sql/message-20260529-01.sql"
)
```

The script must print these fields when running with production flags:

```text
phase5_sync_backend_fastpaths_sync_backup_dir=<remote backup dir>
phase5_sync_backend_fastpaths_absent_files_manifest=<remote absent file manifest>
phase5_sync_backend_fastpaths_build_context=verified
phase5_sync_backend_fastpaths_previous_image_tag=wukongim/tsdd-api:phase5-pre-<timestamp>
```

Keep the same safety behavior as Phase 4:

- Dry run by default.
- Require `-Run -AllowProductionSync` before writing remote source.
- Require `-BuildImage -AllowProductionBuild` before building an image.
- Verify the effective Docker build context.
- Reject changed files outside `$AllowedFiles`.

- [ ] **Step 5: Run script tests to verify GREEN**

Run:

```powershell
flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git add deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1 test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart
git commit -m "chore: add phase5 sync fastpath rollout tooling"
```

---

### Task 4: Rollout Runbook

**Files:**
- Create: `docs/production/phase5-sync-backend-fastpaths-rollout.md`

- [ ] **Step 1: Create rollout runbook**

Create `docs/production/phase5-sync-backend-fastpaths-rollout.md`:

```markdown
# Phase 5 Sync Backend Fast Paths Rollout

This runbook deploys only the Phase 5 backend sync fastpath batch:

- `GET /v1/message/prohibit_words/sync` no-change fast path.
- `prohibit_words(version)` index migration.
- No client release required.
- No service topology changes.

## Preconditions

Run from the repository root:

```powershell
flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart

Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

## Baseline PromQL

Capture before rollout:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
topk(20, sum by (route, method) (increase(wukongim_http_requests_total[30m])))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

## Dry Run

```powershell
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1 -RunTests
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1
```

Confirm the allowlist contains only:

- `modules/message/api.go`
- `modules/message/phase4_sync_load_test.go`
- `modules/message/sql/message-20260529-01.sql`

## Sync Source And Build

```powershell
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Record:

```text
phase5_sync_backend_fastpaths_sync_backup_dir=<remote backup dir>
phase5_sync_backend_fastpaths_absent_files_manifest=<remote absent file manifest>
phase5_sync_backend_fastpaths_build_context=verified
phase5_sync_backend_fastpaths_previous_image_tag=wukongim/tsdd-api:phase5-pre-<timestamp>
```

## Apply Migration

Before switching the service, apply:

```sql
CREATE INDEX idx_prohibit_words_version ON prohibit_words (version);
```

If the index already exists, do not recreate it. Verify with:

```sql
SELECT INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'prohibit_words'
  AND INDEX_NAME = 'idx_prohibit_words_version';
```

## Switch Service

Use the existing backend service switch script:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

## Smoke Checks

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps tsdd-api callgateway nginx'
ssh ubuntu@42.194.218.158 'curl -k -fsS https://infoequity.cn/v1/ping'
```

## 30-Minute Gate

Pass criteria:

- `up{job="wukongim_api"}` remains `1`.
- 5xx remains `0`.
- `route="unknown"` remains `0`.
- Hot-route p95/p99 do not regress materially.
- `GET /v1/message/prohibit_words/sync` p95/p99 stay near Phase 4 baseline.

## Rollback

If smoke checks or 30-minute gates fail:

1. Restore backend source from `phase5_sync_backend_fastpaths_sync_backup_dir`.
2. Retag `phase5_sync_backend_fastpaths_previous_image_tag` to `wukongim/tsdd-api:production-local`.
3. Switch service with `phase6_backend_service_switch.ps1`.
4. Leave `idx_prohibit_words_version` in place unless it caused a verified database issue. The index is additive and safe to keep.
```

- [ ] **Step 2: Verify runbook references**

Run:

```powershell
Select-String -Path docs/production/phase5-sync-backend-fastpaths-rollout.md -Pattern 'phase5_sync_backend_fastpaths','idx_prohibit_words_version','rollback','30-Minute Gate'
```

Expected: all patterns are present.

- [ ] **Step 3: Commit Task 4**

Run:

```powershell
git add docs/production/phase5-sync-backend-fastpaths-rollout.md
git commit -m "docs: add phase5 sync fastpath rollout runbook"
```

---

### Task 5: Final Verification And Review

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run full Phase 5 verification**

Run:

```powershell
flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart

Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestSyncSensitiveWords|TestProhibit'
Pop-Location

git status --short
```

Expected:

- Flutter script tests PASS.
- Go message tests PASS.
- Git status only shows planned Phase 5 files before commit, or clean after final commit.

- [ ] **Step 2: Run patch allowlist inspection**

Run:

```powershell
Select-String -Path deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch -Pattern '^diff --git'
```

Expected exactly:

```text
diff --git a/modules/message/api.go b/modules/message/api.go
diff --git a/modules/message/phase4_sync_load_test.go b/modules/message/phase4_sync_load_test.go
diff --git a/modules/message/sql/message-20260529-01.sql b/modules/message/sql/message-20260529-01.sql
```

- [ ] **Step 3: Commit any final verification-only changes**

If any planned files changed during verification:

```powershell
git add <planned-files>
git commit -m "test: verify phase5 sync backend fastpaths"
```

---

## Self-Review Checklist

- Spec coverage: The plan covers the user-approved Phase 5 batch 1: `prohibit_words` no-change fast path, `prohibit_words(version)` index, guarded rollout tooling, and runbook.
- Placeholder scan: No TBD/TODO/fill-in-later placeholders are present.
- Type consistency: The helper names `phase5ProhibitWordsNoChangeResponse`, `phase4ShouldCacheConfigNoChange`, and `versionedNoChangeCacheKey` match existing Phase 4 naming.
- Production safety: The plan requires local tests and explicit production approval before deployment.
