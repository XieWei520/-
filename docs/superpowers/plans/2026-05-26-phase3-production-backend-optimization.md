# Phase 3 Production Backend Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first low-risk Phase 3 backend optimization batch using production Prometheus baselines: route caching for `/v1/users/:uid/im`, safer `conversation/syncack`, object-storage visibility/reuse, and repeatable production gates.

**Architecture:** Keep the Phase 2 deployment model: implement and test in `.codex-backend-work/src`, generate a tracked patch under `deploy/production`, sync only approved backend files, build without switching, then switch services with explicit production approval. Avoid protocol changes and DB schema changes in this first batch.

**Tech Stack:** Go 1.20, Gin/wkhttp, Prometheus text metrics, PowerShell deployment scripts, Docker Compose production rollout

---

## Reader And Scope

This plan is for an agentic worker who has no session context. It implements only the first backend Phase 3 batch. It must not modify Flutter client, Web release artifacts, Android/Windows packages, or admin-dashboard code. The current worktree may contain unrelated user changes; do not stage or revert them.

## File Structure And Ownership

- Modify: `.codex-backend-work/src/modules/user/api.go` - add a short TTL cache around successful IM route lookups.
- Modify: `.codex-backend-work/src/modules/user/api_im_route_test.go` - prove cache hit, TTL expiry, manager token separation, and error fallback behavior.
- Modify: `.codex-backend-work/src/modules/message/api_conversation.go` - replace syncack nested dedupe, add ack cleanup helper, keep response semantics.
- Create or modify: `.codex-backend-work/src/modules/message/api_conversation_syncack_test.go` - unit-test syncack dedupe and cache cleanup helpers without requiring full DB integration.
- Modify: `.codex-backend-work/src/modules/file/service_minio.go` - reuse MinIO client and cache bucket readiness.
- Modify: `.codex-backend-work/src/modules/file/service_minio_test.go` - test object path behavior and bucket readiness/client reuse through injectable factory if needed.
- Modify: `.codex-backend-work/src/serverlib/pkg/metrics/metrics.go` - add optional storage operation metrics if the existing recorder can support them without new dependencies.
- Modify: `.codex-backend-work/src/serverlib/pkg/metrics/metrics_test.go` - test storage operation labels do not include object keys, UIDs, or filenames.
- Create: `scripts/ops/phase3_backend_optimization_prepare.ps1` - Phase 3 dry-run/apply/sync/build helper based on Phase 2 script, with an explicit file allowlist for this batch.
- Create: `test/scripts/ops/phase3_backend_optimization_prepare_test.dart` - guard dry-run behavior, allowlist, production approval flags, and no secret output.
- Create: `docs/production/phase3-backend-optimization-rollout.md` - rollout, smoke, PromQL gates, rollback.
- Create: `deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch` - reproducible backend patch after implementation.

## Task 1: IM Route Short TTL Cache

**Files:**
- Modify: `.codex-backend-work/src/modules/user/api.go`
- Modify: `.codex-backend-work/src/modules/user/api_im_route_test.go`

- [ ] **Step 1: Add failing cache tests**

Add tests beside existing `TestUserIM_*` tests:

```go
func TestUserIM_CachesSuccessfulRouteResponsesForShortTTL(t *testing.T) {
	cfg := config.New()
	ctx := config.NewContext(cfg)
	httpRouter := wkhttp.New()
	u := &User{ctx: ctx}
	httpRouter.GET("/v1/users/:uid/im", u.userIM)

	var upstreamCalls int
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		upstreamCalls++
		require.Equal(t, "/route", r.URL.Path)
		require.Equal(t, "route-cache-user", r.URL.Query().Get("uid"))
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"tcp_addr":"wemx.cc:5100","ws_addr":"ws://wemx.cc:5200","wss_addr":"wss://wemx.cc/ws"}`))
	}))
	defer upstream.Close()

	ctx.GetConfig().WuKongIM.APIURL = upstream.URL

	for i := 0; i < 2; i++ {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/v1/users/route-cache-user/im", nil)
		httpRouter.ServeHTTP(w, req)
		require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	}
	require.Equal(t, 1, upstreamCalls)
}

