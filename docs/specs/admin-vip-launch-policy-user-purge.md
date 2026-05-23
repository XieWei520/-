# Spec: Admin VIP, Launch Policy, Announcement, and User Purge

## Objective
Upgrade the existing TangSengDaoDao admin frontend into the control plane for VIP entitlements, customer-service staff assignment, startup announcements, forced updates, maintenance mode, and irreversible user deletion.

The work must support the current Flutter IM client and the TangSengDaoDao/WuKongIM backend. Success means operators can configure VIP, customer-service staff, and launch policies from the admin console, the client applies those policies at runtime, and administrators can fully purge a user so the same phone number can register again.

This is a production-sensitive change. Backend authorization, audit logs, and deletion verification are mandatory.

Backend interface inventory is tracked in `docs/specs/admin-backend-interface-matrix.md`.

## Assumptions
1. The admin UI continues to use `TangSengDaoDaoManager-main` with Vue 3, TypeScript, Vite, Pinia, and Element Plus.
2. Client runtime policy continues to flow through `/v1/app/launch-policy`.
3. Admin APIs continue to use `/manager/...`.
4. The complete TangSengDaoDaoServer backend source tree is deployed on the cloud server reachable with `ssh ubuntu@42.194.218.158`.
5. User identity data can be physically deleted, including phone and username unique-key rows, so the same phone can register again.
6. Group messages sent by the purged user, groups created by the purged user, and user-owned MinIO files are physically deleted during purge.
7. Financial/order records, if introduced later, are physically deleted during user purge.
8. VIP first release uses a conservative MVP scope: VIP identity display, backend entitlement status, admin manual grant/revoke/expiry, and core permission gates. Complex commercial benefits can be added after the MVP proves the contract.
9. Customer-service staff assignment is an admin-managed role, not a VIP benefit.

## Tech Stack
Client:
- Flutter, Dart 3.11, Riverpod, GoRouter.
- Existing API configuration in `lib/core/config/api_config.dart`.
- Existing VIP client area in `lib/modules/vip/`.
- Existing launch policy client area in `lib/modules/launch_policy/`.

Admin frontend:
- Vue 3.3, TypeScript, Vite, Pinia, Element Plus.
- Source root: `TangSengDaoDaoManager-main/src`.
- Existing API wrapper: `TangSengDaoDaoManager-main/src/utils/axios.ts`.
- Existing menu modules: `TangSengDaoDaoManager-main/src/menu/modules`.

Backend:
- TangSengDaoDaoServer Go service with MySQL, Redis, MinIO, WuKongIM integration, and SQL migrations.
- Complete backend source is on `ubuntu@42.194.218.158`.
- Production deployment currently expects full backend source for `deploy/production/Dockerfile.tsdd`.

## Commands
Client:
- Get dependencies: `flutter pub get`
- Analyze: `flutter analyze`
- VIP focused tests: `flutter test test/data/models/user_info_model_test.dart test/modules/vip/vip_guard_test.dart`
- Launch policy focused tests: `flutter test test/app/launch_policy_dialog_context_test.dart`

Admin frontend:
- Install dependencies: `cd TangSengDaoDaoManager-main && pnpm install`
- Dev server: `cd TangSengDaoDaoManager-main && pnpm dev`
- Build: `cd TangSengDaoDaoManager-main && pnpm build`
- Lint: `cd TangSengDaoDaoManager-main && pnpm lint`
- Typecheck: `cd TangSengDaoDaoManager-main && pnpm typecheck`
- Admin smoke: `cd TangSengDaoDaoManager-main && pnpm smoke:admin`
- Backend contract probe: `cd TangSengDaoDaoManager-main && ADMIN_API_BASE_URL=https://<host>/v1 pnpm probe:admin-backend`

Backend, after complete source is available:
- Connect to backend host: `ssh ubuntu@42.194.218.158`
- Unit tests: `go test ./modules/...`
- Build: `go build -o /tmp/tsdd-admin-policy-check .`
- Migration dry-run or local DB migration command must be defined in the backend repo before implementation starts.

