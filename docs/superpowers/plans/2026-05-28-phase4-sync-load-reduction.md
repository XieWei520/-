# Phase 4 Sync Load Reduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the high-frequency sync request load identified from the 24-hour production Prometheus window without schema changes or risky production behavior changes.

**Architecture:** Phase 4 is split into small, reversible changes. First add pure policy tests for client sync cadence/backoff decisions, then add backend no-change/cache fast paths for low-change sync endpoints, then package a guarded source-sync/build rollout like Phase 3. The first production batch must not change database schema, message correctness, auth behavior, or service topology.

**Tech Stack:** Flutter/Dart, PowerShell rollout scripts, Go backend snapshot under `.codex-backend-work/src`, TangSengDaoDao/WuKongIM HTTP APIs, Prometheus metrics.

---

## Production Evidence

The 24-hour Prometheus window collected on 2026-05-28 showed:

- Total requests: about 5.44M.
- 5xx: 0.
- `up{job="wukongim_api"}`: 5760 samples over 24h, `min_over_time(up[24h]) = 1`.
- Top eight routes account for about 96% of request volume:
  - `POST /v1/message/sync`: about 947k/day.
  - `POST /v1/conversation/extra/sync`: about 943k/day.
  - `GET /v1/users/:uid/im`: about 591k/day.
  - `POST /v1/conversation/sync`: about 560k/day.
  - `POST /v1/conversation/syncack`: about 557k/day.
  - `GET /v1/message/sync/sensitivewords`: about 548k/day.
  - `GET /v1/message/prohibit_words/sync`: about 545k/day.
  - `POST /v1/message/reminder/sync`: about 540k/day.
- Hot-route p99 is mostly low. The main issue is request frequency, not a single slow handler.
- `/v1/file/upload` p99 is about 980ms but only about 8 POST requests/day, so it is not Phase 4 batch 1.

## Scope For Batch 1

In scope:

- Client-side policy primitives for sync backoff/coalescing decisions.
- Server-side low-risk no-change/cache behavior for configuration-like sync endpoints.
- Metrics/runbook/deployment tooling for safe production rollout.

Out of scope:

- Database schema changes.
- Replacing the WuKongIM message sync protocol.
- WebSocket push architecture changes.
- File upload optimization.
- Client UI rebuilds or release packaging.

## File Structure

- Create `lib/service/im/sync_load_policy.dart`: pure Dart sync cadence/backoff/coalescing policy.
- Test `test/service/im/sync_load_policy_test.dart`: validates policy decisions without network dependencies.
- Modify backend snapshot ` .codex-backend-work/src/modules/message/api.go`: add no-change/cache helpers for low-change sync endpoints after tests prove desired behavior.
- Add backend tests under `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`: tests no-change cache/TTL helpers as pure functions or handler-level tests where practical.
- Create `deploy/production/backend-optimization/patches/0002-phase4-sync-load-reduction.patch`: reviewed backend patch generated from `.codex-backend-work/src`.
- Create `docs/production/phase4-sync-load-reduction-rollout.md`: production gates, PromQL baseline, switch and rollback.
- Create `scripts/ops/phase4_sync_load_reduction_prepare.ps1`: source sync/build script copied from the Phase 3 guarded pattern and narrowed to Phase 4 allowlist.
- Test `test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart`: verifies dry-run, allowlist, production gates, build-context filtering, rollback fields.

---

### Task 1: Client Sync Load Policy

**Files:**
- Create: `lib/service/im/sync_load_policy.dart`
- Create: `test/service/im/sync_load_policy_test.dart`

- [ ] **Step 1: Write the failing policy tests**

