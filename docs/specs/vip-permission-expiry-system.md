# Spec: VIP Merchant Permission and Expiry System

## Objective
Build a VIP merchant entitlement system for the IM product.

VIP merchants can use commercial capabilities: add friends, create groups, invite group members, and enter the system management tools. When VIP expires, the account must lose those capabilities and all groups created by that merchant must be disabled so they cannot be used until VIP is restored.

Success means the client shows correct VIP/expired state, but the backend remains the source of truth and rejects restricted operations even if the client is bypassed.

## Tech Stack
- Client: Flutter, Dart 3.11, Riverpod, GoRouter.
- Backend: TangSengDaoDaoServer Go service running on `ubuntu@42.194.218.158:/opt/wukongim-prod/src`.
- Database: MySQL 8 via embedded SQL migrations under backend `modules/*/sql`.
- IM channel state: WuKongIM channel info, using group `ban` when a VIP-created group is disabled.

## Commands
Client:
- Get dependencies: `flutter pub get`
- Analyze: `flutter analyze`
- Test VIP client slice: `flutter test test/data/models/user_info_model_test.dart test/modules/vip/vip_guard_test.dart`

Backend:
- Test user VIP slice: `go test ./modules/user`
- Test group VIP slice: `go test ./modules/group`
- Build backend: `go build -o /tmp/tsdd-vip-check .`

Deployment:
- Do not redeploy production containers until code and migrations are verified.
- Existing deploy helper: `powershell -File scripts/ops/deploy_backend_remote.ps1`

## Project Structure
Client:
- `lib/data/models/user.dart` - current user VIP fields and entitlement helpers.
- `lib/modules/vip/` - VIP badges, guard dialog, and management entry gating.
- `lib/modules/contacts/`, `lib/modules/conversation/`, `lib/wukong_uikit/` - UI entry points that call VIP guard.
- `test/modules/vip/` and `test/data/models/` - client regression tests.

Backend:
- `modules/user/vip_runtime.go` - VIP expiry middleware and reminders.
- `modules/user/vip_const.go` - entitlement constants.
- `modules/user/db.go` - user VIP fields and updates.
- `modules/user/api_friend.go` - add-friend backend enforcement.
- `modules/group/api.go` - group create/member operations and group access enforcement.
- `modules/group/db.go` - group ownership/status updates.
- `modules/user/sql/` and `modules/group/sql/` - migrations.

## Code Style
Use explicit entitlement names instead of scattered `vipLevel == 1` checks.

```dart
final user = authState.userInfo;
if (user?.canCreateGroup != true) {
  await showVipRequiredDialog(context, entitlement: VipEntitlement.createGroup);
  return;
}
```

```go
if err := user.RequireVIPEntitlement(loginUser, user.VIPEntitlementCreateGroup); err != nil {
    c.ResponseError(err)
    return
}
```

Keep the server-side permission functions small, deterministic, and easy to test.

## Testing Strategy
- Client model tests cover VIP active, expired, no-expiry, and entitlement serialization.
- Client guard tests cover allowed VIP, expired VIP rejection, and customer-service fallback.
- Backend unit/API tests cover:
  - non-VIP cannot add friends;
  - expired VIP is downgraded;
  - non-VIP cannot create groups;
  - expired VIP creator groups are disabled;
  - disabled VIP groups reject member add/invite and group use paths.
- Prefer focused package tests first, then broader build verification.

## Boundaries
- Always:
  - Enforce VIP permissions on backend protected endpoints.
  - Keep historical friends, group records, and chat records.
  - Disable VIP-created groups on expiry using group status + IM channel ban.
  - Return explicit VIP fields to the client.
  - Preserve unrelated local changes already present in the Flutter worktree.
- Ask first:
  - Running production deployment/restarting containers.
  - Adding payment/order tables.
  - Deleting existing groups, friends, or messages.
  - Changing public API route names.
- Never:
  - Trust client-side VIP checks as authorization.
  - Delete user assets on VIP expiry.
  - Store production secrets in the repo.
  - Treat platform customer-service identity as purchasable VIP.

## Success Criteria
- User model exposes `vip_level`, `vip_expire_time`, `vip_status`, and entitlement booleans.
- Backend rejects add-friend and group-creation requests from non-VIP or expired VIP accounts.
- Backend disables groups where `group.creator` is the expired VIP merchant.
- Disabled VIP-created groups cannot be opened for normal use, modified, invited into, or have new members added.
- Restoring VIP can re-enable that merchant's disabled groups.
- Tests prove the behavior on both client and backend slices.

## Open Questions
- Whether expired groups should be automatically re-enabled immediately when VIP is renewed. Current implementation target: yes, re-enable groups created by the merchant when VIP is set active again.
- Whether ordinary group members should still be able to read historical messages in disabled VIP-created groups. Current target: no active group use from API; historical local cache is not deleted.
