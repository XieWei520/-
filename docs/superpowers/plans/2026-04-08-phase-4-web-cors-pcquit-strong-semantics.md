# Phase 4 Web CORS And PC-Quit Strong Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the last truthful Phase 4 gaps by fixing production nginx CORS for normal-browser Flutter Web and redefining `POST /v1/user/pc/quit` so it removes other PC/Web device rows while preserving the current device.

**Architecture:** Keep Flutter as a thin client. Production CORS must be repaired at the nginx edge, backend device truth must be strengthened with a persisted `device_flag` plus request-header-based current-device resolution, and Flutter should only update user-facing copy and regression tests to match the stronger backend semantics.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Go, MySQL migrations, nginx, Docker Compose, PowerShell, SSH, curl, TangSengDaoDaoServer backend

---

**Workspace Note:** `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app` is not backed by `.git` metadata. Use the checkpoint `git add` and `git commit` commands below only in a canonical checkout or server-side repo clone. In this local copy, record the same checkpoints together with analyzer, test, curl, and live-runtime evidence.

## Scope Boundary

This plan implements the approved design at [2026-04-08-phase-4-web-cors-pcquit-strong-semantics-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-08-phase-4-web-cors-pcquit-strong-semantics-design.md).

In scope:

- production nginx CORS repair for `X-Device-ID` and `X-Device-Session-ID`
- additive `device.device_flag` persistence and write-path upgrades
- stronger `/v1/user/pc/quit` semantics that remove other PC/Web rows while preserving the current device
- truthful `GET /v1/user/devices` self-marker resolution from request headers
- Flutter device-management copy and tests aligned to the stronger meaning
- live verification on `42.194.218.158` and `https://wemx.cc`

Out of scope:

- broader auth architecture work already closed in the earlier Phase 4 convergence plan
- unrelated chat, contacts, settings, call, or search modules
- speculative QR encryption or product redesign beyond regression coverage

## File Structure

### New Files

- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/sql/user-20260408-01.sql`
  - Adds `device.device_flag` and an index that supports PC/Web cleanup without changing the device-list payload shape.
- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_device_test.go`
  - Locks device persistence, header-based self resolution, and strong `/v1/user/pc/quit` semantics with focused backend tests.

### Existing Backend Files To Modify

- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/nginx/default.conf.template`
  - Must return correct CORS headers for `OPTIONS` and normal responses through the production nginx edge.
- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/db_device.go`
  - Must persist `device_flag`, expose it on reads, and provide a safe delete helper for "remove other PC/Web devices".
- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api.go`
  - Must stamp `device_flag` on all relevant device writes: normal login, auth-code login, login verification completion, and register/create-user paths that insert device rows.
- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_device.go`
  - Must derive `self` from `X-Device-ID` instead of "first row wins", while keeping response shape stable.
- `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_online.go`
  - Must change `pcQuit` from "quit online state only" to the stronger compound action.

### Existing Flutter Files To Modify

- `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
  - Must tell the truth that the action removes other PC/Web logins and preserves the current device.
- `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/auth/auth_device_sessions_web_login_test.dart`
  - Must lock the new copy and keep device-session page behavior covered.

### Remote Verification And Deployment Targets

- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/deploy/production/nginx/default.conf.template`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api.go`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_device.go`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_online.go`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/db_device.go`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/sql/user-20260408-01.sql`
- `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- `/opt/wukongim-prod/src/modules/user/api.go`
- `/opt/wukongim-prod/src/modules/user/api_device.go`
- `/opt/wukongim-prod/src/modules/user/api_online.go`
- `/opt/wukongim-prod/src/modules/user/db_device.go`
- `/opt/wukongim-prod/src/modules/user/sql/user-20260408-01.sql`

## Verification Commands Used Throughout

