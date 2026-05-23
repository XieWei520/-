# Spec: Admin Control Plane Five-Phase Roadmap

## Objective
把现有 `TangSengDaoDaoManager-main` 后台管理源码补齐成项目的正式运营控制台，覆盖部署链路、基础质量、信息架构、客户端业务配置、内容安全、审计、后端接口和权限闭环。

目标用户是超级管理员、运营人员、客服主管、内容安全审核员和运维人员。成功标准不是“页面能打开”，而是每个高危管理动作都有后端鉴权、操作审计、失败反馈、最小测试和可回滚部署路径。

## Assumptions
1. 管理端继续使用 `TangSengDaoDaoManager-main`，技术栈为 Vue 3、TypeScript、Vite、Pinia、Element Plus。
2. 管理端最终通过 `/admin/` 访问，后端 API 通过 `/api/v1` 或 `/v1` 反向代理到 Go 服务，前端代码不硬编码生产域名。
3. Flutter 客户端已有 `launchPolicy` 概念，后台的启动策略、强更、公告、维护模式要和客户端模型对齐。
4. Go 后端完整源码在 `ssh ubuntu@42.194.218.158` 的云服务器上，正式接口、数据库迁移和权限逻辑必须在后端实现。
5. 前端权限只做体验控制，不能作为安全边界。
6. 用户删除、强制更新、封禁、举报处理、消息审计、VIP/客服设置等操作都属于高危操作，必须写审计日志。

## Tech Stack
Admin frontend:
- Vue 3.3, TypeScript, Vite 4, Pinia, Element Plus, ECharts.
- Source root: `TangSengDaoDaoManager-main/src`.
- API wrapper: `TangSengDaoDaoManager-main/src/utils/axios.ts`.
- Menu modules: `TangSengDaoDaoManager-main/src/menu/modules`.
- Existing pages: user, group, message, report, workplace, tool/appupdate, vip, customer-service, launch-policy.

Client:
- Flutter app under repository root `lib/`.
- Launch policy expected to map to Flutter startup behavior: version policy, forced update, announcement, maintenance mode.

Backend:
- Go TangSengDaoDaoServer local working copy: `.codex-backend-work/src`.
- Production source/deployment target: `ssh ubuntu@42.194.218.158`.
- Storage: MySQL, Redis, MinIO, WuKongIM service integration.

## Commands
Admin frontend:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\TangSengDaoDaoManager-main
pnpm install
pnpm dev
pnpm build
pnpm lint
```

Backend local focused tests:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src
$env:GOPROXY='https://goproxy.cn,direct'
go test ./modules/common ./modules/user ./modules/file -run "TestNormalizeAdminAuditLog|TestBuildUserPurgePlan|TestValidatePurgeUserReq|TestExtractPurgeObjectKeysFromMessagePayloads|TestUserPurgeSQLStepsDeleteReminderChildrenBeforeCreatedReminders|TestSQLTableNameEscapesGroupTable|TestVIPStatusAndEntitlements|TestRebalanceCustomerServiceQueue|TestNormalizePublicCategory|TestMinio|TestMultipartService"
```

Deployment checks, after services exist:

```powershell
ssh ubuntu@42.194.218.158
docker compose ps
docker compose exec -T nginx nginx -t
```

## Project Structure
Admin frontend:
- `src/config/`: APP_URL, HOME_URL, LOGIN_URL, runtime config.
- `src/router/`: base path, login redirect, route guards.
- `src/utils/axios.ts`: unified request, response, auth-expiry, error, loading policy.
- `src/menu/modules/`: menu grouping and permission metadata.
- `src/api/`: typed API wrappers.
- `src/pages/home/`: operations dashboard.
- `src/pages/user/`: user, device, VIP, customer-service, purge entry.
- `src/pages/group/`: group list, members, created-group cleanup impact.
- `src/pages/message/`: message audit, prohibited words, send history.
- `src/pages/launch-policy/`: version policy, forced update, announcements, maintenance mode.
- `src/pages/workplace/`: app, category, banner, module visibility.
- `src/pages/audit/`: operation audit and high-risk action log.
- `src/pages/monitoring/`: service health, robot monitor, call gateway, logs.

