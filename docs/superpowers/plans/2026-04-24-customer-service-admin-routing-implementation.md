# Customer Service Admin Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add admin-managed customer-service assignment with one default
customer-service account, deterministic fallback, admin-visible `客服/默认客服`
badges, and public Flutter-visible `客服` tags driven by normalized user
category data.

**Architecture:** The remote Go server remains the source of truth for
customer-service membership and routing order by storing `category` plus
`customer_service_rank` on the `user` table. The deployed manager frontend gets
minimal bundle patches to expose customer-service actions and badges, while the
local Flutter app only normalizes public category handling and fills the one
missing badge surface in user detail.

**Tech Stack:** Go, MySQL, Gin, gocraft/dbr, remote SSH editing, deployed
manager `dist` JavaScript bundles, Flutter/Dart, `go test`, `flutter test`

---

## File Structure And Ownership

- Create: `/opt/wukongim-prod/src/modules/user/customer_service_runtime.go`
  Responsibility: centralize customer-service queue rebalancing and public
  category normalization helpers
- Create: `/opt/wukongim-prod/src/modules/user/customer_service_runtime_test.go`
  Responsibility: lock queue rebalancing and category normalization behavior
- Create: `/opt/wukongim-prod/src/modules/user/api_manager_customer_service_test.go`
  Responsibility: cover admin API mutations and list response flags
- Create: `/opt/wukongim-prod/src/modules/user/api_customer_service_public_test.go`
  Responsibility: cover `/v1/user/customerservices` ordering and public category
  normalization
- Create: `/opt/wukongim-prod/src/modules/user/sql/user-20260424-01.sql`
  Responsibility: add `customer_service_rank` and backfill stable ordering
- Modify: `/opt/wukongim-prod/src/modules/user/const.go`
  Responsibility: declare the public customer-service category constant
- Modify: `/opt/wukongim-prod/src/modules/user/db.go`
  Responsibility: add `customer_service_rank`, queue queries, and tx update
  helpers
- Modify: `/opt/wukongim-prod/src/modules/user/db_manager.go`
  Responsibility: expose customer-service fields in manager list queries
- Modify: `/opt/wukongim-prod/src/modules/user/api.go`
  Responsibility: return ranked available customer-service accounts and
  normalize public login-category output
- Modify: `/opt/wukongim-prod/src/modules/user/api_manager.go`
  Responsibility: add `set_customer_service` routes and manager response flags
- Modify: `/opt/wukongim-prod/src/modules/user/service.go`
  Responsibility: normalize public category values in user detail responses

- Create: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/customer-service.shared.js`
  Responsibility: keep manager-side customer-service row helpers readable even
  though the main bundles are built artifacts
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js`
  Responsibility: add the customer-service mutation API wrapper with `/api/admin`
  fallback
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js`
  Responsibility: render manager customer-service badges and dropdown actions
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/customer-service.shared.js.gz`
  Responsibility: compressed asset parity for the new helper bundle
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js.gz`
  Responsibility: compressed asset parity after API bundle changes
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js.gz`
  Responsibility: compressed asset parity after user-list bundle changes

- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_identity.dart`
  Responsibility: normalize public customer-service category values in Flutter
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_badge.dart`
  Responsibility: render the public `客服` badge in surfaces that need a widget
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\friend.dart`
  Responsibility: normalize friend category values and expose
  `isCustomerService`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\user.dart`
  Responsibility: carry normalized public `category` for user detail surfaces
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_item_loader.dart`
  Responsibility: include preferred category in cache keys and request payloads
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_page.dart`
  Responsibility: propagate friend category into personal conversation
  preferred info and fallback data
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\widgets\wk_conversation_item.dart`
  Responsibility: use normalized customer-service category matching
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\widgets\contacts_list_viewport.dart`
  Responsibility: use normalized customer-service category matching and correct
  public label text
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\user\user_detail_page.dart`
  Responsibility: show the public `客服` badge beside existing identity badges

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\friend_model_test.dart`
  Responsibility: verify friend category normalization
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\user_info_model_test.dart`
  Responsibility: verify user info category normalization
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\conversation\conversation_list_preferred_info_test.dart`
  Responsibility: verify category propagation into preferred conversation info
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\widgets\wk_conversation_item_parity_test.dart`
  Responsibility: verify the conversation item shows the `客服` tag
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_viewport_test.dart`
  Responsibility: verify the contact list shows the `客服` tag
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\user\user_detail_page_parity_test.dart`
  Responsibility: verify the user detail header shows the `客服` badge

## Task 1: Add Server Customer-Service Primitives And Migration

**Files:**
- Create: `/opt/wukongim-prod/src/modules/user/customer_service_runtime.go`
- Create: `/opt/wukongim-prod/src/modules/user/customer_service_runtime_test.go`
- Create: `/opt/wukongim-prod/src/modules/user/sql/user-20260424-01.sql`
- Modify: `/opt/wukongim-prod/src/modules/user/const.go`
- Modify: `/opt/wukongim-prod/src/modules/user/db.go`
- Modify: `/opt/wukongim-prod/src/modules/user/db_manager.go`

- [ ] **Step 1: Back up the remote server files before editing**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/modules/user && ts=\$(date +%Y%m%d%H%M%S) && cp const.go const.go.bak.\$ts && cp db.go db.go.bak.\$ts && cp db_manager.go db_manager.go.bak.\$ts && mkdir -p sql/backup.\$ts && cp -R sql/. sql/backup.\$ts/ && printf '%s\n' \$ts"
```