- `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/device/bind" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type,token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
- `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/devices" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
- `flutter analyze lib/modules/auth/presentation/pages/auth_device_sessions_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart`
- `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
- `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run 'TestInsertOrUpdateDevicePersistsDeviceFlag|TestDeviceListMarksHeaderMatchedDeviceAsSelf|TestUserPcQuitRemovesOtherPcWebDevicesButKeepsCurrentAndApp' -count=1"`
- `ssh -F NUL ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && docker compose -f deploy/production/docker-compose.yaml up -d --build nginx tsdd-api"`
- `ssh -F NUL ubuntu@42.194.218.158 "docker logs --since 15m wukongim_prod-tsdd-api-1 | grep -E '/v1/user/device/bind|/v1/user/devices|/v1/user/pc/quit|/v1/user/loginuuid|/v1/user/loginstatus|/v1/user/grant_login'"`

### Task 1: Repair Production Nginx CORS For Normal Browser Startup

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/deploy/production/nginx/default.conf.template`
- Deploy mirror: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`

- [ ] **Step 1: Reproduce the failing preflight before touching nginx**

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/device/bind" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type,token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: `204` or `200`, but `Access-Control-Allow-Headers` is missing `X-Device-ID` and `X-Device-Session-ID`

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/devices" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: same missing-header failure pattern on a second authenticated route

- [ ] **Step 2: Patch both nginx server blocks to answer truthful CORS headers**

```nginx
server {
    listen 80 default_server;
    server_name _;
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    set $cors_allow_headers "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, token, accept, origin, Cache-Control, X-Requested-With, appid, noncestr, sign, timestamp, X-Device-ID, X-Device-Session-ID";
    set $cors_allow_methods "GET, POST, PUT, DELETE, PATCH, OPTIONS";

    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin $http_origin always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Allow-Headers $cors_allow_headers always;
        add_header Access-Control-Allow-Methods $cors_allow_methods always;
        add_header Access-Control-Max-Age 86400 always;
        add_header Vary "Origin" always;
        add_header Content-Length 0;
        add_header Content-Type text/plain;
        return 204;
    }

    add_header Access-Control-Allow-Origin $http_origin always;
    add_header Access-Control-Allow-Credentials "true" always;
    add_header Vary "Origin" always;

    location /v1/user/login {
        limit_req zone=login_limit burst=20 nodelay;
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
```

```nginx
server {
    listen 443 ssl http2;
    server_name ${PUBLIC_DOMAIN};
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    set $cors_allow_headers "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, token, accept, origin, Cache-Control, X-Requested-With, appid, noncestr, sign, timestamp, X-Device-ID, X-Device-Session-ID";
    set $cors_allow_methods "GET, POST, PUT, DELETE, PATCH, OPTIONS";

    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin $http_origin always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Allow-Headers $cors_allow_headers always;
        add_header Access-Control-Allow-Methods $cors_allow_methods always;
        add_header Access-Control-Max-Age 86400 always;
        add_header Vary "Origin" always;
        add_header Content-Length 0;
        add_header Content-Type text/plain;
        return 204;
    }

    add_header Access-Control-Allow-Origin $http_origin always;
    add_header Access-Control-Allow-Credentials "true" always;
    add_header Vary "Origin" always;
}
```

- [ ] **Step 3: Rebuild only nginx in the production compose stack**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && docker compose -f deploy/production/docker-compose.yaml up -d --build nginx"`
Expected: `wukongim_prod-nginx-1` rebuilds cleanly and returns to healthy/running status

- [ ] **Step 4: Re-run preflight verification on both API paths**

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/device/bind" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type,token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: `Access-Control-Allow-Headers` now includes both `X-Device-ID` and `X-Device-Session-ID`

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/devices" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: second route matches the same fixed header set

- [ ] **Step 5: Checkpoint**

```bash
git add deploy/production/nginx/default.conf.template
git commit -m "fix: allow device headers through production cors"
```

### Task 2: Persist `device_flag` On Device Rows And All Device Write Paths

**Files:**
- Create: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/sql/user-20260408-01.sql`
- Create: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_device_test.go`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/db_device.go`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api.go`

- [ ] **Step 1: Write the failing device persistence test first**