Backend:
- `modules/common/`: app version, startup notice, launch policy, shared audit if already located there.
- `modules/user/`: user management, VIP MVP fields, customer-service flags, physical purge.
- `modules/group/`: group cleanup, group audit support.
- `modules/message/`: message audit and content safety search.
- `modules/file/`: MinIO physical delete.
- `modules/audit/`: central admin audit if split into new module.
- `modules/*/sql/`: MySQL migrations.

## Code Style
前端 API wrapper 必须使用明确类型，不再扩散 `any`：

```ts
export interface LaunchPolicySaveRequest {
  platform: 'android' | 'windows' | 'ios' | 'macos' | 'web';
  latest_version: string;
  latest_build: number;
  min_supported_version: string;
  min_supported_build: number;
  force_update: boolean;
  maintenance_enabled: boolean;
  reason: string;
}

export function saveLaunchPolicy(data: LaunchPolicySaveRequest) {
  return request({
    url: '/manager/app/launch-policies',
    method: 'post',
    data
  });
}
```

高危后端接口必须显式验证操作原因：

```go
type RiskActionRequest struct {
    Reason string `json:"reason"`
}

func (r RiskActionRequest) Validate() error {
    if strings.TrimSpace(r.Reason) == "" {
        return errors.New("reason is required")
    }
    return nil
}
```

## Testing Strategy
- 第一阶段必须先让管理端 `pnpm build` 可稳定通过。
- 管理端新增页面至少有构建检查、关键 API wrapper 单测或页面 smoke。若当前未配置 Vitest，第一阶段先补测试基础设施。
- 后端新增行为采用 TDD：先写接口/服务层测试，再实现迁移和 handler。
- 用户删除、权限、审计、强制更新、举报处理必须有后端测试。
- 真实数据库相关能力需要隔离 MySQL 测试环境。本机当前 `127.0.0.1:3306` 不可用，不能用当前机器证明手机号复用。

## Boundaries
- Always:
  - 后端鉴权是唯一安全边界。
  - 所有高危操作写审计日志。
  - 管理端统一 `/admin/` base path 和 API base URL。
  - 每阶段完成后执行构建或对应测试。
  - 前端只调用后端固定 API，不传 SQL、不拼危险表名。
- Ask first:
  - 修改生产 Nginx、Docker Compose、数据库迁移或重启生产服务。
  - 删除或重命名现有公开 API。
  - 引入新的前端 UI 框架或大型依赖。
- Never:
  - 在前端实现真实权限绕过。
  - 在管理端保存 token、密码、MinIO secret、数据库连接串等敏感信息。
  - 绕过审计直接执行用户物理删除。
  - 用生产数据做删除测试。

## Phase 1: Admin Access And Baseline Quality

### Scope
修正 `/admin/` 部署链路，统一 base path 和请求层，建立后台最小质量门禁。

### Deliverables
1. 部署方式二选一并写入文档：
   - 方案 A: 主 Nginx 挂载 `/admin/`，静态文件来自 `TangSengDaoDaoManager-main/dist`。
   - 方案 B: 后台独立 Nginx 服务，例如 `admin-nginx`，域名或端口独立，但 API 代理路径保持一致。
2. Vite 配置支持 `base: '/admin/'`。
3. Vue Router 使用一致的 base path，登录后不会跳到站点根路径 `/`。
4. `APP_URL`、`/api/v1`、`/admin/` 的职责明确：
   - `APP_BASE_PATH`: 前端页面路径，默认 `/admin/`。
   - `APP_URL`: API base，默认 `/api/v1` 或运行时 `window.TSDD_CONFIG.APP_URL`。
   - API wrapper 统一自动补齐 `/manager/...` 或 `/v1/...` 规则，不混用有无前导 slash。
5. `axios` 层整理：
   - token 注入。
   - 401 登录态过期统一清理并跳转 `/admin/login`。
   - 400/403/500 错误统一转为可展示 message。
   - loading 可被页面显式打开/关闭，不做全局无脑遮罩。
   - 空态和异常态由页面统一组件展示。