func TestUserIM_DoesNotShareCacheAcrossManagerCredential(t *testing.T) {
	cfg := config.New()
	ctx := config.NewContext(cfg)
	httpRouter := wkhttp.New()
	u := &User{ctx: ctx}
	httpRouter.GET("/v1/users/:uid/im", u.userIM)

	var seenCredentials []string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenCredentials = append(seenCredentials, r.Header.Get("token"))
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"tcp_addr":"wemx.cc:5100","ws_addr":"ws://wemx.cc:5200","wss_addr":"wss://wemx.cc/ws"}`))
	}))
	defer upstream.Close()

	ctx.GetConfig().WuKongIM.APIURL = upstream.URL
	setRouteCredentialForTest(ctx, "test-token")
	httpRouter.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/v1/users/u1/im", nil))

	setRouteCredentialForTest(ctx, "dummy-token")
	httpRouter.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/v1/users/u1/im", nil))

	require.Equal(t, []string{"test-token", "dummy-token"}, seenCredentials)
}
```

Implement `setRouteCredentialForTest` locally in the test file using the existing config field for the upstream route credential. Keep the helper small, use only scanner-approved fixture values, and verify the staged diff with `secret_log_scan.py`.

- [ ] **Step 2: Run tests and verify RED**

Run from `.codex-backend-work/src/serverlib`:

```powershell
go test -count=1 ./modules/user -run 'TestUserIM_'
```

Expected: the new cache test fails because every request currently calls upstream.

- [ ] **Step 3: Implement bounded cache**

Add a package-level or `User`-scoped cache with:

```go
type imRouteCacheKey struct {
	apiURL       string
	managerToken string
	uid          string
}

type imRouteCacheEntry struct {
	statusCode int
	body       imRouteResponse
	expiresAt  time.Time
}
```

Rules:

- TTL: 5 seconds.
- Cache only successful upstream status codes from `200` to `299`.
- Normalize response before caching.
- Key includes API URL and manager token, so tests and production config changes do not cross-contaminate.
- Do not cache malformed JSON.
- Do not log or expose manager token.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
go test -count=1 ./modules/user -run 'TestUserIM_'
```

Expected: all `TestUserIM_*` tests pass.

- [ ] **Step 5: Commit backend snapshot change only after patch generation task**

Do not commit `.codex-backend-work` directly if it is ignored. This task's commit happens after Task 5 creates the tracked patch.

## Task 2: Syncack Dedupe And Cache Cleanup

**Files:**
- Modify: `.codex-backend-work/src/modules/message/api_conversation.go`
- Create: `.codex-backend-work/src/modules/message/api_conversation_syncack_test.go`

- [ ] **Step 1: Add pure helper tests**

Create tests for helper behavior:

```go
func TestBuildUserLastOffsetsDedupesByChannelWithMaxSeq(t *testing.T) {
	co := &Conversation{}
	got := co.buildUserLastOffsetsFromCache("u1", []string{
		"c1-1-10",
		"c1-1-12",
		"c2-2-4",
		"bad-value",
		"c2-2-3",
	})

	require.Len(t, got, 2)
	byKey := map[string]int64{}
	for _, item := range got {
		byKey[fmt.Sprintf("%s-%d", item.ChannelID, item.ChannelType)] = item.MessageSeq
	}
	require.Equal(t, int64(12), byKey["c1-1"])
	require.Equal(t, int64(4), byKey["c2-2"])
}