```go
package user

import (
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

func TestInsertOrUpdateDevicePersistsDeviceFlag(t *testing.T) {
	s, ctx := testutil.NewTestServer()
	_ = s
	assert.NoError(t, testutil.CleanAllTables(ctx))

	db := newDeviceDB(ctx)

	assert.NoError(t, db.insertOrUpdateDevice(&deviceModel{
		UID:         "device-flag-user",
		DeviceID:    "web-1",
		DeviceName:  "Chrome",
		DeviceModel: "Chrome",
		DeviceFlag:  config.Web.Uint8(),
		LastLogin:   1712563200,
	}))

	devices, err := db.queryDeviceWithUID("device-flag-user")
	assert.NoError(t, err)
	if assert.Len(t, devices, 1) {
		assert.Equal(t, uint8(config.Web), devices[0].DeviceFlag)
	}

	assert.NoError(t, db.insertOrUpdateDevice(&deviceModel{
		UID:         "device-flag-user",
		DeviceID:    "web-1",
		DeviceName:  "Windows",
		DeviceModel: "Windows",
		DeviceFlag:  config.PC.Uint8(),
		LastLogin:   1712563300,
	}))

	devices, err = db.queryDeviceWithUID("device-flag-user")
	assert.NoError(t, err)
	if assert.Len(t, devices, 1) {
		assert.Equal(t, uint8(config.PC), devices[0].DeviceFlag)
		assert.Equal(t, "Windows", devices[0].DeviceName)
	}
}
```

- [ ] **Step 2: Run the targeted backend test to verify it fails**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run TestInsertOrUpdateDevicePersistsDeviceFlag -count=1"`
Expected: FAIL because `deviceModel` and the `device` table do not yet persist `device_flag`

- [ ] **Step 3: Add the migration, DB field, and login write-path updates**

```sql
-- +migrate Up

ALTER TABLE `device`
  ADD COLUMN `device_flag` SMALLINT NOT NULL DEFAULT 0 COMMENT '设备标记 0.APP 1.Web 2.PC' AFTER `device_model`;

CREATE INDEX `device_uid_flag_last_login_idx`
  ON `device` (`uid`, `device_flag`, `last_login`);

-- +migrate Down

DROP INDEX `device_uid_flag_last_login_idx` ON `device`;
ALTER TABLE `device` DROP COLUMN `device_flag`;
```

```go
type deviceModel struct {
	UID         string
	DeviceID    string
	DeviceName  string
	DeviceModel string
	DeviceFlag  uint8
	LastLogin   int64
	db.BaseModel
}

func (d *deviceDB) insertOrUpdateDevice(m *deviceModel) error {
	_, err := d.session.InsertBySql(`
insert into device(uid,device_id,device_name,device_model,device_flag,last_login)
values(?,?,?,?,?,?)
ON DUPLICATE KEY UPDATE
device_name=VALUES(device_name),
device_model=VALUES(device_model),
device_flag=VALUES(device_flag),
last_login=VALUES(last_login)
`, m.UID, m.DeviceID, m.DeviceName, m.DeviceModel, m.DeviceFlag, m.LastLogin).Exec()
	return err
}
```

```go
err := u.deviceDB.insertOrUpdateDeviceCtx(loginSpanCtx, &deviceModel{
	UID:         userInfo.UID,
	DeviceID:    device.DeviceID,
	DeviceName:  device.DeviceName,
	DeviceModel: device.DeviceModel,
	DeviceFlag:  flag.Uint8(),
	LastLogin:   time.Now().Unix(),
})
```

```go
err := u.deviceDB.insertOrUpdateDeviceCtx(spanCtx, &deviceModel{
	UID:         userModel.UID,
	DeviceID:    deviceId,
	DeviceName:  deviceName,
	DeviceModel: dmodel,
	DeviceFlag:  flag.Uint8(),
	LastLogin:   time.Now().Unix(),
})
```

```go
err = u.deviceDB.insertOrUpdateDeviceCtx(spanCtx, &deviceModel{
	UID:         userInfo.UID,
	DeviceID:    loginDeivce.DeviceID,
	DeviceName:  loginDeivce.DeviceName,
	DeviceModel: loginDeivce.DeviceModel,
	DeviceFlag:  config.APP.Uint8(),
	LastLogin:   time.Now().Unix(),
})
```

```go
err = u.deviceDB.insertOrUpdateDeviceTx(&deviceModel{
	UID:         createUser.UID,
	DeviceID:    createUser.Device.DeviceID,
	DeviceName:  createUser.Device.DeviceName,
	DeviceModel: createUser.Device.DeviceModel,
	DeviceFlag:  config.DeviceFlag(createUser.Flag).Uint8(),
	LastLogin:   time.Now().Unix(),
}, tx)
```