Expected:
- Prints one timestamp such as `20260424093015`
- Leaves backup copies in place before any remote code edit

- [ ] **Step 2: Write the failing runtime tests first**

Create `/opt/wukongim-prod/src/modules/user/customer_service_runtime_test.go`
with:

```go
package user

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNormalizePublicCategory_CustomerService(t *testing.T) {
	assert.Equal(t, publicCategoryCustomerService, normalizePublicCategory("customerService"))
	assert.Equal(t, publicCategoryCustomerService, normalizePublicCategory("customerservice"))
	assert.Equal(t, publicCategoryCustomerService, normalizePublicCategory("customer_service"))
	assert.Equal(t, publicCategoryCustomerService, normalizePublicCategory("service"))
}

func TestNormalizePublicCategory_PreservesSystem(t *testing.T) {
	assert.Equal(t, "system", normalizePublicCategory("system"))
	assert.Equal(t, "", normalizePublicCategory(""))
}

func TestRebalanceCustomerServiceQueue_PromotesDefault(t *testing.T) {
	queue := rebalanceCustomerServiceQueue([]string{"cs-1", "cs-2"}, "cs-3", true, true)
	assert.Equal(t, []string{"cs-3", "cs-1", "cs-2"}, queue)
}

func TestRebalanceCustomerServiceQueue_RemovesTarget(t *testing.T) {
	queue := rebalanceCustomerServiceQueue([]string{"cs-1", "cs-2", "cs-3"}, "cs-2", false, false)
	assert.Equal(t, []string{"cs-1", "cs-3"}, queue)
}
```

- [ ] **Step 3: Run the targeted Go tests and verify they fail**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestNormalizePublicCategory|TestRebalanceCustomerServiceQueue' -count=1"
```

Expected:
- Fails with undefined identifiers such as `publicCategoryCustomerService`,
  `normalizePublicCategory`, and `rebalanceCustomerServiceQueue`

- [ ] **Step 4: Implement the runtime helper, migration, and DB fields**

Create `/opt/wukongim-prod/src/modules/user/customer_service_runtime.go` with:

```go
package user

import "strings"

const publicCategoryCustomerService = "customer_service"

func isCustomerServiceCategory(value string) bool {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case strings.ToLower(string(CategoryCustomerService)), publicCategoryCustomerService, "customerservice", "service":
		return true
	default:
		return false
	}
}

func normalizePublicCategory(value string) string {
	normalized := strings.TrimSpace(strings.ToLower(value))
	if normalized == "" {
		return ""
	}
	if isCustomerServiceCategory(normalized) {
		return publicCategoryCustomerService
	}
	return normalized
}

func rebalanceCustomerServiceQueue(current []string, targetUID string, enabled bool, isDefault bool) []string {
	targetUID = strings.TrimSpace(targetUID)
	queue := make([]string, 0, len(current)+1)
	for _, uid := range current {
		uid = strings.TrimSpace(uid)
		if uid == "" || uid == targetUID {
			continue
		}
		queue = append(queue, uid)
	}
	if !enabled || targetUID == "" {
		return queue
	}
	if isDefault {
		return append([]string{targetUID}, queue...)
	}
	return append(queue, targetUID)
}
```

Add to `/opt/wukongim-prod/src/modules/user/const.go`:

```go
const (
	CategoryCustomerService = "customerService"
	CategorySystem          = "system"
)
```

Update `/opt/wukongim-prod/src/modules/user/db.go` model and helpers:

```go
type Model struct {
	// ...
	Category            string
	CustomerServiceRank int
	// ...
}

func (d *DB) QueryCustomerServiceQueue() ([]*Model, error) {
	var models []*Model
	_, err := d.session.Select("*").
		From("user").
		Where("category=? and customer_service_rank>0", string(CategoryCustomerService)).
		OrderAsc("customer_service_rank", "created_at", "id").
		Load(&models)
	return models, err
}

func (d *DB) QueryAvailableCustomerServices() ([]*Model, error) {
	var models []*Model
	_, err := d.session.Select("*").
		From("user").
		Where("category=? and customer_service_rank>0 and status=1 and is_destroy=0", string(CategoryCustomerService)).
		OrderAsc("customer_service_rank", "created_at", "id").
		Load(&models)
	return models, err
}