Create `test/service/im/sync_load_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukongim/service/im/sync_load_policy.dart';

void main() {
  group('SyncLoadPolicy', () {
    test('keeps immediate sync for the first attempt', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.messageSync,
        consecutiveEmptyResponses: 0,
        appVisible: true,
        hasPendingLocalMutation: false,
      );

      expect(delay, Duration.zero);
    });

    test('backs off repeated empty message sync while visible', () {
      const policy = SyncLoadPolicy();

      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 1,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 2),
      );
      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 4,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 16),
      );
      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 9,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 30),
      );
    });

    test('uses longer cap when app is backgrounded', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.conversationExtraSync,
        consecutiveEmptyResponses: 9,
        appVisible: false,
        hasPendingLocalMutation: false,
      );

      expect(delay, const Duration(minutes: 2));
    });

    test('does not back off when local mutations are pending', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.conversationSync,
        consecutiveEmptyResponses: 8,
        appVisible: true,
        hasPendingLocalMutation: true,
      );

      expect(delay, Duration.zero);
    });

    test('coalesces configuration endpoints for five minutes', () {
      const policy = SyncLoadPolicy();
      final now = DateTime(2026, 5, 28, 12);

      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.prohibitWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
          hasServerInvalidation: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.prohibitWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(const Duration(minutes: 5)),
          hasServerInvalidation: false,
        ),
        isTrue,
      );
    });

    test('server invalidation bypasses configuration coalescing', () {
      const policy = SyncLoadPolicy();
      final now = DateTime(2026, 5, 28, 12);

      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.sensitiveWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(const Duration(seconds: 30)),
          hasServerInvalidation: true,
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```powershell
flutter test test/service/im/sync_load_policy_test.dart
```

Expected: FAIL because `lib/service/im/sync_load_policy.dart` does not exist.

- [ ] **Step 3: Implement the policy**

Create `lib/service/im/sync_load_policy.dart`:

```dart
enum SyncEndpoint {
  messageSync,
  conversationSync,
  conversationExtraSync,
  conversationSyncAck,
  userIMRoute,
  sensitiveWordsSync,
  prohibitWordsSync,
  reminderSync,
}

class SyncLoadPolicy {
  const SyncLoadPolicy({
    this.visibleMaxDelay = const Duration(seconds: 30),
    this.backgroundMaxDelay = const Duration(minutes: 2),
    this.configurationCoalesceWindow = const Duration(minutes: 5),
  });

  final Duration visibleMaxDelay;
  final Duration backgroundMaxDelay;
  final Duration configurationCoalesceWindow;

  Duration nextDelay({
    required SyncEndpoint endpoint,
    required int consecutiveEmptyResponses,
    required bool appVisible,
    required bool hasPendingLocalMutation,
  }) {
    if (hasPendingLocalMutation || consecutiveEmptyResponses <= 0) {
      return Duration.zero;
    }
    if (_isAckEndpoint(endpoint)) {
      return Duration.zero;
    }
    final seconds = 1 << consecutiveEmptyResponses;
    final candidate = Duration(seconds: seconds);
    final cap = appVisible ? visibleMaxDelay : backgroundMaxDelay;
    return candidate > cap ? cap : candidate;
  }

  bool shouldRequest({
    required SyncEndpoint endpoint,
    required DateTime now,
    required DateTime? lastSuccessfulRequestAt,
    required bool hasServerInvalidation,
  }) {
    if (hasServerInvalidation || lastSuccessfulRequestAt == null) {
      return true;
    }
    if (!_isConfigurationEndpoint(endpoint)) {
      return true;
    }
    return now.difference(lastSuccessfulRequestAt) >= configurationCoalesceWindow;
  }

  bool _isAckEndpoint(SyncEndpoint endpoint) {
    return endpoint == SyncEndpoint.conversationSyncAck;
  }

  bool _isConfigurationEndpoint(SyncEndpoint endpoint) {
    return endpoint == SyncEndpoint.sensitiveWordsSync ||
        endpoint == SyncEndpoint.prohibitWordsSync;
  }
}
```

- [ ] **Step 4: Run Task 1 tests**

Run:

```powershell
flutter test test/service/im/sync_load_policy_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```powershell
git add lib/service/im/sync_load_policy.dart test/service/im/sync_load_policy_test.dart
git commit -m "feat: add sync load policy"
```

---

