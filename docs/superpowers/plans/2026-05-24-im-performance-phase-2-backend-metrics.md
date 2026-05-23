# IM Performance Phase 2 Backend Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe backend HTTP and IM operation metrics for WuKongIM/TangSengDaoDao API, expose them through protected `/metrics`, and make the production rollout auditable.

**Architecture:** The backend source snapshot lives in ignored local directory `.codex-backend-work/src`, so implementation is validated there but committed as a tracked patch plus rollout tooling. Metrics live in `serverlib/pkg/metrics` for shared HTTP middleware and are called from API modules for operation-level timers. To avoid widening backend dependency risk, the package emits standard Prometheus text exposition directly with the Go standard library rather than adding `client_golang`. Production deployment is a separate approval-gated step that syncs only the files listed by the Phase 2 release script.

**Tech Stack:** Go 1.20, Gin, Prometheus text exposition format, PowerShell deployment scripts, Prometheus scrape config

---

## Scope Note

This plan covers Phase 2 only: backend HTTP metrics, operation timers, protected metrics exposure, local tests, and rollout artifacts. It does not deploy to production without explicit approval, and it does not change Nginx rate limits, database indexes, Redis settings, or load-test behavior. Those remain later phases after metrics are available.

## File Structure And Ownership

- Create in ignored validation workspace: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib\pkg\metrics\metrics.go` - in-memory counters/histograms, HTTP middleware, operation timer, protected handler, route normalization helpers, Prometheus text output.
- Create in ignored validation workspace: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib\pkg\metrics\metrics_test.go` - middleware, labels, protected endpoint, and no-payload tests.
- Modify in ignored validation workspace: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\main.go` - install HTTP middleware before route registration and register protected `/metrics`.
- Modify in ignored validation workspace: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\modules\message\api.go` - record message sync/channel sync/message extra sync timers.
- Modify in ignored validation workspace: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\modules\file\api.go` - record upload and multipart operation timers.
- Create tracked patch: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\backend-metrics\patches\0001-backend-http-operation-metrics.patch` - reproducible diff from backend snapshot.
- Create tracked script: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\phase2_backend_metrics_prepare.ps1` - dry-run/apply/sync/build helper with approval gates.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\prometheus\prometheus.yml` - scrape local API `/metrics` with optional bearer token env placeholder documented.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\docker-compose.yml` - mount the local metrics token file into Prometheus as read-only runtime secret material.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\monitoring\prometheus.yml` - same production scrape target update, using a runtime token file instead of inline secrets.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\docker-compose.observability.yaml` - mount the metrics token file into Prometheus as read-only runtime secret material.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\docker-compose.yaml` - pass `WUKONGIM_METRICS_TOKEN` to `tsdd-api`.
- Modify tracked config: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\.env.example` - document the metrics token placeholder without committing a real token.
- Create tracked docs: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\backend-metrics-rollout.md` - rollout, rollback, smoke, and metric queries.

## Task 1: Add Backend Metrics Package

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib\pkg\metrics\metrics.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib\pkg\metrics\metrics_test.go`

- [ ] **Step 1: Write failing metrics tests**

Create `serverlib/pkg/metrics/metrics_test.go` in the backend snapshot with tests for:

```go
package metrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestMiddlewareRecordsNormalizedRouteStatusClassAndLatency(t *testing.T) {
	gin.SetMode(gin.TestMode)
	recorder := NewRecorder()
	router := gin.New()
	router.Use(recorder.GinMiddleware())
	router.GET("/v1/users/:uid", func(c *gin.Context) {
		c.String(http.StatusCreated, "ok")
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/users/alice?token=secret", nil)
	router.ServeHTTP(w, req)

	body := recorder.GatherText()
	if !strings.Contains(body, `wukongim_http_requests_total{method="GET",route="/v1/users/:uid",status_class="2xx"} 1`) {
		t.Fatalf("missing normalized request counter:\n%s", body)
	}
	if strings.Contains(body, "alice") || strings.Contains(body, "secret") {
		t.Fatalf("metrics leaked path/query data:\n%s", body)
	}
}

func TestMiddlewareUsesUnknownRouteForUnmatchedPaths(t *testing.T) {
	gin.SetMode(gin.TestMode)
	recorder := NewRecorder()
	router := gin.New()
	router.Use(recorder.GinMiddleware())

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/scanner/admin", strings.NewReader(`{"token":"secret"}`))
	router.ServeHTTP(w, req)

	body := recorder.GatherText()
	if !strings.Contains(body, `route="unknown"`) {
		t.Fatalf("expected unknown route label:\n%s", body)
	}
	if strings.Contains(body, "scanner") || strings.Contains(body, "secret") {
		t.Fatalf("metrics leaked unmatched path or body:\n%s", body)
	}
}

func TestOperationTimerRecordsResultWithoutPayloadLabels(t *testing.T) {
	recorder := NewRecorder()
	done := recorder.StartOperation("message_sync")
	done(nil)
	failed := recorder.StartOperation("file_upload")
	failed(assertErr("upload failed"))

	body := recorder.GatherText()
	for _, want := range []string{
		`wukongim_operation_total{operation="message_sync",result="success"} 1`,
		`wukongim_operation_total{operation="file_upload",result="failure"} 1`,
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("missing %s in:\n%s", want, body)
		}
	}
	if strings.Contains(body, "upload failed") {
		t.Fatalf("metrics leaked error text:\n%s", body)
	}
}

func TestProtectedMetricsHandlerAllowsLocalhostOrBearerToken(t *testing.T) {
	recorder := NewRecorder()
	recorder.ObserveOperation("message_sync", time.Millisecond, nil)
	handler := recorder.ProtectedHandler("expected-token")

	unauthorized := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	req.RemoteAddr = "203.0.113.10:54321"
	handler.ServeHTTP(unauthorized, req)
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status = %d", unauthorized.Code)
	}

	authorized := httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/metrics", nil)
	req.RemoteAddr = "203.0.113.10:54321"
	req.Header.Set("Authorization", "Bearer expected-token")
	handler.ServeHTTP(authorized, req)
	if authorized.Code != http.StatusOK {
		t.Fatalf("authorized status = %d", authorized.Code)
	}

	local := httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/metrics", nil)
	req.RemoteAddr = "127.0.0.1:54321"
	handler.ServeHTTP(local, req)
	if local.Code != http.StatusOK {
		t.Fatalf("local status = %d", local.Code)
	}
}