Deployment verification:
- nginx validation: `docker compose exec -T nginx nginx -t`
- Admin route smoke: `Invoke-WebRequest -Uri https://<domain>/admin/ -UseBasicParsing`

## Project Structure
Client:
- `lib/core/config/api_config.dart` -> launch policy and VIP endpoint constants.
- `lib/modules/launch_policy/` -> forced update, announcement, and maintenance UI handling.
- `lib/modules/vip/` -> VIP badges, guards, and entitlement display.
- `test/modules/vip/` and `test/app/` -> client regression tests.

Admin frontend:
- `TangSengDaoDaoManager-main/src/api/vip.ts` -> VIP admin API wrappers.
- `TangSengDaoDaoManager-main/src/api/customerService.ts` -> customer-service staff admin API wrappers.
- `TangSengDaoDaoManager-main/src/api/launchPolicy.ts` -> announcement, forced update, and maintenance API wrappers.
- `TangSengDaoDaoManager-main/src/api/userPurge.ts` -> user purge preview, execute, and job status API wrappers.
- `TangSengDaoDaoManager-main/src/api/audit.ts` -> admin audit log API wrappers.
- `TangSengDaoDaoManager-main/src/pages/vip/` -> VIP plan, user entitlement, and audit pages.
- `TangSengDaoDaoManager-main/src/pages/customer-service/` -> customer-service staff list, assign, remove, and status pages.
- `TangSengDaoDaoManager-main/src/pages/launch-policy/` -> version policy, announcement, and maintenance pages.
- `TangSengDaoDaoManager-main/src/pages/user/purge.vue` -> high-risk user deletion page or tab.
- `TangSengDaoDaoManager-main/src/pages/audit/` -> high-risk operation audit pages.
- `TangSengDaoDaoManager-main/src/menu/modules/` -> new menu entries.

Backend:
- `modules/vip/` -> VIP plan, entitlement, feature, and audit logic.
- `modules/customer_service/` or existing user/customer-service module -> customer-service staff assignment and lookup logic.
- `modules/common/` or `modules/app/` -> launch policy, announcement, maintenance endpoints.
- `modules/user/` -> purge preview, purge job, user deletion, phone release.
- `modules/audit/` -> reusable admin audit logging.
- `modules/*/sql/` -> MySQL migrations for all new tables and indexes.

## Code Style
Prefer explicit domain models and typed request bodies over loosely shaped `any` objects.

Admin frontend example:

```ts
export interface VipGrantRequest {
  plan_id: string;
  expire_at?: string;
  reason: string;
}

export function grantVip(uid: string, data: VipGrantRequest) {
  return request({
    url: `/manager/vip/users/${uid}/grant`,
    method: 'post',
    data
  });
}
```

Backend example:

```go
func (s *Service) PurgeUser(ctx context.Context, req PurgeUserRequest) (*PurgeJob, error) {
    if err := req.Validate(); err != nil {
        return nil, err
    }
    if err := s.audit.RequireReason(req.Reason); err != nil {
        return nil, err
    }
    return s.purgeRunner.Enqueue(ctx, req)
}
```

Deletion code must be idempotent where possible. Retrying a failed purge job should not resurrect partially deleted data or skip verification.

## Testing Strategy
VIP:
- Backend tests cover plan CRUD, entitlement grant/revoke/expiry, and feature evaluation.
- Client tests cover VIP status parsing and entitlement gating.
- Admin frontend tests or smoke checks cover create plan, grant VIP, revoke VIP, and display audit rows.

Customer service:
- Backend tests cover assigning a user as customer-service staff, removing staff status, listing enabled staff, and rejecting disabled/deleted users.
- Client tests or API contract tests cover customer-service list/status parsing if the current client endpoint changes.
- Admin frontend build verifies the staff management page compiles.

Launch policy and announcements:
- Backend tests cover platform/version matching, forced update decisions, maintenance override, announcement targeting, priority ordering, and display modes.
- Client tests cover forced update blocking, optional update, maintenance dialog/page, and announcement dedupe by ID.
- Admin build verifies policy pages compile.