### Task 2: Backend Configuration Sync No-Change Cache

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api.go`
- Create: `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`

- [ ] **Step 1: Add failing backend tests**

Create `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`:

```go
package message

import (
    "testing"
    "time"

    "github.com/stretchr/testify/require"
)

func TestPhase4VersionedNoChangeCacheReturnsCachedEmptyResponse(t *testing.T) {
    cache := newVersionedNoChangeCache(5 * time.Minute)
    now := time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)
    key := versionedNoChangeCacheKey{endpoint: "prohibit_words", uid: "u1", version: 10}

    require.False(t, cache.shouldServeNoChange(key, now))

    cache.rememberNoChange(key, now)
    require.True(t, cache.shouldServeNoChange(key, now.Add(4*time.Minute)))
    require.False(t, cache.shouldServeNoChange(key, now.Add(5*time.Minute)))
}

func TestPhase4VersionedNoChangeCacheSeparatesEndpointUIDAndVersion(t *testing.T) {
    cache := newVersionedNoChangeCache(5 * time.Minute)
    now := time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)
    key := versionedNoChangeCacheKey{endpoint: "sensitive_words", uid: "u1", version: 1}
    cache.rememberNoChange(key, now)

    require.True(t, cache.shouldServeNoChange(key, now.Add(time.Minute)))
    require.False(t, cache.shouldServeNoChange(versionedNoChangeCacheKey{endpoint: "prohibit_words", uid: "u1", version: 1}, now.Add(time.Minute)))
    require.False(t, cache.shouldServeNoChange(versionedNoChangeCacheKey{endpoint: "sensitive_words", uid: "u2", version: 1}, now.Add(time.Minute)))
    require.False(t, cache.shouldServeNoChange(versionedNoChangeCacheKey{endpoint: "sensitive_words", uid: "u1", version: 2}, now.Add(time.Minute)))
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```powershell
Push-Location .codex-backend-work\src
go test -count=1 ./modules/message -run TestPhase4VersionedNoChangeCache
Pop-Location
```

Expected: FAIL because `newVersionedNoChangeCache` and related types do not exist.

- [ ] **Step 3: Implement cache helpers**

Add near the top of `.codex-backend-work/src/modules/message/api.go` after the `Message` type or package constants:

```go
const phase4NoChangeCacheTTL = 5 * time.Minute

type versionedNoChangeCacheKey struct {
    endpoint string
    uid      string
    version  int64
}

type versionedNoChangeCacheEntry struct {
    expiresAt time.Time
}

type versionedNoChangeCache struct {
    ttl     time.Duration
    mu      sync.RWMutex
    entries map[versionedNoChangeCacheKey]versionedNoChangeCacheEntry
}

func newVersionedNoChangeCache(ttl time.Duration) *versionedNoChangeCache {
    return &versionedNoChangeCache{
        ttl:     ttl,
        entries: make(map[versionedNoChangeCacheKey]versionedNoChangeCacheEntry),
    }
}

func (c *versionedNoChangeCache) shouldServeNoChange(key versionedNoChangeCacheKey, now time.Time) bool {
    c.mu.RLock()
    entry, ok := c.entries[key]
    c.mu.RUnlock()
    if !ok {
        return false
    }
    if now.Before(entry.expiresAt) {
        return true
    }
    c.mu.Lock()
    if current, ok := c.entries[key]; ok && !now.Before(current.expiresAt) {
        delete(c.entries, key)
    }
    c.mu.Unlock()
    return false
}

func (c *versionedNoChangeCache) rememberNoChange(key versionedNoChangeCacheKey, now time.Time) {
    c.mu.Lock()
    c.entries[key] = versionedNoChangeCacheEntry{expiresAt: now.Add(c.ttl)}
    c.mu.Unlock()
}
```

Add a package-level cache:

```go
var phase4ConfigNoChangeCache = newVersionedNoChangeCache(phase4NoChangeCacheTTL)
```

Ensure `api.go` imports `sync` and `time` if they are not already present.

- [ ] **Step 4: Run Task 2 tests**