6. 最小测试：
   - `pnpm build`。
   - `pnpm lint`。
   - API wrapper 单测或 smoke。
   - 登录页、首页、用户列表、启动策略页 smoke。

### Acceptance Criteria
- 访问 `https://<domain>/admin/` 能打开后台。
- 刷新 `https://<domain>/admin/user/userlist` 不 404。
- 未登录访问任意后台页面跳到 `/admin/login`。
- 登录过期后清理本地 token，不循环跳转。
- `pnpm build` 通过。
- `pnpm lint` 无阻断问题，遗留风格问题必须列清单。

### Tasks
- [ ] Task 1.1: Normalize admin base path
  - Acceptance: Vite、Router、Nginx 对 `/admin/` 一致。
  - Verify: `pnpm build` and manual refresh `/admin/home`.
  - Files: `vite.config.ts`, `src/router/index.ts`, `src/config/index.ts`, `default.conf`, deployment docs.
- [ ] Task 1.2: Normalize API base URL
  - Acceptance: API calls use one base rule and no route mixes `manager/...` with `/manager/...`.
  - Verify: API wrapper tests or static wrapper scan.
  - Files: `src/utils/axios.ts`, `src/api/**/*.ts`, runtime config.
- [ ] Task 1.3: Harden request state and errors
  - Acceptance: 401, 403, 400, network error, empty data all have deterministic behavior.
  - Verify: API wrapper tests.
  - Files: `src/utils/axios.ts`, stores, shared empty/error components.
- [ ] Task 1.4: Add minimum quality gate
  - Acceptance: build, lint, and smoke command documented and runnable.
  - Verify: `pnpm build`, `pnpm lint`, smoke test command.
  - Files: `package.json`, test config, docs.

## Phase 2: Management Information Architecture

### Scope
把菜单从“源码模块堆叠”升级为运营后台的信息架构，并把首页做成真正的运维 Dashboard。

### Menu Groups
1. 运营:
   - Dashboard
   - 启动策略
   - 弹窗公告
   - 工作台管理
   - VIP 管理
   - 客服人员
2. 用户:
   - 用户列表
   - 新增用户
   - 好友关系
   - 黑名单
   - 封禁用户
   - 删除用户/注销审计
   - 设备管理
3. 群组:
   - 群列表
   - 群成员
   - 群黑名单
   - 群封禁
   - 群公告/群提醒
4. 内容安全:
   - 违禁词策略
   - 举报中心
   - 消息审计
   - 群发记录
5. 系统配置:
   - 基础配置
   - APP 版本
   - 管理员
   - 权限角色
   - 审计日志
6. 监控运维:
   - 服务健康
   - 在线连接
   - 机器人/监控中心
   - 音视频质量
   - 错误趋势

### Dashboard Metrics
- 在线用户数。
- 今日活跃用户。
- 今日消息量。
- 连接成功率。
- API 错误趋势。
- WuKongIM、Go 后端、Redis、MySQL、MinIO、LiveKit/CallGateway 健康。
- 最近高危操作。
- 待处理举报。
- 当前强更/维护/公告状态。

### Table Standard
所有核心表格统一具备：
- 筛选区。
- 分页。
- 列配置。
- 导出。
- 批量操作。
- 危险操作二次确认。
- 空态。
- 加载态。
- 错误态。

### Acceptance Criteria
- 菜单分组不再只按历史模块命名。
- 首页展示至少 6 个真实或后端占位指标，后端缺失时明确显示“接口未接入”。
- 用户、群组、消息、举报、审计至少共享同一套表格交互规范。

### Tasks
- [ ] Task 2.1: Rewrite menu grouping
  - Acceptance: menu follows six groups and keeps existing routes reachable.
  - Verify: `pnpm build`, manual menu navigation.
  - Files: `src/menu/modules/*`, route meta.
- [ ] Task 2.2: Build operations dashboard shell
  - Acceptance: dashboard uses real API where available and typed placeholders where missing.
  - Verify: `pnpm build`, dashboard smoke.
  - Files: `src/pages/home/index.vue`, `src/api/statistic.ts`, dashboard components.
