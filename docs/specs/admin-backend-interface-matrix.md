# Admin Backend Interface Matrix

## Source Snapshot
Remote backend source:

```text
ssh ubuntu@42.194.218.158
cd /opt/wukongim-prod/src
```

Observed structure:

```text
go.mod
main.go
modules/
serverlib/
```

The remote source directory is not currently a git worktree, so implementation must create its own backups before edits and should record every changed path explicitly.

This matrix is based on read-only inspection of the remote source. No remote files, database rows, containers, or services were changed during this inventory.

## Summary
The backend already contains more of the requested control-plane work than the local admin frontend exposes.

Existing and reusable:
- VIP user fields, runtime entitlement checks, admin set-VIP endpoint, and tests.
- Customer-service assignment endpoint and public customer-service list endpoint.
- Client launch-policy endpoint, startup notice storage, and manager startup-notice endpoints.
- Existing manager user, group, message, report, workplace, common, and app version endpoints.

Still missing or not production-verified:
- Admin frontend pages/API wrappers for VIP, customer-service staff, and startup notices.
- VIP plan CRUD and plan history if we want plans beyond direct user-level grant/revoke.
- Central admin audit log is implemented in the local backend copy, but production deployment and DB integration verification are still pending.
- Physical user purge preview, confirmed purge job, verification rows, private-message fake-channel cleanup, and MinIO delete calls are implemented in the local backend copy, but production deployment and DB/MinIO integration verification are still pending.
- Same-phone re-registration proof is still pending because the local test environment currently has no MySQL service on `127.0.0.1:3306`.
- Maintenance-mode contract is implemented in the local backend copy, but production deployment is still pending.
- Future payment/order cleanup remains a documented rule; no payment/order tables currently exist in this slice.

## Phase 5 Probe Workflow
The admin frontend now includes a local backend contract probe:

```text
cd TangSengDaoDaoManager-main
ADMIN_API_BASE_URL=https://<host>/v1 pnpm probe:admin-backend
```

Optional authenticated checks:

```text
ADMIN_API_BASE_URL=https://<host>/v1 ADMIN_TOKEN=<admin-token> pnpm probe:admin-backend
```

Optional mutation validation checks:

```text
ADMIN_API_BASE_URL=https://<host>/v1 ADMIN_TOKEN=<admin-token> ADMIN_PROBE_MUTATIONS=true pnpm probe:admin-backend
```

Local probe helper tests:

```text
cd TangSengDaoDaoManager-main
pnpm test:probe
```

Safety rules:
- Default probes only use `GET` and `OPTIONS`.
- `ADMIN_PROBE_MUTATIONS` defaults to `false`.
- Mutation probes use sentinel IDs such as `__admin_probe_never_real_uid__` and omit `reason` only to verify backend validation.
- Do not run mutation probes against production until backend handlers are confirmed to validate before mutating.

The probe checks:
- `auth-required`: manager endpoints must reject unauthenticated requests with `401` or `403`.
- `reason-required`: high-risk operations must reject missing `reason`.
- frontend response contracts for successful authenticated reads:
  - paged reads must return top-level `{ list, count }`;
  - purge preview must return top-level `uid`, `counts`, and `verification`;
  - purge job must return top-level `job_id`, `uid`, and `status`.
- `GET /v1/manager/audit/logs`
- `GET /v1/manager/message/prohibit_word_policies`
- `GET /v1/manager/message/prohibit_word_hit_logs`
- `GET /v1/manager/message/record`
- `GET /v1/manager/message/recordpersonal`
- `OPTIONS /v1/manager/report/handle`
- `OPTIONS /v1/manager/message`
- `OPTIONS /v1/manager/user/set_vip`
- `OPTIONS /v1/manager/user/set_customer_service`
- `GET /v1/manager/users/__admin_probe_never_real_uid__/purge-preview`
- `GET /v1/manager/users/purge-jobs/__admin_probe_never_real_job_id__`
- `OPTIONS /v1/manager/users/__admin_probe_never_real_uid__/purge`