- [ ] **Step 4: Re-run the focused backend checks**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run 'TestInsertOrUpdateDevicePersistsDeviceFlag|TestUser_Login|TestLoginCheckPhone' -count=1"`
Expected: PASS with the new column, DB upsert, and write paths all green

- [ ] **Step 5: Checkpoint**

```bash
git add modules/user/sql/user-20260408-01.sql modules/user/db_device.go modules/user/api.go modules/user/api_device_test.go
git commit -m "feat: persist device flag on login devices"
```

### Task 3: Strengthen `/v1/user/pc/quit` And Fix Device Self Resolution

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_online.go`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_device.go`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/db_device.go`
- Test: `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/user/api_device_test.go`

- [ ] **Step 1: Add failing backend tests for self marking and strong quit semantics**

```go
package user

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

func insertDeviceTestUser(t *testing.T, u *User) {
	t.Helper()
	assert.NoError(t, u.db.Insert(&Model{
		UID:      testutil.UID,
		Username: "phase4_user",
		Name:     "Phase4 User",
		Password: util.MD5(util.MD5("123456")),
		ShortNo:  "phase4_short",
		Status:   1,
	}))
}

func TestDeviceListMarksHeaderMatchedDeviceAsSelf(t *testing.T) {
	s, ctx := testutil.NewTestServer()
	u := New(ctx)
	u.Route(s.GetRoute())
	assert.NoError(t, testutil.CleanAllTables(ctx))
	insertDeviceTestUser(t, u)

	assert.NoError(t, u.deviceDB.insertOrUpdateDevice(&deviceModel{
		UID:         testutil.UID,
		DeviceID:    "pc-other",
		DeviceName:  "Windows",
		DeviceModel: "Windows",
		DeviceFlag:  config.PC.Uint8(),
		LastLogin:   300,
	}))
	assert.NoError(t, u.deviceDB.insertOrUpdateDevice(&deviceModel{
		UID:         testutil.UID,
		DeviceID:    "web-current",
		DeviceName:  "Chrome",
		DeviceModel: "Chrome",
		DeviceFlag:  config.Web.Uint8(),
		LastLogin:   200,
	}))

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/v1/user/devices", nil)
	req.Header.Set("token", testutil.Token)
	req.Header.Set("X-Device-ID", "web-current")
	s.GetRoute().ServeHTTP(w, req)

	var devices []deviceResp
	assert.NoError(t, util.ReadJsonByByte(w.Body.Bytes(), &devices))
	if assert.Len(t, devices, 2) {
		assert.Equal(t, "pc-other", devices[0].DeviceID)
		assert.Equal(t, 0, devices[0].Self)
		assert.Equal(t, "web-current", devices[1].DeviceID)
		assert.Equal(t, 1, devices[1].Self)
	}
}