func (d *DB) UpdateCustomerServiceFieldsTx(uid, category string, rank int, tx *dbr.Tx) error {
	_, err := tx.Update("user").
		Set("category", category).
		Set("customer_service_rank", rank).
		Where("uid=?", uid).
		Exec()
	return err
}
```

Update `/opt/wukongim-prod/src/modules/user/db_manager.go` list query and model:

```go
selectStm := m.session.Select("user.uid,user.name,user.username,user.status,user.phone,user.short_no,user.sex,user.is_destroy,user.created_at,user.gitee_uid,user.github_uid,user.wx_openid,user.vip_level,user.vip_expire_time,user.category,user.customer_service_rank,max(user_online.online) online").From("user").LeftJoin("user_online", "user.uid=user_online.uid")
```

```go
type managerUserModel struct {
	Username            string
	Name                string
	UID                 string
	Status              int
	Phone               string
	ShortNo             string
	Category            string
	CustomerServiceRank int
	WXOpenid            string
	GiteeUID            string
	GithubUID           string
	Sex                 int
	IsDestroy           int
	VIPLevel            int
	VIPExpireTime       *time.Time
	db.BaseModel
}
```

Create `/opt/wukongim-prod/src/modules/user/sql/user-20260424-01.sql` with:

```sql
-- +migrate Up
ALTER TABLE `user`
  ADD COLUMN `customer_service_rank` INT NOT NULL DEFAULT 0 COMMENT 'customer service rank, 1 is default';

UPDATE `user`
SET `customer_service_rank` = 0
WHERE `category` <> 'customerService';

SET @wk_cs_rank := 0;

UPDATE `user` u
JOIN (
  SELECT ranked.id, (@wk_cs_rank := @wk_cs_rank + 1) AS next_rank
  FROM (
    SELECT id
    FROM `user`
    WHERE `category` = 'customerService'
    ORDER BY `created_at` ASC, `id` ASC
  ) ranked
) seq ON seq.id = u.id
SET u.customer_service_rank = seq.next_rank;

-- +migrate Down
ALTER TABLE `user`
  DROP COLUMN `customer_service_rank`;
```

- [ ] **Step 5: Run the targeted Go tests and verify they pass**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestNormalizePublicCategory|TestRebalanceCustomerServiceQueue' -count=1"
```

Expected:
- PASS for the new runtime tests

- [ ] **Step 6: Commit only the server runtime and migration changes**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git add modules/user/customer_service_runtime.go modules/user/customer_service_runtime_test.go modules/user/const.go modules/user/db.go modules/user/db_manager.go modules/user/sql/user-20260424-01.sql && git commit -m 'feat: add customer service runtime primitives'"
```

Expected:
- Creates one remote commit containing only customer-service runtime and schema
  primitives

## Task 2: Add The Admin Customer-Service API And Manager List Flags

**Files:**
- Create: `/opt/wukongim-prod/src/modules/user/api_manager_customer_service_test.go`
- Modify: `/opt/wukongim-prod/src/modules/user/api_manager.go`
- Modify: `/opt/wukongim-prod/src/modules/user/db.go`

- [ ] **Step 1: Back up the remote manager API file before editing**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/modules/user && ts=\$(date +%Y%m%d%H%M%S) && cp api_manager.go api_manager.go.bak.\$ts && printf '%s\n' \$ts"
```

Expected:
- Prints a backup timestamp and leaves `api_manager.go.bak.<timestamp>`

- [ ] **Step 2: Write the failing manager API tests first**

Create `/opt/wukongim-prod/src/modules/user/api_manager_customer_service_test.go`
with:

```go
package user

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

func TestManagerSetCustomerServicePromotesDefaultAndUpdatesListFlags(t *testing.T) {
	s, ctx := newEventEnabledTestServer(t)
	m := NewManager(ctx)
	err := testutil.CleanAllTables(ctx)
	assert.NoError(t, err)

	for _, user := range []*Model{
		{UID: "cs-1", Username: "cs_1", Name: "CS 1", ShortNo: "cs_1", Status: 1},
		{UID: "cs-2", Username: "cs_2", Name: "CS 2", ShortNo: "cs_2", Status: 1},
		{UID: "user-3", Username: "user_3", Name: "User 3", ShortNo: "user_3", Status: 1},
	} {
		assert.NoError(t, m.userDB.Insert(user))
	}

	for _, body := range []map[string]interface{}{
		{"uid": "cs-1", "enabled": true, "is_default": false},
		{"uid": "cs-2", "enabled": true, "is_default": true},
	} {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodPost, "/v1/manager/user/set_customer_service", bytes.NewReader([]byte(util.ToJson(body))))
		req.Header.Set("token", testutil.Token)
		s.GetRoute().ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code, w.Body.String())
	}

	var rows []struct {
		UID                 string `db:"uid"`
		Category            string `db:"category"`
		CustomerServiceRank int    `db:"customer_service_rank"`
	}
	_, err = ctx.DB().Select("uid,category,customer_service_rank").From("user").Where("uid in ?", []string{"cs-1", "cs-2"}).OrderAsc("customer_service_rank").Load(&rows)
	assert.NoError(t, err)
	assert.Equal(t, "cs-2", rows[0].UID)
	assert.Equal(t, "customerService", rows[0].Category)
	assert.Equal(t, 1, rows[0].CustomerServiceRank)
	assert.Equal(t, "cs-1", rows[1].UID)
	assert.Equal(t, 2, rows[1].CustomerServiceRank)

	listRecorder := httptest.NewRecorder()
	listReq, _ := http.NewRequest(http.MethodGet, "/v1/manager/user/list?page_index=1&page_size=10&keyword=cs-", nil)
	listReq.Header.Set("token", testutil.Token)
	s.GetRoute().ServeHTTP(listRecorder, listReq)

	assert.Equal(t, http.StatusOK, listRecorder.Code, listRecorder.Body.String())
	assert.Contains(t, listRecorder.Body.String(), `"is_customer_service":true`)
	assert.Contains(t, listRecorder.Body.String(), `"is_default_customer_service":true`)
	assert.Contains(t, listRecorder.Body.String(), `"customer_service_rank":1`)
}
```