Result handling:
- `PASS`: the endpoint or guard satisfies the current contract check.
- `MISSING`: route returned `404`; keep the admin UI showing `接口未接入` and implement/route the backend before enabling the action.
- `FAIL`: backend behavior violates the contract, for example unauthenticated access succeeded or a high-risk mutation accepted an empty `reason`.
- `WARN`: the probe could not fully prove the contract, commonly because no admin token was supplied or the backend returned an unexpected but non-success status.

## VIP
### Existing Backend
Admin endpoints:

```text
POST /v1/manager/user/set_vip
POST /api/admin/set_vip
```

Request shape:

```json
{
  "uid": "user-id",
  "vip_level": 1,
  "vip_expire_time": "2026-06-30 23:59:59",
  "reason": "operator reason"
}
```

Existing storage:

```text
user.vip_level
user.vip_expire_time
```

Existing migration:

```text
modules/user/sql/user-20260424-00.sql
```

Existing entitlement constants:

```text
add_friend
create_group
invite_group_member
system_management
```

Existing backend enforcement found:
- Add friend checks active VIP.
- Group creation checks active VIP.
- Group member invite checks active VIP.
- VIP expiry downgrades the user and disables merchant-created groups.

Existing tests:

```text
modules/user/api_manager_vip_test.go
modules/user/vip_runtime_test.go
modules/user/vip_response_test.go
modules/user/friend_test.go
modules/group/api_test.go
```

### Current Local Backend State
- `POST /v1/manager/user/set_vip` and `POST /api/admin/set_vip` route to audited handlers in the local backend copy.
- Empty or missing `reason` is rejected before the VIP mutation.
- Audit snapshots are written through `admin_audit_log` and redact sensitive keys.

### Gaps
- No separate `vip_plan` table or VIP plan CRUD endpoint.
- No separate `/manager/vip/...` REST surface.
- Client has VIP fields in user responses, but no dedicated `GET /v1/vip/status` or `GET /v1/vip/features` endpoint observed.

### Recommended First Implementation
Reuse the existing backend user fields and `set_vip` path for MVP, then add only what is necessary:

```text
Backend:
- Add audit logging around set_vip.
- Add optional plan table only if admin needs named packages immediately.
- Add read endpoint if client needs standalone VIP refresh.

Admin frontend:
- Add VIP page that calls POST /v1/manager/user/set_vip.
- Show current VIP fields from /v1/manager/user/list.
```

## Customer-Service Staff
### Existing Backend
Admin endpoints:

```text
POST /v1/manager/user/set_customer_service
POST /api/admin/set_customer_service
```

Request shape:

```json
{
  "uid": "user-id",
  "enabled": true,
  "is_default": false,
  "reason": "operator reason"
}
```

Client endpoint:

```text
GET /v1/user/customerservices
```

Existing storage:

```text
user.category
user.customer_service_rank
```

Existing migration:

```text
modules/user/sql/user-20260424-01.sql
```

Existing behavior:
- Customer-service users are represented by category values normalized to `customer_service` for public responses.
- `customer_service_rank = 1` is the default customer-service staff member.
- Existing manager user list includes:
  - `is_customer_service`
  - `is_default_customer_service`
  - `customer_service_rank`

Existing tests:

```text
modules/user/api_manager_customer_service_test.go
modules/user/api_customer_service_public_test.go
modules/user/customer_service_runtime_test.go
```

### Current Local Backend State
- `POST /v1/manager/user/set_customer_service` and `POST /api/admin/set_customer_service` route to audited handlers in the local backend copy.
- Empty or missing `reason` is rejected before customer-service mutation.
- Audit snapshots are written through `admin_audit_log`.

### Gaps
- No dedicated `/manager/customer-service/staff` REST surface.
- Existing setter checks user existence but should also reject disabled, banned, or destroyed users before enabling staff status.
- Public `GET /v1/user/customerservices` returns only `uid` and `name`; confirm whether avatar/display order fields are needed by the Flutter client.

### Recommended First Implementation
Use the existing user columns for MVP instead of introducing a new `customer_service_staff` table.