type assertErr string

func (e assertErr) Error() string { return string(e) }
```

- [ ] **Step 2: Run tests and verify RED**

Run from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib`:

```powershell
go test ./pkg/metrics
```

Expected: FAIL because `pkg/metrics` does not exist.

- [ ] **Step 3: Implement metrics package without third-party dependencies**

Create `serverlib/pkg/metrics/metrics.go` with these required behaviors:

```go
type Recorder struct {
	mu               sync.Mutex
	httpRequests     map[httpLabelKey]uint64
	httpLatency      map[httpLabelKey]*histogram
	operationTotal   map[operationLabelKey]uint64
	operationLatency map[operationLabelKey]*histogram
}
```

The implementation must use only Go standard library plus existing Gin. `GatherText()` must render valid Prometheus text format with `# HELP`, `# TYPE`, `_bucket`, `_sum`, and `_count` lines. Use bounded fixed buckets:

- HTTP latency buckets: `0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10`
- Operation latency buckets: `0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30`

`ProtectedHandler` must set content type `text/plain; version=0.0.4; charset=utf-8`. When a token is configured it must require exact `Authorization: Bearer <token>` for every caller, including loopback. When the token is empty, it may allow loopback only and must reject non-loopback callers.

- [ ] **Step 4: Run metrics tests and verify GREEN**

Run:

```powershell
go test ./pkg/metrics
```

Expected: PASS.

## Task 2: Integrate HTTP Middleware And Protected `/metrics`

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\main.go`

- [ ] **Step 1: Add integration test by exercising a small Gin route**

If direct `main.go` testing is too coupled to config startup, add middleware registration coverage to `serverlib/pkg/metrics/metrics_test.go`:

```go
func TestProtectedHandlerDoesNotRegisterPayloadLabels(t *testing.T) {
	recorder := NewRecorder()
	router := gin.New()
	router.Use(recorder.GinMiddleware())
	router.POST("/v1/message/sync", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})
	router.GET("/metrics", gin.WrapH(recorder.ProtectedHandler("token")))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/message/sync", strings.NewReader(`{"channel_id":"c1","token":"secret"}`))
	router.ServeHTTP(w, req)

	metrics := httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/metrics", nil)
	req.RemoteAddr = "127.0.0.1:10000"
	router.ServeHTTP(metrics, req)

	body := metrics.Body.String()
	if !strings.Contains(body, `route="/v1/message/sync"`) {
		t.Fatalf("missing message sync metric:\n%s", body)
	}
	if strings.Contains(body, "channel_id") || strings.Contains(body, "secret") || strings.Contains(body, "c1") {
		t.Fatalf("metrics leaked request payload:\n%s", body)
	}
}
```

- [ ] **Step 2: Run test and verify RED if handler wiring helper is missing**

Run:

```powershell
go test ./pkg/metrics
```

Expected: FAIL only if the package needs small imports or helper adjustment.

- [ ] **Step 3: Wire metrics into API startup**

In `.codex-backend-work/src/main.go`, import:

```go
servermetrics "github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/metrics"
```

In `runAPI`, immediately after `ctx.SetHttpRoute(s.GetRoute())`, add:

```go
	s.GetRoute().UseGin(servermetrics.GinMiddleware())
	s.GetRoute().GET("/metrics", func(c *wkhttp.Context) {
		servermetrics.ProtectedHandler(strings.TrimSpace(os.Getenv("WUKONGIM_METRICS_TOKEN"))).ServeHTTP(c.Writer, c.Request)
	})