- [ ] Task 2.3: Create reusable table conventions
  - Acceptance: one shared pattern covers filter, pagination, empty/error/loading, confirm, export.
  - Verify: apply to one user table and one content table.
  - Files: shared table components, one or two migrated pages.

## Phase 3: Client Business Admin Coverage

### Scope
补齐和 Flutter 客户端直接相关的后台能力：启动策略、工作台、机器人/监控、音视频、设备。

### Startup Policy Management
Admin fields:
- platform。
- latest_version。
- latest_build。
- min_supported_version。
- min_supported_build。
- force_update。
- download_url。
- changelog。
- announcement_id。
- maintenance_enabled。
- maintenance_message。
- rollout_percent。
- status。

Backend behavior:
- `GET /v1/app/launch-policy` 返回客户端所需完整策略。
- 管理端变更写审计。
- 发布和停用可回滚。

### Workplace Management
Upgrade existing workplace pages:
- 应用管理。
- 分类管理。
- Banner 管理。
- 用户侧启用模块。
- 排序。
- 可见范围: 全部、平台、用户、角色、VIP 等级。

### Robot And Monitor Center
Management targets:
- 飞书。
- 钉钉。
- 小鹅。
- 巨量。
- 其他 webhook 机器人。

Required views:
- 配置列表。
- 运行状态。
- 最近转发日志。
- 错误原因。
- 手动测试发送。
- 启用/禁用。

### Audio/Video Management
For LiveKit/CallGateway:
- 服务健康。
- 通话记录。
- 失败原因。
- 质量指标: join success, reconnect, packet loss, RTT, duration。
- 用户/群/时间筛选。

### Device Management
- 登录设备。
- 设备锁。
- 踢下线。
- 异常登录记录。
- 最近登录 IP/平台/版本。

### Acceptance Criteria
- Flutter 相关运行策略都能从后台配置或至少在后台只读可见。
- 启动策略变更能在客户端启动流程里被验证。
- 设备踢下线和设备锁必须后端执行并审计。

### Tasks
- [ ] Task 3.1: Complete launch policy admin
  - Acceptance: forced update, optional update, announcement, maintenance can be configured.
  - Verify: admin build, backend launch-policy tests, Flutter focused launch-policy tests.
  - Files: `src/api/launchPolicy.ts`, `src/pages/launch-policy/*`, backend common/app modules, Flutter launch policy model if needed.
- [ ] Task 3.2: Upgrade workplace pages
  - Acceptance: app/category/banner/module visibility/sort are manageable.
  - Verify: admin build and API smoke.
  - Files: `src/pages/workplace/*`, `src/api/workplace/*`, backend workplace endpoints if missing.
- [ ] Task 3.3: Add robot monitor center
  - Acceptance: monitor configs and forwarding logs are visible, test send works where backend supports it.
  - Verify: admin build, backend API tests.
  - Files: new `src/pages/monitoring/robots/*`, `src/api/monitoring.ts`, backend monitor modules.
- [ ] Task 3.4: Add audio/video operations page
  - Acceptance: health, call records, failure reasons, and quality metrics are visible.
  - Verify: admin build, backend health endpoint tests.
  - Files: monitoring pages/API, backend call gateway/livekit endpoints.
- [ ] Task 3.5: Add device management
  - Acceptance: list devices, lock device, kick offline, inspect abnormal login.
  - Verify: admin build, backend user/device tests.
  - Files: `src/pages/user/devices.vue`, `src/api/device.ts`, backend device endpoints.

## Phase 4: Content Safety And Audit

### Scope
把现有违禁词、举报、消息记录升级为可运营、可追责的内容安全系统。

### Prohibited Words As Policy
From simple list to policy:
- 分组。
- 版本。
- 草稿。
- 发布。
- 回滚。
- 命中日志。
- 生效范围: 私聊、群聊、昵称、群名、朋友圈/动态等。

### Report Center
Report states:
- 待处理。
- 已处理。
- 驳回。
- 封禁。
- 备注。
- 处理人。
- 处理时间。