```text
Backend:
- Harden set_customer_service validation.
- Add audit logging.
- Add optional list endpoint for admin if user list is not enough.

Admin frontend:
- Add customer-service page using user search + POST /v1/manager/user/set_customer_service.
- Display rank/default/status from /v1/manager/user/list.
```

## Launch Policy, Announcement, Forced Update
### Existing Backend
Client endpoint:

```text
GET /v1/app/launch-policy?platform=<android|windows>&version=<version>&build=<build>
```

Response includes:

```text
serverTime
platform
version
build
versionPolicy
startupNotice
```

Existing version policy source:

```text
app_version
```

Existing app version fields include:

```text
build_number
minimum_version
minimum_build_number
title
enabled
is_force
download_url
update_desc
```

Existing startup notice table:

```text
startup_notice
```

Startup notice fields include:

```text
notice_id
title
content
image_url
platforms
frequency
enabled
start_at
end_at
```

Existing migrations:

```text
modules/common/sql/common-20260516-01.sql
```

Admin notice endpoints:

```text
GET  /v1/manager/common/startup-notices
POST /v1/manager/common/startup-notices
PUT  /v1/manager/common/startup-notices/:notice_id
```

Existing app version endpoints:

```text
POST /v1/common/appversion
GET  /v1/common/appversion/:os/:version
GET  /v1/common/appversion/list
```

### Current Local Backend State
- Launch-policy response includes a `maintenance` block when maintenance mode is enabled in app config.
- Manager app config includes maintenance fields.
- Startup notice create/update and app-version create write admin audit rows with required `reason`.

### Gaps
- Launch platform normalization currently accepts Android and Windows only.
- No dedicated manager route for launch-policy CRUD; version policy is indirectly managed through app version endpoints.
- Startup notices do not currently expose target VIP levels or richer targeting.

### Recommended First Implementation
Reuse existing launch-policy and startup-notice backend contracts first.

```text
Backend:
- Add maintenance mode to launch-policy response and app/common config.
- Add audit around app version and startup notice changes.
- Add platform support only if client needs iOS/macOS/web immediately.

Admin frontend:
- Extend app update page for build_number, minimum_build_number, is_force, enabled, title.
- Add startup notice page using existing /v1/manager/common/startup-notices.
```

## User Purge
### Existing Backend
Client self-destroy endpoints:

```text
POST   /v1/user/sms/destroy
DELETE /v1/user/destroy/:code
```

Existing behavior:
- User self-destroy verifies SMS code.
- `destroyAccount` updates `user.phone`, `user.username`, and `user.is_destroy = 1`.
- Existing behavior is a soft destroy with phone/username rewritten, not a full physical purge.

Existing storage:

```text
user.is_destroy
```

Existing migration:

```text
modules/user/sql/user-20220222-01.sql
```

### Current Local Backend State
The local backend source copy now has these manager endpoints:

```text
GET    /v1/manager/users/:uid/purge-preview
DELETE /v1/manager/users/:uid/purge
GET    /v1/manager/users/purge-jobs/:job_id
```

Implemented locally:
- Super-admin authorization on all purge endpoints.
- `DELETE` requires JSON body with non-empty `reason` and exact `confirm_uid`.
- `user_purge_job` and `user_purge_verification` migrations.
- Backend-owned purge plan and response contract for admin preview/job status.
- Job status maps internal `completed` to admin-facing `succeeded`.
- Purge writes mandatory admin audit before destructive work.
- Purge invalidates realtime/device token state before DB cleanup.
- DB cleanup includes user identity row, VIP/customer-service user fields by deleting the row, user-created groups, user-created group metadata, group messages in those groups, group messages sent by the user, private fake-channel messages containing the target UID, conversation/offset rows, devices, friends, settings, tags, moments, workplace rows, call rows, and message backup metadata.
- MinIO/object deletion is called through backend file service for avatars, group avatars, message backup objects, and message payload object keys found in deleted messages.
- Object deletion failures are recorded in purge job `result_json.object_delete_errors`.
- If any object deletion fails, the purge job is marked `failed` while retaining result details for audit and future retry handling.
- SQL LIKE patterns for private fake-channel cleanup are escaped to avoid wildcard expansion.