func TestUserPcQuitRemovesOtherPcWebDevicesButKeepsCurrentAndApp(t *testing.T) {
	s, ctx := testutil.NewTestServer()
	u := New(ctx)
	u.Route(s.GetRoute())
	assert.NoError(t, testutil.CleanAllTables(ctx))
	insertDeviceTestUser(t, u)

	seed := []*deviceModel{
		{
			UID:         testutil.UID,
			DeviceID:    "web-current",
			DeviceName:  "Chrome",
			DeviceModel: "Chrome",
			DeviceFlag:  config.Web.Uint8(),
			LastLogin:   400,
		},
		{
			UID:         testutil.UID,
			DeviceID:    "pc-other",
			DeviceName:  "Windows",
			DeviceModel: "Windows",
			DeviceFlag:  config.PC.Uint8(),
			LastLogin:   300,
		},
		{
			UID:         testutil.UID,
			DeviceID:    "web-other",
			DeviceName:  "Edge",
			DeviceModel: "Edge",
			DeviceFlag:  config.Web.Uint8(),
			LastLogin:   200,
		},
		{
			UID:         testutil.UID,
			DeviceID:    "phone-1",
			DeviceName:  "iPhone",
			DeviceModel: "iOS",
			DeviceFlag:  config.APP.Uint8(),
			LastLogin:   100,
		},
	}
	for _, device := range seed {
		assert.NoError(t, u.deviceDB.insertOrUpdateDevice(device))
	}

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodPost, "/v1/user/pc/quit", nil)
	req.Header.Set("token", testutil.Token)
	req.Header.Set("X-Device-ID", "web-current")
	s.GetRoute().ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	devices, err := u.deviceDB.queryDeviceWithUID(testutil.UID)
	assert.NoError(t, err)
	remaining := make([]string, 0, len(devices))
	for _, device := range devices {
		remaining = append(remaining, device.DeviceID)
	}
	assert.ElementsMatch(t, []string{"web-current", "phone-1"}, remaining)
}
```

- [ ] **Step 2: Run the focused backend semantics tests and confirm they fail**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run 'TestDeviceListMarksHeaderMatchedDeviceAsSelf|TestUserPcQuitRemovesOtherPcWebDevicesButKeepsCurrentAndApp' -count=1"`
Expected: FAIL because `deviceList` still marks the first row as `self` and `pcQuit` still only clears online state

- [ ] **Step 3: Implement header-based self resolution and safe PC/Web row cleanup**

```go
func currentDeviceIDFromRequest(c *wkhttp.Context) string {
	return strings.TrimSpace(c.Request.Header.Get("X-Device-ID"))
}

func resolveSelfFlag(deviceID string, currentDeviceID string, index int) int {
	if currentDeviceID != "" {
		if deviceID == currentDeviceID {
			return 1
		}
		return 0
	}
	if index == 0 {
		return 1
	}
	return 0
}

func (u *User) deviceList(c *wkhttp.Context) {
	pageIndex, pageSize := c.GetPage()
	currentDeviceID := currentDeviceIDFromRequest(c)

	// existing query code stays the same

	for index, device := range devices {
		selft := resolveSelfFlag(device.DeviceID, currentDeviceID, index)
		deviceName := device.DeviceName
		if selft == 1 && pageIndex == 1 {
			deviceName = fmt.Sprintf("%s（本机）", device.DeviceName)
		}
		deviceResps = append(deviceResps, deviceResp{
			ID:          device.Id,
			DeviceID:    device.DeviceID,
			DeviceName:  deviceName,
			DeviceModel: device.DeviceModel,
			Self:        selft,
			LastLogin:   util.ToyyyyMMddHHmm(time.Unix(device.LastLogin, 0)),
		})
	}
}
```

```go
func (d *deviceDB) deleteOtherDevicesByFlags(uid string, currentDeviceID string, flags []uint8) error {
	query := d.session.DeleteFrom("device").Where("uid=?", uid).Where("device_flag in ?", flags)
	if strings.TrimSpace(currentDeviceID) != "" {
		query = query.Where("device_id<>?", currentDeviceID)
	}
	_, err := query.Exec()
	return err
}
```

```go
func (u *User) pcQuit(c *wkhttp.Context) {
	loginUID := c.GetLoginUID()
	currentDeviceID := strings.TrimSpace(c.Request.Header.Get("X-Device-ID"))

	if err := u.ctx.QuitUserDevice(loginUID, int(config.Web)); err != nil {
		u.Error("退出 web 设备失败", zap.Error(err))
		c.ResponseError(errors.New("退出 web 设备失败"))
		return
	}

	if err := u.ctx.QuitUserDevice(loginUID, int(config.PC)); err != nil {
		u.Error("退出 PC 设备失败", zap.Error(err))
		c.ResponseError(errors.New("退出 PC 设备失败"))
		return
	}

	if currentDeviceID != "" {
		err := u.deviceDB.deleteOtherDevicesByFlags(
			loginUID,
			currentDeviceID,
			[]uint8{config.Web.Uint8(), config.PC.Uint8()},
		)
		if err != nil {
			u.Error("删除其他 PC/Web 设备失败", zap.Error(err))
			c.ResponseError(errors.New("删除其他 PC/Web 设备失败"))
			return
		}
	} else {
		u.Warn("pcQuit missing X-Device-ID, skipped device-row cleanup", zap.String("uid", loginUID))
	}

	if err := u.ctx.SendCMD(config.MsgCMDReq{
		NoPersist:   true,
		ChannelID:   loginUID,
		ChannelType: common.ChannelTypePerson.Uint8(),
		CMD:         common.CMDPCQuit,
	}); err != nil {
		c.ResponseErrorf("发送指令失败！", err)
		return
	}

	c.ResponseOK()
}
```