- [ ] **Step 3: Run the targeted manager tests and verify they fail**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestManagerSetCustomerServicePromotesDefaultAndUpdatesListFlags' -count=1"
```

Expected:
- Fails because the route, request type, and response fields do not exist yet

- [ ] **Step 4: Implement the manager route, queue mutation, and list flags**

Add routes to `/opt/wukongim-prod/src/modules/user/api_manager.go`:

```go
auth.POST("/user/set_customer_service", m.setCustomerService)
adminAPI.POST("/set_customer_service", m.setCustomerService)
```

Add request/response fields and handler code:

```go
type setCustomerServiceReq struct {
	UID       string `json:"uid"`
	Enabled   bool   `json:"enabled"`
	IsDefault bool   `json:"is_default"`
}

type managerUserResp struct {
	// existing fields...
	Category                 string `json:"category"`
	CustomerServiceRank      int    `json:"customer_service_rank"`
	IsCustomerService        bool   `json:"is_customer_service"`
	IsDefaultCustomerService bool   `json:"is_default_customer_service"`
}
```

```go
func (m *Manager) setCustomerService(c *wkhttp.Context) {
	if err := c.CheckLoginRole(); err != nil {
		c.ResponseError(err)
		return
	}

	var req setCustomerServiceReq
	if err := c.BindJSON(&req); err != nil {
		c.ResponseError(common.ErrData)
		return
	}
	req.UID = strings.TrimSpace(req.UID)
	if req.UID == "" {
		c.ResponseError(errors.New("uid不能为空"))
		return
	}

	targetUser, err := m.userDB.QueryByUID(req.UID)
	if err != nil || targetUser == nil {
		c.ResponseError(errors.New("用户不存在"))
		return
	}

	queueModels, err := m.userDB.QueryCustomerServiceQueue()
	if err != nil {
		c.ResponseError(errors.New("查询客服队列失败"))
		return
	}

	currentQueue := make([]string, 0, len(queueModels))
	for _, model := range queueModels {
		currentQueue = append(currentQueue, model.UID)
	}
	nextQueue := rebalanceCustomerServiceQueue(currentQueue, req.UID, req.Enabled, req.IsDefault)

	tx, err := m.ctx.DB().Begin()
	if err != nil {
		c.ResponseError(errors.New("开启事务失败"))
		return
	}
	defer tx.RollbackUnlessCommitted()

	for _, model := range queueModels {
		if err := m.userDB.UpdateCustomerServiceFieldsTx(model.UID, "", 0, tx); err != nil {
			c.ResponseError(errors.New("清理客服顺位失败"))
			return
		}
	}
	for index, uid := range nextQueue {
		if err := m.userDB.UpdateCustomerServiceFieldsTx(uid, string(CategoryCustomerService), index+1, tx); err != nil {
			c.ResponseError(errors.New("更新客服顺位失败"))
			return
		}
	}
	if err := tx.Commit(); err != nil {
		c.ResponseError(errors.New("提交客服顺位失败"))
		return
	}
	c.ResponseOK()
}
```

When building `/v1/manager/user/list`, populate the new flags with:

```go
isCustomerService := isCustomerServiceCategory(user.Category) && user.CustomerServiceRank > 0
isDefaultCustomerService := isCustomerService && user.CustomerServiceRank == 1
```

- [ ] **Step 5: Run the manager tests and verify they pass**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestManagerSetCustomerServicePromotesDefaultAndUpdatesListFlags|TestManagerSetVIPUpdatesUserVIPFields' -count=1"
```

Expected:
- PASS for the new customer-service manager test
- PASS for the existing VIP manager test to confirm no regression

- [ ] **Step 6: Commit only the manager API changes**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git add modules/user/api_manager.go modules/user/api_manager_customer_service_test.go modules/user/db.go && git commit -m 'feat: add manager customer service routing api'"
```

Expected:
- Creates one remote commit for the manager API slice only

## Task 3: Normalize Public Customer-Service Output And Ranked `/customerservices`

**Files:**
- Create: `/opt/wukongim-prod/src/modules/user/api_customer_service_public_test.go`
- Modify: `/opt/wukongim-prod/src/modules/user/api.go`
- Modify: `/opt/wukongim-prod/src/modules/user/service.go`

- [ ] **Step 1: Back up the remote public API files before editing**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/modules/user && ts=\$(date +%Y%m%d%H%M%S) && cp api.go api.go.bak.\$ts && cp service.go service.go.bak.\$ts && printf '%s\n' \$ts"
```

Expected:
- Prints one backup timestamp and leaves both backup files in place

- [ ] **Step 2: Write the failing public API tests first**

Create `/opt/wukongim-prod/src/modules/user/api_customer_service_public_test.go`
with:

```go
package user

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil"
	"github.com/stretchr/testify/assert"
)

func TestCustomerservices_ReturnsOnlyAvailableAccountsInRankOrder(t *testing.T) {
	s, ctx := testutil.NewTestServer()
	u := New(ctx)
	err := testutil.CleanAllTables(ctx)
	assert.NoError(t, err)

	for _, user := range []*Model{
		{UID: "cs-default", Name: "Default", ShortNo: "cs_default", Category: string(CategoryCustomerService), CustomerServiceRank: 1, Status: 1},
		{UID: "cs-fallback", Name: "Fallback", ShortNo: "cs_fallback", Category: string(CategoryCustomerService), CustomerServiceRank: 2, Status: 1},
		{UID: "cs-disabled", Name: "Disabled", ShortNo: "cs_disabled", Category: string(CategoryCustomerService), CustomerServiceRank: 3, Status: 0},
	} {
		assert.NoError(t, u.db.Insert(user))
	}

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/v1/user/customerservices", nil)
	s.GetRoute().ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code, w.Body.String())
	assert.JSONEq(t, `[{"uid":"cs-default","name":"Default"},{"uid":"cs-fallback","name":"Fallback"}]`, w.Body.String())
}

func TestNewUserDetailResp_NormalizesCustomerServiceCategory(t *testing.T) {
	resp := NewUserDetailResp(&Detail{
		Model: Model{
			UID:      "cs-1",
			Name:     "客服一号",
			Category: string(CategoryCustomerService),
			Status:   1,
		},
	}, "", "other-user", "", 0, 0, 0, 0, 1, 0, 0, nil, "")

	assert.Equal(t, publicCategoryCustomerService, resp.Category)
}
```

- [ ] **Step 3: Run the targeted public API tests and verify they fail**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestCustomerservices_ReturnsOnlyAvailableAccountsInRankOrder|TestNewUserDetailResp_NormalizesCustomerServiceCategory' -count=1"
```

Expected:
- Fails because `/v1/user/customerservices` still queries raw category rows and
  the public constructors still return `customerService`

- [ ] **Step 4: Implement ranked public output and category normalization**

Update `/opt/wukongim-prod/src/modules/user/api.go` `customerservices()` to:

```go
func (u *User) customerservices(c *wkhttp.Context) {
	list, err := u.db.QueryAvailableCustomerServices()
	if err != nil {
		u.Error("查询客服列表失败", zap.Error(err))
		c.ResponseError(errors.New("查询客服列表失败"))
		return
	}
	results := make([]*customerservicesResp, 0, len(list))
	for _, user := range list {
		results = append(results, &customerservicesResp{
			UID:  user.UID,
			Name: user.Name,
		})
	}
	c.Response(results)
}
```

Update `/opt/wukongim-prod/src/modules/user/api.go` login response constructor:

```go
Category: normalizePublicCategory(m.Category),
```

Update `/opt/wukongim-prod/src/modules/user/service.go` detail constructor:

```go
Category: normalizePublicCategory(m.Category),
```

- [ ] **Step 5: Run the public API tests and verify they pass**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestCustomerservices_ReturnsOnlyAvailableAccountsInRankOrder|TestNewUserDetailResp_NormalizesCustomerServiceCategory|TestUser_Register' -count=1"
```

Expected:
- PASS for the two new tests
- PASS for `TestUser_Register` to confirm the login/register payload still works

- [ ] **Step 6: Commit only the public customer-service output changes**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git add modules/user/api.go modules/user/service.go modules/user/api_customer_service_public_test.go && git commit -m 'feat: normalize public customer service routing output'"
```

Expected:
- Creates one remote commit for public routing and category normalization

## Task 4: Patch The Deployed Manager Frontend Bundles

**Files:**
- Create: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/customer-service.shared.js`
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js`
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js`
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/customer-service.shared.js.gz`
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js.gz`
- Modify: `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js.gz`