func TestClearSyncConversationCacheRemovesUserEntries(t *testing.T) {
	co := &Conversation{
		syncConversationResultCacheMap: map[string][]string{"u1": []string{"c1-1-10"}},
		syncConversationVersionMap:     map[string]int64{"u1": 99},
	}
	co.clearSyncConversationCache("u1")
	require.Empty(t, co.syncConversationResultCacheMap)
	require.Empty(t, co.syncConversationVersionMap)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
go test -count=1 ./modules/message -run 'TestBuildUserLastOffsetsDedupesByChannelWithMaxSeq|TestClearSyncConversationCacheRemovesUserEntries'
```

Expected: FAIL because helpers do not exist.

- [ ] **Step 3: Implement helpers and wire syncack**

Implement:

```go
func (co *Conversation) buildUserLastOffsetsFromCache(loginUID string, channelMessageSeqStrs []string) []*userLastOffsetModel {
	byChannel := map[string]*userLastOffsetModel{}
	for _, raw := range channelMessageSeqStrs {
		channelID, channelType, messageSeq := co.channelMessageSeqSplit(raw)
		if channelID == "" || channelType == 0 || messageSeq == 0 {
			continue
		}
		key := fmt.Sprintf("%s-%d", channelID, channelType)
		existing := byChannel[key]
		if existing == nil {
			byChannel[key] = &userLastOffsetModel{
				UID:         loginUID,
				ChannelID:   channelID,
				ChannelType: channelType,
				MessageSeq:  int64(messageSeq),
			}
			continue
		}
		if int64(messageSeq) > existing.MessageSeq {
			existing.MessageSeq = int64(messageSeq)
		}
	}
	result := make([]*userLastOffsetModel, 0, len(byChannel))
	for _, item := range byChannel {
		result = append(result, item)
	}
	return result
}

func (co *Conversation) clearSyncConversationCache(userKey string) {
	co.syncConversationResultCacheLock.Lock()
	delete(co.syncConversationResultCacheMap, userKey)
	delete(co.syncConversationVersionMap, userKey)
	co.syncConversationResultCacheLock.Unlock()
}
```

Update `syncUserConversationAck` to call the helper instead of nested-loop dedupe. Clear cache only after DB writes and max-version write succeed.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
go test -count=1 ./modules/message -run 'TestBuildUserLastOffsetsDedupesByChannelWithMaxSeq|TestClearSyncConversationCacheRemovesUserEntries'
```

Expected: PASS.

## Task 3: MinIO Client Reuse And Bucket Readiness Cache

**Files:**
- Modify: `.codex-backend-work/src/modules/file/service_minio.go`
- Modify: `.codex-backend-work/src/modules/file/service_minio_test.go`

- [ ] **Step 1: Add tests around reusable MinIO dependency**

If current tests use concrete MinIO helpers only, introduce a small interface around the methods used by `UploadFile`:

```go
type minioClient interface {
	BucketExists(context.Context, string) (bool, error)
	MakeBucket(context.Context, string, minio.MakeBucketOptions) error
	SetBucketPolicy(context.Context, string, string) error
	PutObject(context.Context, string, string, io.Reader, int64, minio.PutObjectOptions) (minio.UploadInfo, error)
}
```

Add a fake client test proving two uploads to the same bucket call `BucketExists` once.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
go test -count=1 ./modules/file -run 'TestServiceMinio'
```

Expected: new readiness-cache test fails before implementation.

- [ ] **Step 3: Implement client factory and bucket cache**

Add fields to `ServiceMinio`:

```go
minioMu       sync.Mutex
minioClient   minioClient
readyBuckets  map[string]struct{}
clientFactory func(endpoint string, opts *minio.Options) (minioClient, error)
```

Rules:

- Create the MinIO client once per service/config instance.
- Protect client and ready bucket map with `minioMu`.
- If `BucketExists` or `MakeBucket` fails, do not mark bucket ready.
- If `SetBucketPolicy` fails after bucket creation, do not mark bucket ready.
- Do not cache failed bucket checks.

- [ ] **Step 4: Run file tests**

Run:

```powershell
go test -count=1 ./modules/file -run 'TestServiceMinio|TestMinio'
```

Expected: PASS.

## Task 4: Storage Operation Metrics

**Files:**
- Modify: `.codex-backend-work/src/serverlib/pkg/metrics/metrics.go`
- Modify: `.codex-backend-work/src/serverlib/pkg/metrics/metrics_test.go`
- Modify: `.codex-backend-work/src/modules/file/service_minio.go`

- [ ] **Step 1: Add metrics tests**

Add a test:

```go
func TestStorageOperationMetricsDoNotLeakObjectPaths(t *testing.T) {
	recorder := NewRecorder()
	recorder.ObserveStorageOperation("minio", "put_object", time.Millisecond, nil)
	recorder.ObserveStorageOperation("minio", "bucket_exists", 2*time.Millisecond, assertErr("bucket /avatar/u1.png failed"))

	body := recorder.GatherText()
	require.Contains(t, body, `wukongim_storage_operation_total{provider="minio",operation="put_object",result="success"} 1`)
	require.Contains(t, body, `wukongim_storage_operation_total{provider="minio",operation="bucket_exists",result="failure"} 1`)
	require.NotContains(t, body, "avatar")
	require.NotContains(t, body, "u1.png")
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths
```

Expected: FAIL because storage metrics do not exist.

- [ ] **Step 3: Implement storage metrics**

Add storage operation counter and histogram using labels:

- `provider`
- `operation`
- `result`

Do not include bucket, object path, filename, UID, group number, or error text in labels.

- [ ] **Step 4: Instrument MinIO**

Wrap these phases:

- client creation
- bucket exists check
- bucket creation
- policy set
- put object

Use `provider="minio"` and stable operation names.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
go test -count=1 ./pkg/metrics ./modules/file -run 'TestStorageOperationMetricsDoNotLeakObjectPaths|TestServiceMinio|TestMinio'
```

Expected: PASS.

## Task 5: Patch Artifact And Phase 3 Prepare Script

**Files:**
- Create: `deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch`
- Create: `scripts/ops/phase3_backend_optimization_prepare.ps1`
- Create: `test/scripts/ops/phase3_backend_optimization_prepare_test.dart`

- [ ] **Step 1: Add failing script tests**

Create Dart tests asserting:

- dry-run is default;
- production sync requires `-Run -AllowProductionSync`;
- production build requires `-BuildImage -AllowProductionBuild`;
- allowlist contains only backend files changed in Tasks 1-4;
- output includes backup directory variable;
- output does not include secrets or token values.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase3_backend_optimization_prepare_test.dart
```

Expected: FAIL because the script does not exist.

- [ ] **Step 3: Implement script by copying Phase 2 pattern**

Use `scripts/ops/phase2_backend_metrics_prepare.ps1` as the pattern, but change:

- script name and task labels to Phase 3 backend optimization;
- patch path to `deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch`;
- allowlist to the exact backend files touched by Tasks 1-4;
- backup dir name to `phase3-backend-optimization-source-sync`.

- [ ] **Step 4: Generate tracked patch**

From the backend snapshot baseline, generate the patch containing only changed backend files. Verify:

```powershell
git diff -- deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch
```

Expected: patch includes only intended backend changes.

- [ ] **Step 5: Run script tests**

Run:

```powershell
flutter test test/scripts/ops/phase3_backend_optimization_prepare_test.dart
```

Expected: PASS.

## Task 6: Production Rollout Runbook And PromQL Gates

**Files:**
- Create: `docs/production/phase3-backend-optimization-rollout.md`

- [ ] **Step 1: Write runbook**

Include:

- preflight commands;
- PromQL baseline commands;
- dry-run command;
- sync command;
- build command;
- explicit service switch command using `phase6_backend_service_switch.ps1`;
- smoke checks;
- rollback using the Phase 3 backup directory;
- 30-minute post-switch observation gates.

Required PromQL gates:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum by (operation, result) (increase(wukongim_operation_total[30m]))
sum by (provider, operation, result) (increase(wukongim_storage_operation_total[30m]))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

- [ ] **Step 2: Add or update tests if this repo has rollout-doc tests**

If no existing doc test pattern applies, add this runbook to the Phase 3 script test expected docs list.

- [ ] **Step 3: Verify documentation has no secrets**

Run:

```powershell
git diff -- docs/production/phase3-backend-optimization-rollout.md | python scripts\ops\secret_log_scan.py --source phase3-runbook
```

Expected: PASS.

## Task 7: Full Verification And Commit

**Files:**
- All files from Tasks 1-6

- [ ] **Step 1: Run backend tests**

Run from `.codex-backend-work/src/serverlib`:

```powershell
go test -count=1 ./pkg/metrics ./modules/user ./modules/message ./modules/file
```

Expected: PASS.

- [ ] **Step 2: Run rollout/script tests**

Run from repo root:

```powershell
flutter test test/scripts/ops/phase3_backend_optimization_prepare_test.dart
flutter test test/scripts/ops/phase2_backend_metrics_prepare_test.dart
flutter test test/scripts/ops/backend_metrics_rollout_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run diff checks**

Run:

```powershell
git diff --check
git diff | python scripts\ops\secret_log_scan.py --source phase3-backend-optimization
```

Expected: PASS.

- [ ] **Step 4: Stage only Phase 3 files**

Do not stage unrelated existing client/admin/release package changes.

```powershell
git add deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch `
  scripts/ops/phase3_backend_optimization_prepare.ps1 `
  test/scripts/ops/phase3_backend_optimization_prepare_test.dart `
  docs/production/phase3-backend-optimization-rollout.md `
  docs/superpowers/artifacts/2026-05-26-phase3-production-bottleneck-analysis.md `
  docs/superpowers/plans/2026-05-26-phase3-production-backend-optimization.md
```

- [ ] **Step 5: Commit**

```powershell
git commit -m "perf: plan phase3 backend optimization"
```

Expected: commit succeeds with only Phase 3 tracked artifacts.

## Execution Notes

- Do not deploy this plan automatically. Production deployment requires explicit approval after implementation and local verification.
- Do not include DB schema changes in this first batch. Index work should be a separate Phase 3 Batch 2 plan with production DDL rollback strategy.
- Do not include client package rebuilds in this backend batch.
- If production metrics after implementation show p95/p99 regression above thresholds, rollback the backend batch before continuing to Batch 2.