Required operations:
- 查看举报对象。
- 查看上下文。
- 封禁用户。
- 封禁群。
- 标记处理。
- 驳回。
- 写备注。

### Message Audit
Filters:
- 用户。
- 群。
- 时间。
- 消息类型。
- 设备。
- 敏感词命中。
- 是否已撤回/删除。

High-risk operations:
- 删除消息。
- 撤回消息。
- 封禁用户。
- 封禁群。
- 导出审计结果。

### Operation Audit
Every high-risk action records:
- operator_uid。
- operator_name。
- action。
- target_type。
- target_id。
- before_json。
- after_json。
- reason。
- ip。
- user_agent。
- created_at。

### Acceptance Criteria
- 违禁词可以按版本发布和回滚。
- 举报处理状态完整可追踪。
- 消息审计可按关键维度筛选。
- 高危操作不允许无 reason 执行。
- 审计日志不记录密码、token、secret。

### Tasks
- [ ] Task 4.1: Prohibited word policy backend and UI
  - Acceptance: draft, publish, rollback, hit log exist.
  - Verify: backend policy tests, admin build.
  - Files: message/common backend modules, `src/pages/message/prohibitwords.vue`.
- [ ] Task 4.2: Report workflow
  - Acceptance: report status, handler, reason, notes, ban actions are traceable.
  - Verify: backend report tests, admin build.
  - Files: report backend modules, `src/pages/report/*`.
- [ ] Task 4.3: Message audit filters
  - Acceptance: filters work by user, group, time, type, device.
  - Verify: backend query tests, admin build.
  - Files: message backend modules, `src/pages/message/record*.vue`.
- [ ] Task 4.4: Central admin audit
  - Acceptance: all high-risk actions write audit rows and audit page can search them.
  - Verify: backend audit tests, admin build.
  - Files: backend audit module, `src/api/audit.ts`, `src/pages/audit/*`.

## Phase 5: Backend Interfaces And Permission Closure

### Scope
完成后端接口、数据库迁移、权限控制、审计、前后端契约测试，确保管理端不是“假按钮”。

### Backend API Rule
If full backend source is available:
- Add Go endpoints.
- Add MySQL migrations.
- Add unit/integration tests.
- Add audit log calls.
- Add permission checks.

If only existing backend is available:
- Run interface discovery first.
- Mark missing endpoints explicitly.
- Implement frontend adapter only for confirmed existing endpoints.
- Never assume an endpoint exists.

### Permission Closure
Required backend checks:
- Super admin only:
  - user physical purge。
  - admin account management。
  - role/permission changes。
  - deployment/system settings。
- Operator/admin:
  - VIP grant/revoke only if permission allows。
  - announcement publish。
  - forced update publish。
  - report processing。
- Read-only roles:
  - dashboard and audit read where allowed。

### Required Backend Surfaces
Admin deployment:
- `GET /v1/manager/health`
- `GET /v1/manager/dashboard/summary`

Launch policy:
- `GET /v1/app/launch-policy`
- `GET/POST/PUT /v1/manager/app/launch-policies`
- `POST /v1/manager/app/launch-policies/:id/publish`
- `POST /v1/manager/app/launch-policies/:id/disable`

Announcements:
- `GET/POST/PUT /v1/manager/common/startup-notices`
- `POST /v1/manager/common/startup-notices/:id/publish`
- `POST /v1/manager/common/startup-notices/:id/disable`

VIP:
- Reuse first: `POST /v1/manager/user/set_vip`
- Later: `/v1/manager/vip/plans`, `/v1/manager/vip/users/:uid`

Customer service:
- Reuse first: `POST /v1/manager/user/set_customer_service`
- Later: `GET/POST/PUT/DELETE /v1/manager/customer-service/staff`

User purge:
- `GET /v1/manager/users/:uid/purge-preview`
- `DELETE /v1/manager/users/:uid/purge`
- `GET /v1/manager/users/purge-jobs/:job_id`

Audit:
- `GET /v1/manager/audit/logs`

Monitoring:
- `GET /v1/manager/monitoring/services`
- `GET /v1/manager/monitoring/errors`
- `GET /v1/manager/calls/records`
- `GET /v1/manager/calls/health`