User purge:
- Backend tests must run against an isolated test database or repository fakes.
- Required cases:
  - purge preview reports affected rows before deletion;
  - purge deletes user identity and releases phone;
  - old token/session/device records are invalidated;
  - same phone can register again and receives a new UID;
  - purge job is retry-safe;
  - verification fails if any configured hard-delete table still references the old UID or phone.

Audit:
- Backend tests prove high-risk operations write audit logs with operator, target, action, reason, before/after snapshots, IP, and timestamp.
- Audit logs must not store cleartext passwords, tokens, or long-lived secrets.

## Boundaries
- Always:
  - Enforce admin permissions on backend endpoints.
  - Record audit logs for VIP changes, announcement publish/unpublish, forced update changes, maintenance changes, message deletion, user ban/unban, and user purge.
  - Record audit logs for customer-service staff assignment and removal.
  - Require an operator reason for user purge and other destructive actions.
  - Use a purge preview before physical user deletion.
  - Verify phone reuse with an automated backend test.
  - Keep frontend menu permissions as UX only; never treat them as authorization.
- Ask first:
  - Changing existing public client API route names.
  - Restarting production services or applying production migrations.
- Never:
  - Implement user purge as ad hoc SQL in the admin frontend.
  - Delete users without an audit log and purge job record.
  - Store production secrets in repo files, audit logs, client logs, or admin page state.
  - Trust client-side VIP checks as backend authorization.

## Data Model
VIP:

```text
vip_plan
- id
- name
- level
- duration_days
- price
- features_json
- status
- created_at
- updated_at

vip_user_entitlement
- id
- uid
- plan_id
- level
- start_at
- expire_at
- status
- source
- created_at
- updated_at

vip_feature
- id
- code
- name
- description
- status
- created_at
- updated_at

vip_audit_log
- id
- uid
- operator_uid
- action
- before_json
- after_json
- reason
- created_at
```

Customer service:

```text
customer_service_staff
- id
- uid
- display_name
- avatar
- status
- sort_order
- assigned_by
- assigned_at
- removed_by
- removed_at
- created_at
- updated_at
```

Launch policy and announcement:

```text
app_launch_policy
- id
- platform
- latest_version
- latest_build
- min_supported_version
- min_supported_build
- force_update
- download_url
- changelog
- maintenance_enabled
- maintenance_message
- rollout_percent
- status
- created_at
- updated_at

app_announcement
- id
- title
- content
- image_url
- link_url
- display_mode
- target_platforms
- target_versions
- target_vip_levels
- priority
- start_at
- end_at
- status
- created_at
- updated_at
```

User purge:

```text
user_purge_job
- id
- uid
- phone_hash
- operator_uid
- status
- preview_json
- result_json
- reason
- error
- started_at
- finished_at
- created_at

user_purge_verification
- id
- job_id
- check_name
- status
- detail_json
- created_at
```

Admin audit:

```text
admin_audit_log
- id
- operator_uid
- operator_name
- action
- target_type
- target_id
- before_json
- after_json
- reason
- ip
- user_agent
- created_at
```

## API Contract
Client:

```text
GET /v1/app/launch-policy?platform=<platform>&version=<version>&build=<build>
GET /v1/vip/status
GET /v1/vip/features
```

Admin VIP:

```text
GET    /manager/vip/plans
POST   /manager/vip/plans
PUT    /manager/vip/plans/{id}
POST   /manager/vip/users/{uid}/grant
POST   /manager/vip/users/{uid}/revoke
GET    /manager/vip/users/{uid}
GET    /manager/vip/audit
```

Admin customer service:

```text
GET    /manager/customer-service/staff
POST   /manager/customer-service/staff
PUT    /manager/customer-service/staff/{uid}
DELETE /manager/customer-service/staff/{uid}
```

Client customer service:

```text
GET /v1/user/customerservices
```

Admin launch policy:

```text
GET    /manager/app/launch-policies
POST   /manager/app/launch-policies
PUT    /manager/app/launch-policies/{id}
POST   /manager/app/launch-policies/{id}/publish
POST   /manager/app/launch-policies/{id}/disable
GET    /manager/app/announcements
POST   /manager/app/announcements
PUT    /manager/app/announcements/{id}
POST   /manager/app/announcements/{id}/publish
POST   /manager/app/announcements/{id}/disable
```

Admin user purge:

```text
GET    /manager/users/{uid}/purge-preview
DELETE /manager/users/{uid}/purge
GET    /manager/users/purge-jobs/{job_id}
```

Admin audit:

```text
GET /manager/audit/logs
```

## User Purge Rules
The purge flow is a backend job with strict phases:

1. Lock the target user and reject new login/session refresh.
2. Revoke tokens, device sessions, Redis login caches, and realtime sessions.
3. Delete friend relations, friend applications, and blacklist rows.
4. Delete group membership rows.
5. Resolve groups created by the user:
   - physically delete groups created by the purged user;
   - delete group membership, group settings, group blacklist, group mute, group notice, group avatar, and related group metadata for those groups.
6. Delete user settings, tags, favorites, moments, reports, VIP entitlements, client preferences, and workplace preferences.
7. Physically delete financial/order records for the purged user if those tables exist.
8. Delete private conversations and private messages according to backend schema ownership.
9. Handle group messages according to the approved product rule.
   - physically delete group messages sent by the purged user;
   - physically delete all messages belonging to groups created by the purged user.
10. Physically delete avatar and user-owned MinIO upload objects, including objects referenced by the user's deleted private messages, deleted group messages, and deleted groups.
11. Delete the user main row and all phone/username unique-key rows.
12. Verify no configured hard-delete table references the old UID, username, or phone.
13. Mark the purge job complete only after verification passes.

The phone must be reusable after phase 10 and verified by a registration test.

### User Purge Admin Frontend Slice
The local admin frontend now includes the purge control shell:

```text
TangSengDaoDaoManager-main/src/api/userPurge.ts
TangSengDaoDaoManager-main/src/pages/user/purge.vue
TangSengDaoDaoManager-main/src/menu/index.ts -> /user/purge
```

This slice is intentionally contract-first:
- It calls only `GET /manager/users/{uid}/purge-preview`, `DELETE /manager/users/{uid}/purge`, and `GET /manager/users/purge-jobs/{job_id}`.
- It requires exact UID confirmation before delete.
- It uses the shared high-risk prompt, so the delete request always includes `reason`.
- It displays `接口未接入` when the backend returns `404`.
- It does not fake deletion success and does not contain SQL, table names, or MinIO object paths.

Backend implementation remains required before production use. The backend must enforce the same UID confirmation and `reason` checks even though the frontend already prompts for them.

### User Purge Backend Slice 1
This slice is limited to the local backend source copy. It must not execute against production data until reviewed and explicitly deployed.

1. Add manager endpoints under `/v1/manager/users`:
   - `GET /:uid/purge-preview`
   - `DELETE /:uid/purge`
   - `GET /purge-jobs/:job_id`
2. Require super-admin authorization for all purge endpoints.
3. Require a JSON body for execution:

```json
{
  "reason": "operator-entered reason",
  "confirm_uid": "target uid"
}
```

4. Refuse execution unless `confirm_uid` exactly matches the path UID and `reason` is non-empty.
5. Insert a `user_purge_job` row before destructive work and keep the job row after purge for accountability.
6. Write an admin audit log before destructive work.
7. Use a fixed backend-owned purge plan. The admin frontend never sends SQL or table names.
8. Delete user-owned MinIO objects through backend storage code, not shell scripts.
9. Keep pure logic tests for the purge plan and request validation. DB integration tests are required before production deployment, including same-phone re-registration proof.