- [ ] **Step 1: Back up the manager bundles before editing**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production/manager/dist/static/js && ts=\$(date +%Y%m%d%H%M%S) && cp user-d08990fe.js user-d08990fe.js.bak.\$ts && cp userlist-83e98bc5.js userlist-83e98bc5.js.bak.\$ts && cp user-d08990fe.js.gz user-d08990fe.js.gz.bak.\$ts && cp userlist-83e98bc5.js.gz userlist-83e98bc5.js.gz.bak.\$ts && printf '%s\n' \$ts"
```

Expected:
- Prints a timestamp and leaves both `.js` and `.js.gz` backup copies

- [ ] **Step 2: Verify the current bundles do not already contain customer-service support**

Run:

```bash
ssh ubuntu@42.194.218.158 "grep -n 'set_customer_service\\|默认客服\\|客服' /opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js /opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js"
```

Expected:
- No matches for `set_customer_service`
- No customer-service management entries in the current bundle

- [ ] **Step 3: Add a readable shared helper and the API wrapper**

Create `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/customer-service.shared.js`:

```js
export function normalizeCustomerServiceUser(row = {}) {
  const rank = Number(row.customer_service_rank) || 0;
  const isCustomerService = row.is_customer_service === true || rank > 0;
  const isDefaultCustomerService =
    row.is_default_customer_service === true || (isCustomerService && rank === 1);
  return {
    ...row,
    customer_service_rank: rank,
    is_customer_service: isCustomerService,
    is_default_customer_service: isDefaultCustomerService,
    customerServiceBadgeText: isDefaultCustomerService ? "默认客服" : isCustomerService ? "客服" : "",
  };
}
```

Update `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user-d08990fe.js`
to add:

```js
async function C(e){var n;const r={url:"/manager/user/set_customer_service",method:"post",data:e};try{return await t(r)}catch(s){const u=((n=s==null?void 0:s.response)==null?void 0:n.status)??(s==null?void 0:s.status)??null,a=`${(s==null?void 0:s.message)??""}`.trim();if(u!==404&&a!=="Network Error")throw s;return t({url:"/api/admin/set_customer_service",method:"post",data:e})}}
```

and extend the export list to include:

```js
export{h as a,p as b,f as c,g as d,m as e,c as f,l as g,d as h,G as i,v as j,b as k,o as l,C as m,k as u};
```

- [ ] **Step 4: Patch the user-list bundle to render badges and menu actions**

Modify `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js`
so it:

```js
import{u as Se,m as je,d as ze,e as $e}from "./user-d08990fe.js";
import{normalizeCustomerServiceUser as Xe}from "./customer-service.shared.js";
```

normalizes rows after fetch:

```js
m=()=>{c.value=!0,$e(s).then(e=>{c.value=!1,U.value=e.list.map(Xe),_.value=e.count})}
```

extends the name-cell render:

```js
render:e=>l("div",{class:"user-name-cell"},[
  l("span",null,[e.row.name]),
  Number(e.row.vip_level)===1?l("span",{class:"user-vip-badge"},[i("VIP/商家")]):null,
  e.row.is_default_customer_service?l("span",{class:"user-vip-badge"},[i("默认客服")]):
  e.row.is_customer_service?l("span",{class:"user-vip-badge"},[i("客服")]):null
])
```

and adds dropdown actions:

```js
const M=async(e,r)=>{await je({uid:e.uid,enabled:r,is_default:!1});m();I.success(r?"已设置为客服":"已取消客服")};
const N=async e=>{await je({uid:e.uid,enabled:!0,is_default:!0});m();I.success("默认客服已更新")};
```

with menu entries:

```js
!e.row.is_customer_service&&l(T,{onClick:()=>M(e.row,!0)},{default:()=>[i("设为客服")]}),
e.row.is_customer_service&&l(T,{onClick:()=>M(e.row,!1)},{default:()=>[i("取消客服")]}),
!e.row.is_default_customer_service&&l(T,{onClick:()=>N(e.row)},{default:()=>[i("设为默认客服")]})
```

- [ ] **Step 5: Rebuild the compressed assets and verify the bundle text**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production/manager/dist/static/js && gzip -kf customer-service.shared.js user-d08990fe.js userlist-83e98bc5.js && grep -n 'set_customer_service\\|默认客服\\|设为客服\\|取消客服' user-d08990fe.js userlist-83e98bc5.js customer-service.shared.js"
```

Expected:
- `.gz` files are regenerated for all modified bundles
- `grep` shows the customer-service API path and UI labels in the patched files

- [ ] **Step 6: Commit only the manager bundle changes**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && git add deploy/production/manager/dist/static/js/customer-service.shared.js deploy/production/manager/dist/static/js/customer-service.shared.js.gz deploy/production/manager/dist/static/js/user-d08990fe.js deploy/production/manager/dist/static/js/user-d08990fe.js.gz deploy/production/manager/dist/static/js/userlist-83e98bc5.js deploy/production/manager/dist/static/js/userlist-83e98bc5.js.gz && git commit -m 'feat: add manager customer service controls'"
```

Expected:
- Creates one remote commit containing only the manager frontend bundle patch

## Task 5: Normalize Flutter Public Customer-Service Tags

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_identity.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_badge.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\friend.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\user.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_item_loader.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\widgets\wk_conversation_item.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\widgets\contacts_list_viewport.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\user\user_detail_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\friend_model_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\user_info_model_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\conversation\conversation_list_preferred_info_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\widgets\wk_conversation_item_parity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_viewport_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\user\user_detail_page_parity_test.dart`

- [ ] **Step 1: Write the failing Flutter tests first**

Update `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\friend_model_test.dart`
with:

```dart
test('Friend normalizes customerService category to customer_service', () {
  final friend = Friend.fromJson(const {
    'uid': 'cs-1',
    'name': '客服一号',
    'category': 'customerService',
  });

  expect(friend.category, 'customer_service');
  expect(friend.isCustomerService, isTrue);
});
```

Create `C:\Users\COLORFUL\Desktop\WuKong\test\data\models\user_info_model_test.dart`
with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong/data/models/user.dart';