### Acceptance Criteria
- 所有新增管理操作都有后端鉴权。
- 所有高危新增管理操作都有审计。
- 所有新增接口有 Go 测试或明确的接口探测记录。
- 管理端页面只展示当前角色可操作的按钮，但按钮隐藏不替代后端权限。
- API 错误能在页面明确提示，不吞错。

### Tasks
- [ ] Task 5.1: Backend interface probe and matrix update
  - Acceptance: every page action is mapped to existing, new, or deferred backend endpoint.
  - Verify: update `docs/specs/admin-backend-interface-matrix.md`.
  - Files: docs and backend route inventory.
- [ ] Task 5.2: Permission middleware policy
  - Acceptance: each admin endpoint has declared required role/permission.
  - Verify: backend auth tests.
  - Files: backend middleware and route registration.
- [ ] Task 5.3: Audit middleware/service
  - Acceptance: high-risk handlers call one reusable audit path.
  - Verify: audit tests.
  - Files: backend audit module/common module.
- [ ] Task 5.4: Frontend permission adapter
  - Acceptance: menu/button permission uses backend role metadata where available, with safe fallback.
  - Verify: admin build and permission smoke.
  - Files: `src/stores/modules/auth.ts`, menu meta, directives.
- [ ] Task 5.5: Deployment release gate
  - Acceptance: admin build, backend tests, nginx validation, smoke URLs pass before production rollout.
  - Verify: documented command log.
  - Files: deployment docs/scripts.

## Cross-Phase Dependency Order
1. Phase 1 must be completed first, because base path and request layer affect every page.
2. Phase 2 menu/dashboard can begin after Phase 1 route stability.
3. Phase 3 can split by module after API base is stable.
4. Phase 4 audit should start before large high-risk features are finished, so later modules call the same audit service.
5. Phase 5 runs throughout, but production deployment waits until permission and audit closure are complete.

## Risk Register
| Risk | Impact | Mitigation |
|---|---|---|
| `/admin/` base path conflicts with existing web/PWA routes | High | Use Vite `base`, router base, and Nginx `try_files` together; verify refresh deep links |
| Backend endpoint names differ from assumed names | High | Keep interface matrix current; frontend only calls confirmed endpoints |
| Admin page implements fake actions before backend exists | High | Missing endpoint pages must show disabled "未接入" state |
| Physical user purge deletes too much or too little | Critical | Require preview, job, audit, verification, isolated DB tests |
| Audit logs leak secrets | High | Add redaction helper and audit tests |
| Dashboard metrics are expensive | Medium | Use aggregated endpoints, pagination, time windows, cache |
| Full user module tests need MySQL | Medium | Add isolated test DB or Docker Compose test profile before claiming integration pass |

## Stage Gates
Phase 1 gate:
- `pnpm build` passes.
- `/admin/` route refresh works.
- request wrapper has deterministic auth-expiry/error behavior.

Phase 2 gate:
- six menu groups are live.
- Dashboard has health/operations metrics or explicit unconnected states.
- shared table pattern is used by at least two pages.

Phase 3 gate:
- launch policy, workplace, robot monitor, AV, and device pages have confirmed API contracts.
- Flutter launch policy compatibility is tested.

Phase 4 gate:
- prohibited word policy, report workflow, message audit, and operation audit are searchable and auditable.

Phase 5 gate:
- backend routes, migrations, tests, permissions, audit, admin build, and deployment smoke are complete.

## Open Questions
1. `/admin/` 是走同域主 Nginx，还是后台独立域名/端口？默认建议同域 `/admin/`，减少跨域和登录态问题。
2. 管理员角色体系是否只区分 super admin/admin，还是要做细粒度 RBAC？
3. Dashboard 指标是否已有 Prometheus/日志系统，还是先从业务数据库聚合？
4. LiveKit/CallGateway 当前生产部署路径和健康接口需要在服务器上确认。
5. 机器人/监控中心的配置是否在当前 Flutter 项目本地文件、后端数据库，还是外部服务中？