Current local backend progress:
- Added local migrations for `admin_audit_log`, `user_purge_job`, and `user_purge_verification`.
- Added audited `set_vip`, `set_customer_service`, startup-notice, app-version, app-config, and user-purge execution paths.
- Added `GET /v1/manager/audit/logs` with basic filters and pagination.
- Added user purge preview, confirmed execution, and job lookup endpoints under `/v1/manager/users`.
- Added backend-owned purge SQL generation for user identity, created groups, group-owned messages, group messages sent by the user, private fake-channel messages containing the target UID, user devices, friends/settings, tags, moments, calls, workplace rows, message backup metadata, and conversation/offset rows.
- Added MinIO/object cleanup through the backend file service using avatar keys, group avatar keys, backup object keys, and message payload object keys.
- Added pure tests for audit reason enforcement, audit redaction, audit list response shape, purge request validation, purge preview/job response contract, purge SQL coverage, fake-channel LIKE escaping, object-key extraction, and reminder child-delete ordering.

Still required before production deployment:
- Run DB integration tests against an isolated MySQL schema matching production.
- Verify same-phone re-registration produces a new UID after purge.
- Verify old tokens/session/device state cannot authenticate after purge.
- Verify MinIO deletion and retry/failure behavior against a real bucket.
- Confirm the exact active production table set before applying purge SQL to production.

## Launch Policy Client Behavior
The client should apply server policy in this order:

1. If `maintenance_enabled` is true, show a blocking maintenance state unless the response explicitly allows bypass for the current operator/test account.
2. If current build is below `min_supported_build`, show forced update and block entry.
3. If current build is below `latest_build`, show optional update unless suppressed by policy.
4. If an active announcement matches platform/version/user/VIP targeting, show it according to `display_mode`.
5. Store read announcement IDs locally for `once` and `daily` display modes.

## Implementation Plan
Phase 0: Backend source and interface inventory
- Connect to `ubuntu@42.194.218.158` and confirm the complete backend source path.
- Generate an interface matrix for existing `/manager/...`, `/v1/app/launch-policy`, and VIP-related endpoints.
- Confirm the exact MySQL tables and MinIO buckets touched by physical deletion.

Phase 0.5: Admin frontend bridge for existing backend capabilities
- Add local admin API wrappers and pages for backend capabilities that already exist:
  - VIP manual grant/revoke through `POST /v1/manager/user/set_vip`.
  - Customer-service assignment through `POST /v1/manager/user/set_customer_service`.
  - Startup notices through `/v1/manager/common/startup-notices`.
  - App version/forced-update fields through `/v1/common/appversion`.
- Do not implement physical user purge in the frontend until backend preview/job/verification endpoints exist.
- Verify with `cd TangSengDaoDaoManager-main && pnpm build`.

Phase 1: Database and backend contracts
- Add migrations for VIP, launch policy, announcement, purge job, purge verification, and admin audit tables.
- Add backend service interfaces and tests before implementation.
- Add admin authorization middleware checks for all new routes.

Phase 2: Launch policy and announcement
- Implement backend policy matching.
- Extend client launch policy model and UI handling if needed.
- Implement admin pages for policy and announcement management.
- Verify forced update, maintenance, and announcement flows.

Phase 3: VIP management
- Implement VIP plan and entitlement backend.
- Wire client VIP status/features to backend.
- Implement admin VIP pages.
- Verify grant, revoke, expiry, and entitlement checks.

Phase 4: Customer-service staff management
- Implement customer-service staff assignment backend and audit logging.
- Wire admin page for staff list, assign, remove, enable/disable, and sort.
- Confirm the client customer-service entry uses the managed staff list.

Phase 5: User purge
- Implement purge preview.
- Implement purge job runner and verification checks.
- Implement admin UI for preview, confirmation, job status, and result display.
- Verify same-phone re-registration and old-token invalidation.

Phase 6: Audit and release hardening
- Ensure all high-risk actions write audit logs.
- Add admin audit list and filtering.
- Run full backend tests, admin build, client focused tests, and deployment route smoke.