Run:

```powershell
Push-Location .codex-backend-work\src
go test -count=1 ./modules/message -run TestPhase4VersionedNoChangeCache
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```powershell
git add .codex-backend-work/src/modules/message/api.go .codex-backend-work/src/modules/message/phase4_sync_load_test.go
git commit -m "feat: add backend sync no-change cache primitive"
```

---

### Task 3: Wire No-Change Cache Into Low-Change Endpoints

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api.go`
- Modify: `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`

- [ ] **Step 1: Add tests for endpoint cache keys**

Append to `.codex-backend-work/src/modules/message/phase4_sync_load_test.go`:

```go
func TestPhase4ConfigNoChangeKeyUsesLoginUIDAndVersion(t *testing.T) {
    got := phase4ConfigNoChangeKey("prohibit_words", "u1", 3)

    require.Equal(t, versionedNoChangeCacheKey{
        endpoint: "prohibit_words",
        uid:      "u1",
        version:  3,
    }, got)
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```powershell
Push-Location .codex-backend-work\src
go test -count=1 ./modules/message -run TestPhase4ConfigNoChangeKey
Pop-Location
```

Expected: FAIL because `phase4ConfigNoChangeKey` does not exist.

- [ ] **Step 3: Implement key helper and wire handlers conservatively**

Add helper in `.codex-backend-work/src/modules/message/api.go`:

```go
func phase4ConfigNoChangeKey(endpoint string, uid string, version int64) versionedNoChangeCacheKey {
    return versionedNoChangeCacheKey{endpoint: endpoint, uid: uid, version: version}
}
```

In `syncSensitiveWords`, after parsing request version and login UID, add:

```go
cacheKey := phase4ConfigNoChangeKey("sensitive_words", c.GetLoginUID(), reqVersion)
now := time.Now()
if reqVersion >= sensitiveWordsVersion && phase4ConfigNoChangeCache.shouldServeNoChange(cacheKey, now) {
    c.Response(gin.H{
        "version": sensitiveWordsVersion,
        "words":   []string{},
    })
    return
}
```

When `reqVersion >= sensitiveWordsVersion` and the handler returns an empty/no-change response from the normal path, call:

```go
phase4ConfigNoChangeCache.rememberNoChange(cacheKey, now)
```

In `syncProhibitWords`, use endpoint `"prohibit_words"` and the request version parsed by the existing handler. The no-change response must preserve the current response shape exactly. Do not cache error responses. Do not cache responses that include changed words.

- [ ] **Step 4: Run focused backend tests**

Run:

```powershell
Push-Location .codex-backend-work\src
go test -count=1 ./modules/message -run 'TestPhase4|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```powershell
git add .codex-backend-work/src/modules/message/api.go .codex-backend-work/src/modules/message/phase4_sync_load_test.go
git commit -m "feat: cache unchanged config sync responses"
```

---

### Task 4: Phase 4 Patch, Runbook, And Guarded Prepare Script

**Files:**
- Create: `deploy/production/backend-optimization/patches/0002-phase4-sync-load-reduction.patch`
- Create: `docs/production/phase4-sync-load-reduction-rollout.md`
- Create: `scripts/ops/phase4_sync_load_reduction_prepare.ps1`
- Create: `test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart`

- [ ] **Step 1: Add failing rollout script tests**

Create `test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart` with assertions mirroring Phase 3:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase4 sync load reduction prepare script is gated and scoped', () {
    final script = File('scripts/ops/phase4_sync_load_reduction_prepare.ps1');
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase4-sync-load-reduction'));
    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('modules/message/api.go'));
    expect(content, contains('modules/message/phase4_sync_load_test.go'));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker system prune')));
  });

  test('phase4 rollout docs include baseline and rollback', () {
    final doc = File('docs/production/phase4-sync-load-reduction-rollout.md');
    expect(doc.existsSync(), isTrue);
    final content = doc.readAsStringSync();

    expect(content, contains('sum by (route, method) (increase(wukongim_http_requests_total[24h]))'));
    expect(content, contains('histogram_quantile(0.99'));
    expect(content, contains('rollback'));
    expect(content, contains('phase4_sync_load_reduction_previous_image_tag'));
  });
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart
```