```

If `wkhttp` is not already imported in `main.go`, add:

```go
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
```

- [ ] **Step 4: Run targeted build/test**

Run from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib`:

```powershell
go test ./pkg/metrics
```

Then run from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src`:

```powershell
go test .
```

Expected: PASS.

## Task 3: Add Operation Timers To Core IM Paths

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\modules\message\api.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\modules\file\api.go`

- [ ] **Step 1: Add helper tests for result recording**

Keep result semantics in `serverlib/pkg/metrics/metrics_test.go` covered by `TestOperationTimerRecordsResultWithoutPayloadLabels`. No database-backed API tests are required for this thin instrumentation because the handlers have broad external dependencies.

- [ ] **Step 2: Add message operation timers**

In `modules/message/api.go`, import:

```go
servermetrics "github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/metrics"
```

At the top of each handler add a named `opErr` and deferred recorder:

```go
	var opErr error
	done := servermetrics.StartOperation("message_extra_sync")
	defer func() { done(opErr) }()
```

Use operation names:

- `message_extra_sync` in `syncMessageExtra`
- `message_channel_sync` in `syncChannelMessage`
- `message_sync` in `sync`

Before each error response in those handlers, assign the real error to `opErr`, for example:

```go
	if err := c.BindJSON(&req); err != nil {
		opErr = err
		c.ResponseErrorf("...", err)
		return
	}
```

Use `opErr = errors.New("group_member_not_found")` for the empty group-member branch if it returns early as an expected non-error, do not mark it failure unless the handler returns an error status. Successful empty responses must keep `opErr == nil`.

- [ ] **Step 3: Add file operation timers**

In `modules/file/api.go`, import:

```go
servermetrics "github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/metrics"
```

Add the same `opErr`/defer pattern with operation names:

- `file_upload` in `uploadFile`
- `file_multipart_init` in `initiateMultipartUpload`
- `file_multipart_part` in `uploadMultipartPart`
- `file_multipart_complete` in `completeMultipartUpload`

Before each error response in those handlers, assign `opErr = err`.

- [ ] **Step 4: Run targeted package tests**

Run from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib`:

```powershell
go test ./pkg/metrics
```

Then run the message/file compile gate from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src`.
Full package tests are known to depend on pre-existing MySQL/assets state, so Phase 2 uses `-run '^$'` here to compile the instrumented packages without executing those package tests:

```powershell
go test -count=1 -mod=readonly -run '^$' ./modules/message ./modules/file
```

Expected: PASS compile gate.

## Task 4: Generate Tracked Patch And Rollout Script

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\backend-metrics\patches\0001-backend-http-operation-metrics.patch`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\phase2_backend_metrics_prepare.ps1`

- [ ] **Step 1: Generate patch from backend snapshot**

Create a clean baseline copy before generating the patch. Run from repo root:

```powershell
$baselineRoot = Join-Path $env:TEMP 'wukongim-backend-metrics-baseline'
if (Test-Path $baselineRoot) { Remove-Item -LiteralPath $baselineRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $baselineRoot | Out-Null
$backendRoot = Resolve-Path '.codex-backend-work/src'
$files = @(
  'main.go',
  'modules/message/api.go',
  'modules/file/api.go',
  'serverlib/pkg/metrics/metrics.go',
  'serverlib/pkg/metrics/metrics_test.go'
)
foreach ($relative in $files) {
  $source = Join-Path $backendRoot $relative
  $target = Join-Path $baselineRoot $relative
  New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
  Copy-Item -LiteralPath $source -Destination $target
}
```

Then generate the patch after Tasks 1-3 have modified `.codex-backend-work/src`:

```powershell
New-Item -ItemType Directory -Force -Path 'deploy/production/backend-metrics/patches' | Out-Null
git diff --no-index -- `
  $baselineRoot `
  '.codex-backend-work/src' `
  -- `
  main.go modules/message/api.go modules/file/api.go serverlib/pkg/metrics `
  > 'deploy/production/backend-metrics/patches/0001-backend-http-operation-metrics.patch'