## Tasks
- [ ] Task: Backend source and endpoint matrix
  - Acceptance: Document lists existing and missing endpoints for VIP, launch policy, announcement, user purge, and audit.
  - Verify: Human review of matrix before backend implementation.
  - Files: `docs/specs/` or backend docs.

- [ ] Task: Admin frontend bridge for existing backend capabilities
  - Acceptance: Admin has pages for VIP manual grant/revoke, customer-service staff assignment, startup notice management, and richer app-version forced-update fields.
  - Verify: `cd TangSengDaoDaoManager-main && pnpm build`
  - Files: `TangSengDaoDaoManager-main/src/api/vip.ts`, `src/api/customerService.ts`, `src/api/launchPolicy.ts`, `src/pages/vip/`, `src/pages/customer-service/`, `src/pages/launch-policy/`, `src/components/BdAppVersion/index.vue`, `src/pages/tool/appupdate.vue`, `src/menu/modules/`.

- [ ] Task: Launch policy backend contract
  - Acceptance: Backend returns forced update, optional update, maintenance, and announcement payload for platform/version/build.
  - Verify: `go test ./modules/common ./modules/app`
  - Files: backend `modules/common` or `modules/app`.

- [ ] Task: Launch policy admin pages
  - Acceptance: Admin can create, edit, publish, disable, and inspect launch policies and announcements.
  - Verify: `cd TangSengDaoDaoManager-main && pnpm build`
  - Files: `TangSengDaoDaoManager-main/src/api/launchPolicy.ts`, `src/pages/launch-policy/`, `src/menu/modules/launchPolicy.ts`.

- [ ] Task: VIP backend contract
  - Acceptance: Backend supports VIP plan CRUD, grant, revoke, expiry, status, MVP feature checks, and audit rows.
  - Verify: `go test ./modules/vip ./modules/user`
  - Files: backend `modules/vip`, `modules/user`, migrations.

- [ ] Task: VIP admin pages
  - Acceptance: Admin can manage VIP plans and manually grant/revoke/expire user VIP by UID or phone.
  - Verify: `cd TangSengDaoDaoManager-main && pnpm build`
  - Files: `TangSengDaoDaoManager-main/src/api/vip.ts`, `src/pages/vip/`, `src/menu/modules/vip.ts`.

- [ ] Task: Customer-service backend contract
  - Acceptance: Backend supports assigning/removing customer-service staff, enabling/disabling staff, ordering staff, listing enabled staff for clients, and audit rows.
  - Verify: `go test ./modules/customer_service ./modules/user`
  - Files: backend `modules/customer_service` or existing user/customer-service module, migrations.

- [ ] Task: Customer-service admin pages
  - Acceptance: Admin can search users, set a user as customer-service staff, remove staff status, enable/disable staff, and adjust display order.
  - Verify: `cd TangSengDaoDaoManager-main && pnpm build`
  - Files: `TangSengDaoDaoManager-main/src/api/customerService.ts`, `src/pages/customer-service/`, `src/menu/modules/customerService.ts`.

- [ ] Task: User purge backend
  - Acceptance: Backend supports purge preview, confirmed purge job, job status, verification, phone release, and token invalidation.
  - Verify: `go test ./modules/user ./modules/audit`
  - Files: backend `modules/user`, `modules/audit`, migrations.

- [ ] Task: User purge admin UI
  - Acceptance: Admin sees purge impact, must enter UID and reason, can execute purge, and can inspect job result.
  - Verify: `cd TangSengDaoDaoManager-main && pnpm build`
  - Files: `TangSengDaoDaoManager-main/src/api/userPurge.ts`, `src/pages/user/purge.vue`.

- [ ] Task: Audit log integration
  - Acceptance: High-risk actions write searchable audit logs and never include secrets.
  - Verify: backend audit tests and admin build.
  - Files: backend `modules/audit`, admin `src/api/audit.ts`, `src/pages/audit/`.