- [ ] **Step 4: Re-run the strong-semantics test slice**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run 'TestInsertOrUpdateDevicePersistsDeviceFlag|TestDeviceListMarksHeaderMatchedDeviceAsSelf|TestUserPcQuitRemovesOtherPcWebDevicesButKeepsCurrentAndApp' -count=1"`
Expected: PASS with device persistence, self-marker truth, and batch cleanup all green

- [ ] **Step 5: Checkpoint**

```bash
git add modules/user/api_online.go modules/user/api_device.go modules/user/db_device.go modules/user/api_device_test.go
git commit -m "feat: strengthen pc quit device cleanup semantics"
```

### Task 4: Align Flutter Device-Management Copy With The Stronger Backend Meaning

**Files:**
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
- Modify: `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/auth/auth_device_sessions_web_login_test.dart`

- [ ] **Step 1: Write the failing Flutter copy assertions first**

```dart
testWidgets('device sessions page reflects remove-other-PC-Web semantics', (
  tester,
) async {
  final repository = _TrackingAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: AuthDeviceSessionsPage()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('登录设备管理'), findsOneWidget);
  expect(
    find.text('查看最近登录过当前账号的设备，并清理其他 PC/Web 登录'),
    findsOneWidget,
  );
  expect(find.text('当前设备不会被移除。'), findsOneWidget);
  expect(
    find.widgetWithText(FilledButton, '退出并移除其他 PC/Web 登录'),
    findsOneWidget,
  );
});

testWidgets('device sessions page shows stronger empty-state copy', (
  tester,
) async {
  final repository = _TrackingAuthRepository(
    initialDevices: const <LoginBridgeDeviceRecord>[],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: AuthDeviceSessionsPage()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('当前没有其他 PC/Web 登录设备需要清理。'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused Flutter test and verify it fails**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: FAIL because the page still uses ambiguous "退出全部 PC/Web 登录" copy and the old empty state

- [ ] **Step 3: Update the device page so the text tells the truth**

```dart
return AuthFlowShell(
  title: '登录设备管理',
  subtitle: '查看最近登录过当前账号的设备，并清理其他 PC/Web 登录',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.tonal(
        onPressed: state.isQuittingAll ? null : controller.quitAllPcWeb,
        child: Text(
          state.isQuittingAll ? '清理中...' : '退出并移除其他 PC/Web 登录',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '当前设备不会被移除。',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      if (state.items.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            '当前没有其他 PC/Web 登录设备需要清理。',
            textAlign: TextAlign.center,
          ),
        ),
    ],
  ),
);
```

- [ ] **Step 4: Re-run Flutter analyze and the focused device page tests**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS with the stronger button copy, current-device helper text, and empty state locked down

Run: `flutter analyze lib/modules/auth/presentation/pages/auth_device_sessions_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS with the page and test analyzer clean

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/auth/presentation/pages/auth_device_sessions_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart
git commit -m "fix: clarify pc web cleanup copy"
```

### Task 5: Deploy, Re-Verify Live Runtime Truth, And Close The Phase Honestly

**Files:**
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/deploy/production/nginx/default.conf.template`
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api.go`
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_device.go`
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_online.go`
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/db_device.go`
- Modify on staging first: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/sql/user-20260408-01.sql`
- Deploy mirror: `/opt/wukongim-prod/src/**`

- [ ] **Step 1: Run the local and staging regression packs before touching production**

Run: `flutter analyze lib/modules/auth/presentation/pages/auth_device_sessions_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main && go test ./modules/user -run 'TestInsertOrUpdateDevicePersistsDeviceFlag|TestDeviceListMarksHeaderMatchedDeviceAsSelf|TestUserPcQuitRemovesOtherPcWebDevicesButKeepsCurrentAndApp' -count=1"`
Expected: PASS

- [ ] **Step 2: Mirror the verified backend files into the live source tree and rebuild nginx plus API**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && docker compose -f deploy/production/docker-compose.yaml up -d --build nginx tsdd-api"`
Expected: `wukongim_prod-nginx-1` and `wukongim_prod-tsdd-api-1` rebuild cleanly and return to running state

- [ ] **Step 3: Re-check preflight CORS against the real public edge**

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/device/bind" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type,token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: `204` with `Access-Control-Allow-Headers` containing both device headers

Run: `curl.exe -i -X OPTIONS "https://wemx.cc/v1/user/devices" -H "Origin: http://localhost:7360" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: token,appid,noncestr,sign,timestamp,x-device-id,x-device-session-id"`
Expected: same fixed header set on the authenticated data route

- [ ] **Step 4: Verify live runtime behavior from Flutter and server logs**

Run: `ssh -F NUL ubuntu@42.194.218.158 "docker logs --since 15m wukongim_prod-tsdd-api-1 | grep -E '/v1/user/device/bind|/v1/user/devices|/v1/user/pc/quit|/v1/user/loginuuid|/v1/user/loginstatus|/v1/user/grant_login'"`
Expected: fresh lines for the exact endpoints below after you manually exercise the app

Manual runtime sequence:

- Open Flutter Web in a normal Chrome session, not with `--disable-web-security`.
- Sign in with the approved Phase 4 verification account and confirm the app restores into `#/home` without CORS failure.
- Open `#/auth/device-sessions` and confirm the page shows the stronger copy plus a truthful current-device marker.
- Create at least one other PC/Web row by signing into the same account from another Chrome profile or Windows desktop session.
- Trigger the batch action from the first session and confirm the UI refreshes to keep the current device while removing the other PC/Web rows.
- Re-open device management and confirm APP rows still remain.
- Re-run the earlier QR login confirm flow and confirm `loginuuid`, `loginstatus`, and `grant_login` still behave as before.

- [ ] **Step 5: Final exit gate**

Verify all of the following before claiming Phase 4 closure:

- normal-browser Flutter Web startup succeeds without a browser-security bypass
- both tested preflight routes allow `X-Device-ID` and `X-Device-Session-ID`
- `/v1/user/pc/quit` removes other PC/Web device rows
- the current device remains present after the batch action
- APP rows remain present after the batch action
- Flutter device page copy tells the same story as the backend behavior
- local Flutter checks, staging backend tests, and live logs all agree

```bash
git add deploy/production/nginx/default.conf.template modules/user/sql/user-20260408-01.sql modules/user/db_device.go modules/user/api.go modules/user/api_device.go modules/user/api_online.go lib/modules/auth/presentation/pages/auth_device_sessions_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart
git commit -m "feat: close phase 4 web cors and pc quit truth gap"
```

## Self-Review

### Spec Coverage

Covered:

- production-edge CORS repair at nginx
- persisted `device_flag` on the `device` table
- login and auth-code device writes stamped with device class
- strong `/v1/user/pc/quit` semantics for other PC/Web rows only
- current-device preservation through request `X-Device-ID`
- device-list `self` truth instead of "first row wins"
- Flutter copy and regression tests aligned to the stronger action
- live verification for browser startup, quit-all semantics, single-delete guard, and QR confirm regression

No uncovered spec requirement remains.

### Placeholder Scan

This plan contains:

- exact file paths
- concrete migration SQL
- concrete Go and Dart code snippets
- exact curl, Flutter, SSH, Docker, and Go test commands
- explicit runtime exit gates

This plan does not rely on `TODO`, `TBD`, or "implement later" placeholders.

### Type Consistency

The plan uses one consistent backend truth model:

- `device.device_flag` persists `0 = APP`, `1 = Web`, `2 = PC`
- `X-Device-ID` identifies the current device row
- `pcQuit` remains one endpoint and one Flutter action
- Flutter still depends on `LoginBridgeApi -> AuthRepositoryImpl -> DeviceSessionController -> AuthDeviceSessionsPage`

No type, method, or route naming conflicts were introduced while drafting the tasks.