if ($LASTEXITCODE -eq 1) { $global:LASTEXITCODE = 0 }
```

Expected: patch file contains only Phase 2 backend metrics changes and can be inspected without committing ignored backend source.

- [ ] **Step 2: Create approval-gated rollout script**

Create `scripts/ops/phase2_backend_metrics_prepare.ps1` with a script that:

- Defaults `LocalBackendRoot` to `.codex-backend-work/src`.
- Applies `deploy/production/backend-metrics/patches/0001-backend-http-operation-metrics.patch` locally when `-ApplyLocalPatch` is provided.
- Runs full `go test -count=1 ./pkg/metrics` from `serverlib`, then the backend module compile gate `go test -count=1 -mod=readonly -run '^$' ./modules/message ./modules/file` from the backend root when `-RunTests` is provided. The compile gate is intentional because the full module tests require external MySQL/test assets in the current environment.
- Syncs only changed backend files to `/opt/wukongim-prod/src` when `-Run -AllowProductionSync` is provided.
- Builds `tsdd-api` when `-BuildImage -AllowProductionBuild` is provided.
- Never restarts production services; service switch remains a separate explicit command.

- [ ] **Step 3: Parse-check the script**

Run:

```powershell
$script = Get-Content -Raw scripts/ops/phase2_backend_metrics_prepare.ps1
$null = [scriptblock]::Create($script)
```

Expected: no parser error.

## Task 5: Update Prometheus Config And Rollout Docs

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\prometheus\prometheus.yml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\docker-compose.yml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\monitoring\prometheus.yml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\docker-compose.observability.yaml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\docker-compose.yaml`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\deploy\production\.env.example`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\backend-metrics-rollout.md`

- [ ] **Step 1: Update Prometheus scrape config**

In both Prometheus config files, ensure `wukongim_api` scrapes:

```yaml
  - job_name: wukongim_api
    metrics_path: /metrics
    static_configs:
      - targets:
          - host.docker.internal:8080
```

Do not commit any bearer token. If production uses a token, document that Prometheus should receive it through runtime secret configuration.
Configure `authorization.credentials_file` to read `/run/secrets/wukongim_metrics_token`, mount `./secrets/wukongim_metrics_token` into Prometheus as read-only in both monitoring compose files, and pass the same token to `tsdd-api` through `WUKONGIM_METRICS_TOKEN`.

- [ ] **Step 2: Add rollout doc**

Create `docs/production/backend-metrics-rollout.md` covering:

- Local validation commands.
- Production sync command requiring `-Run -AllowProductionSync`.
- Optional build command requiring `-BuildImage -AllowProductionBuild`.
- Separate service switch command requiring explicit approval.
- Smoke checks: `/v1/ping`, localhost `/metrics`, Prometheus target health.
- Rollback: restore backed-up files from script output and rebuild/recreate `tsdd-api`.
- Metric queries: request rate, p95 latency, 5xx rate, operation p95, file upload failures.

## Task 6: Final Verification And Commit

**Files:**
- All Phase 2 tracked files.

- [ ] **Step 1: Run backend tests**

Run from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src\serverlib`:

```powershell
go test ./pkg/metrics
```

Then run the message/file compile gate from `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src`:

```powershell
go test -count=1 -mod=readonly -run '^$' ./modules/message ./modules/file
```

Expected: PASS compile gate.

- [ ] **Step 2: Run script parse checks**

Run from repo root:

```powershell
$script = Get-Content -Raw scripts/ops/phase2_backend_metrics_prepare.ps1
$null = [scriptblock]::Create($script)
```

Expected: no parser error.

- [ ] **Step 3: Run diff hygiene and secret scans**

Run:

```powershell
git diff --check
git diff | python scripts/ops/secret_log_scan.py --source phase2-backend-metrics
```

Expected: both exit 0.

- [ ] **Step 4: Commit tracked artifacts**

Run:

```powershell
git add docs/superpowers/plans/2026-05-24-im-performance-phase-2-backend-metrics.md deploy/production/backend-metrics/patches/0001-backend-http-operation-metrics.patch scripts/ops/phase2_backend_metrics_prepare.ps1 test/scripts/ops/phase2_backend_metrics_prepare_test.dart test/scripts/ops/backend_metrics_rollout_test.dart ops/monitoring/prometheus/prometheus.yml ops/monitoring/docker-compose.yml deploy/production/monitoring/prometheus.yml deploy/production/docker-compose.observability.yaml deploy/production/docker-compose.yaml deploy/production/.env.example docs/production/backend-metrics-rollout.md
git commit -m "feat: add backend metrics rollout artifacts"
```

## Spec Coverage Self-Review

- Backend HTTP request count, latency, and status by normalized route: Task 1 and Task 2.
- Operation timers for message sync/channel sync/message extra sync/file upload: Task 3.
- Protected metrics exposure: Task 1 and Task 2.
- Low-cardinality labels only: Task 1 tests and implementation.
- No token/body/payload/user/channel labels: Task 1 tests.
- Production-safe rollout and rollback: Task 4 and Task 5.
- Nginx edge hygiene and load testing: intentionally excluded until metrics are deployed and approved.