## Success Criteria
- Admin can configure VIP plans and grant/revoke VIP for a user.
- Client can fetch and enforce VIP status/features from backend.
- Admin can set and remove customer-service staff.
- Client customer-service entry uses the backend-managed enabled staff list.
- Admin can configure announcements, maintenance mode, optional update, and forced update by platform/version.
- Client blocks entry for forced update and maintenance, and displays matching announcements once/daily/every-start according to policy.
- Admin can preview and execute user purge through a backend job.
- Purged user's phone can register again and receives a new UID.
- Old UID cannot authenticate or use old tokens after purge.
- Backend verification reports no hard-delete-table references to the purged UID or phone.
- Every high-risk admin operation is permission-checked and audit-logged.

Current verification status:
- Passed local pure tests:
  - `go test ./modules/common -run "Test(ToMaintenanceResp|LaunchPolicyRespIncludesMaintenance|NormalizeAdminAuditLog|AdminAuditLogResp)"`
  - `go test ./modules/user -run "Test(UserPurgePreviewResponse|UserPurgeJobResponse|BuildUserPurgePlan|ValidatePurgeUserReq|ExtractPurgeObjectKeys|SQLTableName|UserPurgeSQLSteps|PersonalChannelPurgeWhere)"`
- Full `go test ./modules/common ./modules/user` is currently blocked on the local machine because MySQL is not listening on `127.0.0.1:3306`.
- No production migration, remote file edit, service restart, or destructive probe has been run.

## Resolved Decisions
1. Complete backend source is on `ubuntu@42.194.218.158`.
2. Groups created by a purged user are physically deleted.
3. Group messages sent by a purged user are physically deleted.
4. All messages belonging to groups created by a purged user are physically deleted.
5. User-owned MinIO objects are physically deleted as part of purge.
6. Future payment/order records are physically deleted as part of purge.
7. VIP first release is an MVP covering identity display, backend entitlement status, admin manual grant/revoke/expiry, and core permission gates.
8. First-release VIP backend gates protect group creation, group member invitation, friend adding, and system/management-tool entry.
9. Customer-service staff assignment is managed independently from VIP.

## VIP MVP Scope
The first VIP release should not try to ship every possible commercial benefit. Ship a small contract that is hard to misuse and easy to extend:

1. VIP identity:
   - VIP level/status fields returned in user profile/status APIs.
   - Client displays VIP badge/state where the existing UI already has VIP affordances.
2. Admin operations:
   - Create/enable/disable basic VIP plans.
   - Manually grant VIP to a user by UID or phone.
   - Manually revoke VIP.
   - Manually set or adjust expiry time.
3. Backend gates:
   - Add a reusable entitlement check function.
   - Gate group creation on the backend.
   - Gate group member invitation on the backend.
   - Gate friend adding on the backend.
   - Gate system/management-tool entry on the backend.
   - Client checks are only UX hints.
4. Expiry:
   - Expired VIP loses protected capabilities.
   - Expiry is test-covered and visible in admin.
5. Audit:
   - Every VIP grant, revoke, expiry adjustment, and plan change writes an audit log.

Deferred after MVP:
- Payment integration.
- VIP pricing/order lifecycle.
- Robot quota billing.
- Complex capacity tiers.
- Automated renewal.
- Marketing/member-center polish beyond the existing VIP badge and state display.

## Customer-Service Staff Scope
Customer-service assignment lets administrators designate normal users as official customer-service staff without making them VIP.

1. Admin operations:
   - Search user by UID or phone.
   - Assign user as customer-service staff.
   - Remove customer-service staff status.
   - Enable or disable a staff member without deleting the user.
   - Adjust display order.
2. Client behavior:
   - Customer-service entry reads enabled staff from `GET /v1/user/customerservices`.
   - Disabled or purged staff must not appear in the client list.
3. Backend rules:
   - Deleted, disabled, or banned users cannot be assigned as active customer-service staff.
   - Purging a user also removes that user from customer-service staff tables.
   - Staff assignment requires admin permission and an audit reason.
4. Audit:
   - Assignment, removal, enable/disable, and reorder operations write audit logs.

## Open Questions
None for this slice. Further VIP benefits can be specified after the MVP contract is implemented and verified.