Expected: FAIL because files do not exist.

- [ ] **Step 3: Generate backend patch**

Run from repo root:

```powershell
Push-Location .codex-backend-work\src
git diff -- modules/message/api.go modules/message/phase4_sync_load_test.go > ..\..\deploy\production\backend-optimization\patches\0002-phase4-sync-load-reduction.patch
Pop-Location
```

If the backend snapshot is not a git checkout, use `git -C .codex-backend-work/src diff ...` only when `.git` exists. Otherwise generate the patch by comparing against the previous tracked Phase 3 patch source and inspect manually.

- [ ] **Step 4: Create runbook**

Create `docs/production/phase4-sync-load-reduction-rollout.md` with:

```markdown
# Phase 4 Sync Load Reduction Rollout

This rollout deploys only low-risk sync load reduction changes for `tsdd-api`:

- Backend no-change cache for low-change configuration sync endpoints.
- No database schema changes.
- No client release required for backend-only batch.

## Baseline PromQL

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[24h]))
topk(25, sum by (route, method) (increase(wukongim_http_requests_total[24h])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[24h])))
sum(increase(wukongim_http_requests_total{route="unknown"}[24h]))
```

## Build And Switch

Run the prepare script first in dry-run mode, then with explicit production sync/build flags. Switch services with the existing Phase 6 service switch script only after the image build succeeds.

## Rollback

Restore files from `phase4_sync_load_reduction_sync_backup_dir`, retag `wukongim/tsdd-api:production-local` from `phase4_sync_load_reduction_previous_image_tag`, and rerun `scripts/ops/phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch`.
```

- [ ] **Step 5: Create prepare script**

Copy `scripts/ops/phase3_backend_optimization_prepare.ps1` to `scripts/ops/phase4_sync_load_reduction_prepare.ps1`, then narrow the manifest and labels:

- Replace `phase3-backend-optimization` with `phase4-sync-load-reduction`.
- Allow only:
  - `modules/message/api.go`
  - `modules/message/phase4_sync_load_test.go`
- Print:
  - `phase4_sync_load_reduction_sync_backup_dir=`
  - `phase4_sync_load_reduction_previous_image_tag=`
  - `phase4_sync_load_reduction_build_context=verified`
- Keep the same production gates and temp-file SSH transport.

- [ ] **Step 6: Run Task 4 tests**

Run:

```powershell
flutter test test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit Task 4**

```powershell
git add deploy/production/backend-optimization/patches/0002-phase4-sync-load-reduction.patch docs/production/phase4-sync-load-reduction-rollout.md scripts/ops/phase4_sync_load_reduction_prepare.ps1 test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart
git commit -m "chore: add phase4 sync load rollout tooling"
```

---

### Task 5: Final Verification

**Files:**
- All files changed by Tasks 1-4.

- [ ] **Step 1: Run client policy tests**

```powershell
flutter test test/service/im/sync_load_policy_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run rollout script tests**

```powershell
flutter test test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run backend focused tests**

```powershell
Push-Location .codex-backend-work\src
go test -count=1 ./modules/message -run 'TestPhase4|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

Expected: PASS.

- [ ] **Step 4: Check git status**

```powershell
git status --short
```

Expected: only intentional Phase 4 files are modified.

- [ ] **Step 5: Final commit if needed**

If verification required small fixes, commit them:

```powershell
git add <changed files>
git commit -m "fix: stabilize phase4 sync load reduction"
```

## Self-Review Notes

- This plan intentionally starts with a pure client policy without wiring it into production behavior. That gives a safe tested contract for a later client release.
- The first backend batch focuses on configuration-like no-change endpoints. The message and conversation sync protocols are high-value but require more careful protocol-level coalescing and should be a later batch.
- The plan avoids schema changes and keeps production deployment behind explicit gates.