Still not production-verified:
- MySQL integration tests for real schema and row counts.
- Same-phone re-registration proof.
- Old-token authentication rejection after purge.
- MinIO physical deletion under real bucket credentials.
- Retry endpoint/UI for failed `object_delete_errors`.
- Exact active production table set; some optional tables may differ by deployment.

### Admin Frontend
The admin frontend now has a user physical purge entry point:

```text
TangSengDaoDaoManager-main/src/api/userPurge.ts
TangSengDaoDaoManager-main/src/pages/user/purge.vue
TangSengDaoDaoManager-main/src/menu/index.ts -> /user/purge
```

The page supports:
- purge preview by UID;
- affected-count display for created groups, group messages, private messages, MinIO objects, devices, friends, and reports;
- blocker/warning display from the backend preview;
- exact UID confirmation before execution;
- required high-risk `reason` prompt before `DELETE /manager/users/:uid/purge`;
- purge job lookup by `job_id`;
- clear `接口未接入` feedback when the backend route is missing.

The page does not send SQL, table names, MinIO paths, or delete plans. All destructive scope is backend-owned.

Required new backend behavior:
- Create purge job table.
- Create purge verification table.
- Lock target user before purge.
- Revoke tokens, sessions, and devices.
- Physically delete user-created groups.
- Physically delete group messages sent by the user.
- Physically delete all messages in groups created by the user.
- Physically delete private messages and private conversations owned by the user.
- Physically delete user-owned MinIO objects.
- Physically delete future payment/order records.
- Remove customer-service status.
- Remove VIP entitlement state.
- Delete user row and phone/username unique-key rows.
- Verify same phone can register again.
- Verify no hard-delete table references the old UID or phone.

### Tables To Inspect During Implementation
This list must be confirmed against the active schema before writing purge SQL:

```text
user
friend
friend_apply
blacklist or user_blacklist equivalent
group
group_member
group_setting
group_invite
group_notice_history
group_reminder
group_reminder_member
group_reminder_done
message, message1, message2, message3, message4
message_extra
message_user_extra*
member_readed
reaction_users
pinned_message
favorite
tag and tag members
moment and comments/likes
report tables
workplace user app/record/preferences tables
monitor tables when uid-owned
robot group tables when group-owned
future payment/order tables
```

## Admin Audit
### Current Local Backend State
The local backend source copy now includes:
- `admin_audit_log` migration.
- `AdminAuditDB` insert/query helpers.
- Required `reason` enforcement for audit normalization.
- Sensitive snapshot redaction for keys containing `password`, `passwd`, `pwd`, `token`, `secret`, `private_key`, `privatekey`, or `rsa_private`.
- `GET /v1/manager/audit/logs` with filters for `operator_uid`, `action`, `target_type`, `target_id`, `start_at`, and `end_at`.

### Admin Frontend
The admin frontend now has a read-only audit entry point:

```text
TangSengDaoDaoManager-main/src/api/audit.ts
TangSengDaoDaoManager-main/src/pages/audit/logs.vue
TangSengDaoDaoManager-main/src/menu/index.ts -> /audit/logs
```

The page queries `GET /v1/manager/audit/logs` through the normalized admin API base and shows "接口未接入" when the backend route is missing. It also documents the high-risk operation contract and explicitly calls out that audit snapshots must not store `password`, `token`, or `secret` fields.

### Gaps
Required new audit coverage:
- VIP grant/revoke/expiry adjustment: local audited setter implemented.
- Customer-service assign/remove/enable/disable/default: local audited setter implemented.
- Startup notice create/update: local audited endpoints implemented.
- Forced update/version policy create: local audited endpoint implemented.
- User purge execution: local audit implemented before destructive work.
- User purge preview read is not currently audited because it is non-mutating.
- Existing high-risk operations later: ban/unban user, delete message, group ban, group mute, app config changes.

Endpoint in local backend copy:

```text
GET /v1/manager/audit/logs
```

### Admin Frontend Reason Gate
The admin frontend now has a shared high-risk action prompt:

```text
TangSengDaoDaoManager-main/src/utils/highRiskAction.ts
```

Currently wired high-risk operations:

```text
DELETE /v1/manager/message              reason required
POST   /v1/manager/user/set_vip         reason required
POST   /v1/manager/user/set_customer_service reason required
```

The helper requires a non-empty `reason` before the request is sent and explicitly guards audit snapshots against sensitive keys named like `password`, `token`, or `secret`.

### Backend Requirements
The backend must not trust the frontend reason gate. It still needs to enforce:
- Reject high-risk operations with empty or missing `reason`.
- Write audit records with actor, action, target_type, target_id, before_json, after_json, reason, ip, user_agent, and created_at.
- Redact sensitive fields before saving before/after snapshots.
- Keep audit writes in the same transaction as the business mutation when possible.
- Return a clear 4xx error if audit write fails for a mandatory high-risk operation.
- Cover VIP grant/revoke/expiry adjustment, customer-service assign/remove/default, message delete, report handling, startup notice changes, forced update changes, user purge preview/execution, bans, and app config changes.

## Forbidden-Word Policy
### Existing Backend
The admin frontend still keeps compatibility with the existing word-list endpoint:

```text
GET    /v1/manager/message/prohibit_words
POST   /v1/manager/message/prohibit_words
DELETE /v1/manager/message/prohibit_words
```

### Admin Frontend
The admin frontend now upgrades the old word-list page into a content-safety policy entry point:

```text
TangSengDaoDaoManager-main/src/pages/message/prohibitwords.vue
TangSengDaoDaoManager-main/src/api/message.ts
```

The page contains:
- Policy version filters by keyword, group, status, and version.
- Publish and rollback actions that require a reason for backend audit.
- Existing word-list management through `/manager/message/prohibit_words`.
- A hit-log dialog for user, version, keyword, target, and action review.
- Clear "接口未接入" feedback when new policy endpoints are missing.

### Gaps
Required new backend endpoints:

```text
GET  /v1/manager/message/prohibit_word_policies
POST /v1/manager/message/prohibit_word_policies/publish
POST /v1/manager/message/prohibit_word_policies/rollback
GET  /v1/manager/message/prohibit_word_hit_logs
```

Required new backend behavior:
- Store forbidden-word policy group, version, status, word_count, hit_count, published_by, published_at, and rollback lineage.
- Make publish/rollback atomic and write admin audit records with reason.
- Record hit logs with policy_version, group, word, uid, target_type, target_id, message_id, action, content_preview, device_id, and created_at.
- Support rollback to a previous published version without deleting historical policies or hit logs.
- Redact message content in hit logs to a safe preview, not full private content.

## Report Moderation
### Existing Backend
The existing admin frontend already lists user and group reports through:

```text
GET /v1/manager/report/list
```

The existing list is now expected to tolerate these optional query filters:

```text
channel_type=1|2
status=pending|processed|rejected|banned
keyword=<reporter or target id/name>
handler_uid=<admin uid>
page_index=<number>
page_size=<number>
```

### Admin Frontend
The admin frontend now shares one moderation component for user and group reports:

```text
TangSengDaoDaoManager-main/src/api/report.ts
TangSengDaoDaoManager-main/src/pages/report/components/ReportModeration.vue
TangSengDaoDaoManager-main/src/pages/report/user.vue
TangSengDaoDaoManager-main/src/pages/report/group.vue
```

The UI now exposes:
- Processing status filters: `pending`, `processed`, `rejected`, `banned`.
- Handler filters by `handler_uid`.
- Table fields for `handler_name`, `handle_remark`, and `handled_at`.
- Actions for process, reject, and ban.
- A required handling remark before submit.
- Clear "接口未接入" feedback when `/manager/report/handle` is missing.

### Gaps
Required new backend endpoint:

```text
POST /v1/manager/report/handle
```

Request shape:

```json
{
  "report_id": "report-id",
  "channel_type": "1",
  "action": "processed",
  "handle_remark": "handled after review",
  "ban_target": false
}
```

Required new backend behavior:
- Add report status lifecycle: pending -> processed/rejected/banned.
- Persist handler UID/name, handle_remark, handled_at, and target ban result.
- For `banned`, call existing user/group ban logic through backend authorization and audit paths, not from the frontend.
- Make repeat handling idempotent or return 409 conflict with current status.
- Write admin audit records for processed/rejected/banned, including reason and target.
- Keep report content immutable; handling should append moderation state, not rewrite evidence.

## Message Audit Filtering
### Existing Backend
The admin frontend already uses the existing message record endpoints:

```text
GET    /v1/manager/message/record
GET    /v1/manager/message/recordpersonal
DELETE /v1/manager/message
```

### Admin Frontend
The admin frontend now shares one message audit component:

```text
TangSengDaoDaoManager-main/src/api/message.ts
TangSengDaoDaoManager-main/src/pages/message/components/MessageAuditTable.vue
TangSengDaoDaoManager-main/src/pages/message/record.vue
TangSengDaoDaoManager-main/src/pages/message/recordpersonal.vue
```

The UI exposes filters for:
- `sender_uid`
- `target_id`
- `message_type`
- `device_id`
- `start_at`
- `end_at`
- existing `keyword`, `channel_id`, `uid`, and `touid`

### Gaps
Existing endpoints must confirm or add support for these query fields:

```text
GET /v1/manager/message/record
  channel_id=<group id>
  sender_uid=<uid>
  target_id=<group id>
  message_type=text|image|voice|video|file|card
  device_id=<device id>
  start_at=<YYYY-MM-DD HH:mm:ss>
  end_at=<YYYY-MM-DD HH:mm:ss>

GET /v1/manager/message/recordpersonal
  uid=<uid>
  touid=<uid>
  sender_uid=<uid>
  target_id=<uid>
  message_type=text|image|voice|video|file|card
  device_id=<device id>
  start_at=<YYYY-MM-DD HH:mm:ss>
  end_at=<YYYY-MM-DD HH:mm:ss>
```

Required new backend behavior:
- Apply all filters server-side with pagination; do not fetch all rows for frontend filtering.
- Return stable fields: `message_id`, `message_seq`, `sender`, `sender_name`, `channel_id`, `channel_type`, `target_id`, `message_type`, `payload`, `is_encrypt`, `device_id`, `device_name`, `device_model`, `revoke`, `is_deleted`, `created_at`.
- Index common audit filters: channel/conversation, sender, device_id, message_type, created_at.
- Enforce backend authorization for audit reads; frontend route visibility is not the security boundary.
- Continue writing operation audit for message deletes, including actor, target message, channel, reason, and timestamp.

## Admin Frontend Gap Matrix
Local admin frontend already has pages for:
- User list/add/ban/admin.
- Group list/members/ban/mute.
- Message record/send/prohibit words.
- Report list.
- Workplace app/category/banner.
- App update.
- App config.

Needed pages/API wrappers:

```text
src/api/vip.ts
src/pages/vip/
src/menu/modules/vip.ts

src/api/customerService.ts
src/pages/customer-service/
src/menu/modules/customerService.ts

src/api/launchPolicy.ts
src/pages/launch-policy/
src/menu/modules/launchPolicy.ts

src/api/userPurge.ts
src/pages/user/purge.vue

src/api/audit.ts
src/pages/audit/
src/menu/modules/audit.ts

src/api/userPurge.ts
src/pages/user/purge.vue
```

## Recommended Implementation Order
1. Admin frontend adapters for already-existing backend capabilities:
   - VIP manual set/revoke.
   - Customer-service staff assignment.
   - Startup notices.
   - App version forced-update fields.
2. Backend audit module and audit calls around the existing capabilities.
3. Backend maintenance-mode addition to launch policy.
4. Backend user purge preview/job/verification, with tests first.
5. Admin user purge UI.
6. Optional VIP plan CRUD after the manual VIP MVP is stable.
