# Spec: Group Mute With Webhook Robot Exceptions

## Objective
Add a complete group-wide mute feature for merchant-created groups. Group owners and administrators can enable or disable full-group mute. When enabled, only the group owner, group administrators, and configured Feishu/DingTalk group webhook robot messages may send messages. Normal members must be blocked by the backend even if they use an old client or call the API directly.

Acceptance criteria:
- Group owner and administrators can toggle full-group mute for a group.
- Normal members cannot toggle full-group mute.
- When full-group mute is enabled, normal members cannot send text, image, file, voice, sticker, rich text, or other message payloads through `/v1/message/send`.
- Group owner and administrators can still send messages while full-group mute is enabled.
- Feishu and DingTalk group webhook robot messages can still enter the group while full-group mute is enabled.
- Monitor-forwarded robot messages from Feishu, Mengxia, Juliang, and similar configured monitor forwarding modules can still enter muted groups when they are emitted by trusted backend monitor/robot delivery paths.
- Other robot-looking accounts, including generic `robot=1` users or generic robot API senders, are not automatically allowed by this rule.
- Frontend hides or disables the mute management control for normal members and disables the composer for muted normal members with a clear message.
- Normal members cannot start group audio or video calls while full-group mute is enabled.

## Tech Stack
- Flutter/Dart client for Windows, Web, and Android.
- Go backend in the TangSengDaoDaoServer production source tree.
- WuKongIM SDK and backend message delivery APIs.
- MySQL-backed group, group member, and robot configuration tables.

## Commands
Local Flutter verification:
```powershell
flutter test test/modules/group
flutter test test/modules/chat
flutter test test/service
```

Remote Go verification:
```bash
cd /opt/wukongim-prod/src
go test ./modules/group ./modules/message ./modules/robot -run 'Test.*Forbidden|Test.*GroupMute|Test.*Robot' -v
go test ./modules/group ./modules/message ./modules/robot -run '^$'
```

Production smoke after backend publish:
```bash
cd /opt/wukongim-prod/src/deploy/production
python3 scripts/smoke_test.py --base-url https://infoequity.cn --timeout 10
curl -sk -w '\nhttp_code=%{http_code}\n' https://infoequity.cn/v1/ping
```

## Project Structure
- `docs/specs/group-mute-webhook-robot-permissions.md` stores this specification.
- Remote backend:
  - `modules/group` owns group setting updates, group roles, full-group mute state, and IM whitelist synchronization.
  - `modules/message` owns `/v1/message/send` and must perform backend send-time permission checks.
- `modules/robot` owns Feishu/DingTalk group webhook ingestion and should mark or route trusted webhook robot sends explicitly.
- `modules/monitor` and related monitor forwarding paths own observed/forwarded robot-style messages and should be included only when the message is emitted by a trusted backend forwarding path.
- Local Flutter:
  - `lib/service/api/group_api.dart` already contains full-group mute and member mute API calls.
  - `lib/data/models/group.dart` already carries group role, `forbidden`, and `forbidden_expir_time`.
  - `lib/wukong_uikit/group/group_detail_page.dart` is the main group management surface.
  - `lib/modules/chat/panes/chat_composer_pane.dart` is the main composer surface to disable for muted normal members.

## Code Style
Prefer explicit policy helpers over scattered conditionals:

```go
func canSendToMutedGroup(member *group.MemberResp, payload map[string]interface{}) bool {
    if member == nil {
        return false
    }
    if member.Role == group.MemberRoleCreator || member.Role == group.MemberRoleManager {
        return true
    }
    return isTrustedGroupWebhookRobotPayload(payload)
}
```

In Flutter, keep UI checks readable and role-oriented:

```dart
final canManageGroupMute = member?.isOwner == true || member?.isAdmin == true;
final isMutedNormalMember = group.forbidden == 1 && !canManageGroupMute;
```

## Testing Strategy
- Backend tests first:
  - Full-group mute blocks normal members at `/v1/message/send`.
  - Full-group mute allows owner and administrator.
  - Full-group mute allows Feishu/DingTalk group webhook paths.
  - Full-group mute allows trusted monitor forwarding paths for Feishu, Mengxia, Juliang, and future configured monitor providers that use the same backend-trusted forwarding mechanism.
  - Full-group mute does not allow generic `robot=1` users unless the message came through the configured Feishu/DingTalk webhook route.
  - Administrator add/remove refreshes mute whitelist or send-time policy immediately.
- Flutter tests:
  - Group detail shows mute control for owner/admin.
  - Group detail hides or disables mute control for normal members.
  - Chat composer disables send actions for muted normal members and displays the expected reason.
  - Group call entry blocks muted normal members.
  - Owner/admin composer stays enabled in muted groups.
- Manual/runtime verification:
  - Enable mute as group owner.
  - Try sending as normal member: blocked with clear error.
  - Send from owner/admin: succeeds.
  - Send through configured Feishu/DingTalk group webhook: succeeds.
  - Send through configured monitor forwarding route: succeeds.
  - Try group voice/video as normal member: blocked.

## Boundaries
- Always:
  - Enforce send permission on the backend.
  - Keep frontend checks as UX only, not the source of truth.
  - Preserve existing single-member mute behavior.
  - Preserve VIP group-disable behavior already added.
  - Treat generic robots and webhook robots as different trust levels.
- Ask first:
  - Adding new database columns.
  - Changing WuKongIM core service behavior outside TangSengDaoDaoServer modules.
  - Restarting MySQL, Redis, WuKongIM, or other non-backend infrastructure.
  - Publishing/restarting production after code changes.
- Never:
  - Allow old clients to bypass group mute.
  - Allow all `robot=1` accounts to bypass full-group mute.
  - Store or log webhook secrets in plaintext.
  - Revert unrelated local changes.

## Success Criteria
- The backend is authoritative: normal members cannot send to muted groups from any client path covered by this app's message APIs.
- Group owner/admin role checks are consistent in backend and frontend.
- Only Feishu/DingTalk group webhook robot delivery paths bypass full-group mute as robot exceptions.
- Feishu/DingTalk group webhook robot delivery paths and configured monitor forwarding delivery paths bypass full-group mute as trusted backend robot exceptions.
- UI reflects the group mute state without relying on UI-only enforcement.
- Tests cover allow and deny cases before implementation is considered complete.