void main() {
  test('UserInfo normalizes customerService category to customer_service', () {
    final user = UserInfo.fromJson(const {
      'uid': 'cs-1',
      'name': '客服一号',
      'category': 'customerService',
    });

    expect(user.category, 'customer_service');
    expect(user.isCustomerService, isTrue);
  });
}
```

Update `C:\Users\COLORFUL\Desktop\WuKong\test\modules\conversation\conversation_list_preferred_info_test.dart`
with:

```dart
test('buildPreferredPersonalConversationInfoMap keeps category', () {
  final infos = buildPreferredPersonalConversationInfoMap([
    Friend(uid: 'cs-1', name: '客服一号', category: 'customer_service'),
  ]);

  expect(infos['cs-1']?.category, 'customer_service');
});
```

- [ ] **Step 2: Run the targeted Flutter tests and verify they fail**

Run:

```bash
flutter test test/data/models/friend_model_test.dart test/data/models/user_info_model_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart
```

Expected:
- Fails because `UserInfo` lacks `category` and `isCustomerService`
- Fails because `ConversationPreferredInfo` does not yet carry category

- [ ] **Step 3: Implement category normalization and category propagation**

Create `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_identity.dart`:

```dart
const String publicCustomerServiceCategory = 'customer_service';

bool isCustomerServiceCategory(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'customer_service' ||
      normalized == 'customerservice' ||
      normalized == 'customerservice'.replaceAll('_', '') ||
      normalized == 'service';
}

String normalizeCustomerServiceCategory(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  return isCustomerServiceCategory(normalized)
      ? publicCustomerServiceCategory
      : normalized;
}
```

Create `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\customer_service\customer_service_badge.dart`:

```dart
import 'package:flutter/material.dart';

class CustomerServiceBadge extends StatelessWidget {
  const CustomerServiceBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1856E7),
        borderRadius: BorderRadius.circular(compact ? 999 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Text(
          '客服',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
```

Update `friend.dart` and `user.dart` to normalize categories:

```dart
final String? category;
bool get isCustomerService => isCustomerServiceCategory(category);
```

```dart
category: normalizeCustomerServiceCategory(json['category']?.toString()),
```

Update conversation preferred info in
`conversation_list_page.dart` and `conversation_list_item_loader.dart`:

```dart
class ConversationPreferredInfo {
  final String title;
  final String? avatarUrl;
  final int vipLevel;
  final String? category;

  const ConversationPreferredInfo({
    required this.title,
    required this.avatarUrl,
    this.vipLevel = 0,
    this.category,
  });
}
```

```dart
infos[uid] = ConversationPreferredInfo(
  title: _resolveFriendTitle(friend),
  avatarUrl: _resolveConversationAvatar(friend.avatar),
  vipLevel: friend.vipLevel,
  category: friend.category,
);
```

```dart
final String? preferredCategory;
```

```dart
category: _firstNonEmptyText([request.preferredCategory, channel?.category]),
```

Update `wk_conversation_item.dart` and
`contacts_list_viewport.dart` to use `isCustomerServiceCategory(category)`
instead of raw string comparisons.

Update `user_detail_page.dart` header row with:

```dart
final isCustomerServiceUser = _user?.isCustomerService ?? false;
```

```dart
if (isCustomerServiceUser) ...[
  const SizedBox(width: 6),
  const CustomerServiceBadge(),
],
```

- [ ] **Step 4: Add the UI assertions for public `客服`**

Update `C:\Users\COLORFUL\Desktop\WuKong\test\widgets\wk_conversation_item_parity_test.dart`
with:

```dart
testWidgets('conversation item shows 客服 tag', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WKConversationItem(
          data: WKConversationItemData(
            channelId: 'cs-1',
            channelType: 1,
            title: '客服一号',
            lastMsgContent: 'hello',
            unreadCount: 0,
            category: 'customer_service',
          ),
        ),
      ),
    ),
  );

  expect(find.text('客服'), findsOneWidget);
});
```

Update `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_viewport_test.dart`
with:

```dart
testWidgets('contacts viewport shows 客服 tag', (tester) async {
  final directory = buildContactsDirectoryData(
    friends: [Friend(uid: 'cs-1', name: '客服一号', category: 'customer_service')],
    currentUid: 'u-1',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ContactsListViewport(
          header: const SizedBox.shrink(),
          directory: directory,
          contactPresenceByUid: const {},
          currentTimestampSeconds: 0,
          onTapEntry: (_) {},
          onLongPressEntry: (_) {},
        ),
      ),
    ),
  );

  expect(find.text('客服'), findsWidgets);
});
```

Update `C:\Users\COLORFUL\Desktop\WuKong\test\modules\user\user_detail_page_parity_test.dart`
with:

```dart
testWidgets('user detail header shows 客服 badge', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UserDetailPage(
        uid: 'cs-1',
        userOverride: UserInfo(uid: 'cs-1', name: '客服一号', category: 'customer_service'),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('客服'), findsOneWidget);
});
```

- [ ] **Step 5: Run the targeted Flutter tests and verify they pass**

Run:

```bash
flutter test test/data/models/friend_model_test.dart test/data/models/user_info_model_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart test/widgets/wk_conversation_item_parity_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/user/user_detail_page_parity_test.dart
```

Expected:
- PASS for all new and updated Flutter customer-service tests

- [ ] **Step 6: Commit only the Flutter customer-service UI changes**

Run:

```bash
git add -- lib/modules/customer_service/customer_service_identity.dart lib/modules/customer_service/customer_service_badge.dart lib/data/models/friend.dart lib/data/models/user.dart lib/modules/conversation/conversation_list_item_loader.dart lib/modules/conversation/conversation_list_page.dart lib/widgets/wk_conversation_item.dart lib/modules/contacts/widgets/contacts_list_viewport.dart lib/wukong_uikit/user/user_detail_page.dart test/data/models/friend_model_test.dart test/data/models/user_info_model_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart test/widgets/wk_conversation_item_parity_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/user/user_detail_page_parity_test.dart
git commit -m "feat: add public customer service identity badges"
```

Expected:
- Creates one local commit containing only customer-service public UI changes
- Leaves unrelated existing modified files untouched

## Task 6: Verify, Gate Restart, And Roll Out Safely

**Files:**
- No new files
- Use the server and local files already changed in Tasks 1-5

- [ ] **Step 1: Run the complete targeted verification suite**

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user -run 'TestManagerSetCustomerServicePromotesDefaultAndUpdatesListFlags|TestCustomerservices_ReturnsOnlyAvailableAccountsInRankOrder|TestNewUserDetailResp_NormalizesCustomerServiceCategory|TestManagerSetVIPUpdatesUserVIPFields|TestUser_Register' -count=1"
flutter test test/data/models/friend_model_test.dart test/data/models/user_info_model_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart test/widgets/wk_conversation_item_parity_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/user/user_detail_page_parity_test.dart
```

Expected:
- Remote Go customer-service suite passes
- Local Flutter customer-service suite passes

- [ ] **Step 2: Stop before any service restart and ask for explicit approval**

Run:

```text
Print the rollout plan:
1. deploy the updated Go files and manager bundle files to `/opt/wukongim-prod/src`
2. rebuild only the `tsdd-api` container so startup applies the new SQL migration and Go API changes
3. verify `/v1/manager/user/list` and `/v1/user/customerservices` with a fresh admin login token derived from `deploy/production/rendered/tsdd.yaml`
4. verify the patched manager bundle files on disk, then separately confirm whether the live manager SPA host mounts `/opt/wukongim-prod/src/deploy/production/manager/dist` before any static-host reload

Then wait for the user to reply exactly "Approve" before any restart command.
```

Expected:
- No service restart happens before explicit user approval

- [ ] **Step 3: After approval, apply the migration and restart only the affected services**

The production deployment is docker-compose based. `tsdd-api` is built from
`/opt/wukongim-prod/src`, and startup uses the existing sql-migrate loader from
`pkg/db/mysql.go`, so rebuilding and restarting `tsdd-api` is the step that
applies the new SQL migration and Go API changes. The manager bundle patch
lives under `/opt/wukongim-prod/src/deploy/production/manager/dist`, but the
currently running `wukongim_prod-nginx-1` container does not mount that path,
so Task 4 live verification is limited to on-disk bundle inspection unless the
actual manager SPA delivery path is identified separately.

Run:

```bash
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose up -d --build tsdd-api"
ssh ubuntu@42.194.218.158 "docker logs --tail 120 wukongim_prod-tsdd-api-1"
```

Expected:
- `wukongim_prod-tsdd-api-1` rebuilds and restarts successfully
- Startup logs do not show SQL migration or boot failures

- [ ] **Step 4: Verify the live endpoints and UI text after restart**

Run:

```bash
ssh ubuntu@42.194.218.158 "docker exec wukongim_prod-tsdd-api-1 wget -qO- http://127.0.0.1:8090/v1/user/customerservices"
ssh ubuntu@42.194.218.158 "ADMIN_PWD=\$(sed -n 's/^adminpwd: \"\\(.*\\)\"/\\1/p' /opt/wukongim-prod/src/deploy/production/rendered/tsdd.yaml) && TOKEN=\$(wget --header='Content-Type: application/json' --post-data=\"{\\\"username\\\":\\\"superAdmin\\\",\\\"password\\\":\\\"\$ADMIN_PWD\\\"}\" -qO- http://127.0.0.1:8090/v1/manager/login | sed -n 's/.*\"token\":\"\\([^\"]*\\)\".*/\\1/p') && test -n \"\$TOKEN\" && wget --header=\"token: \$TOKEN\" -qO- 'http://127.0.0.1:8090/v1/manager/user/list?page_index=1&page_size=10&keyword=cs-'"
ssh ubuntu@42.194.218.158 "grep -n '默认客服\\|设为客服\\|取消客服' /opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist-83e98bc5.js"
```

Expected:
- `/v1/user/customerservices` returns available customer-service users ordered
  by `customer_service_rank`
- `/v1/manager/user/list` returns `is_customer_service`,
  `is_default_customer_service`, and `customer_service_rank`
- The patched manager bundle on disk contains the new customer-service labels

- [ ] **Step 5: Summarize rollout evidence and remaining risks**

Run:

```text
Capture:
- which remote commits were created
- which local commit was created
- the exact tests that passed
- whether the migration and live endpoint checks passed
- any remaining risk, especially that the manager UI is still a patched dist bundle without source maps and the active nginx compose does not currently mount `deploy/production/manager/dist`
```

Expected:
- A concise evidence-backed rollout note ready to share with the user
