# Spec: Feishu Global Robot Config And Monitor Status

## Assumptions
1. The requested "机器人配置" is a new management-system entry for global Feishu open-platform credentials, not another per-group robot page.
2. Feishu App ID and App Secret should be configured once and reused by group Feishu robot flows; per-group pages should keep only group-specific webhook, signing, identity, and enablement controls.
3. The user confirmed Feishu App ID/App Secret should be persisted locally on this desktop client, not shared through the backend.
4. The user confirmed the management-system status text "第一阶段", "PoC 可用", and "无痕文本" should be unified to "正常".

## Objective
Add a centralized Feishu robot credential configuration surface under the management system so operators do not have to look for App ID and App Secret inside each group. Clarify the management-system service list by making the status labels reflect current phase and capability consistently.

Acceptance criteria:
- The management system page includes a visible "机器人配置" entry.
- The robot configuration page lets an operator enter and save Feishu App ID and App Secret once.
- App Secret is masked on screen by default and is not shown in management list badges or logs.
- Group Feishu robot configuration no longer presents App ID/App Secret as group-level settings.
- Management system badges for the live monitor entries show "正常" instead of phase/capability labels such as "第一阶段", "PoC 可用", or "无痕文本".

## Tech Stack
Flutter / Dart, existing `WKSubPageScaffold`, Material widgets, and repository-local tests. Use existing storage/API patterns from the current codebase.

## Commands
- Analyze: `flutter analyze`
- Focused tests: `flutter test test/modules/vip/vip_management_page_test.dart test/modules/robot_config/feishu_robot_credentials_page_test.dart test/modules/robot_config/feishu_robot_credentials_store_test.dart test/wukong_uikit/group/group_feishu_bot_page_test.dart`

## Project Structure
- `lib/modules/vip/vip_management_page.dart` -> management-system entry list and status labels.
- `lib/modules/robot_config/` -> global robot config page and local persistence adapter.
- `lib/wukong_uikit/group/group_feishu_bot_page.dart` -> per-group Feishu robot settings; should reference global credentials only as status/help text if needed.
- `lib/data/models/group_feishu_robot_config.dart` and `lib/service/api/group_api.dart` -> existing per-group model/API; do not expand group-level credential payloads without backend confirmation.
- `test/modules/vip/` and a new focused test file for global robot config UI/persistence.

## Code Style
Follow the existing compact settings-page style:

```dart
_ManagementCenterCard(
  key: const ValueKey('management-center-robot-config'),
  title: '机器人配置',
  description: '统一配置飞书 App ID 与 App Secret',
  status: '本机配置',
  icon: Icons.smart_toy_outlined,
  enabled: true,
  onTap: () => _openRobotConfig(context),
)
```

Keep form state local to the page. Use existing settings cells, spacing tokens, and Chinese labels. Do not add a new dependency for secure storage unless there is already an accepted storage wrapper in the project.

## Testing Strategy
Use widget tests for:
- The management page renders the new "机器人配置" entry and "正常" status labels.
- Tapping the entry opens the robot config page.
- The robot config form masks App Secret by default and persists entered values through the selected store abstraction.

Use model/store unit tests if persistence logic is introduced outside the widget.

## Boundaries
- Always: keep App Secret masked by default, validate non-empty App ID before save, and preserve existing per-group robot save/test/regenerate/delete behavior.
- Ask first: adding backend endpoints, adding dependencies, changing database schema, or changing Feishu protocol behavior.
- Never: commit real App Secret values, log App Secret, delete unrelated dirty worktree changes, or remove existing group robot features.

## Success Criteria
- A manager can open 管理系统 -> 机器人配置 and save Feishu App ID/App Secret locally on the current desktop client.
- A manager can still open a group Feishu robot page and manage only group-specific robot behavior.
- The management system page displays "正常" for entries that previously showed first-stage PoC or incognito text labels.
- Focused widget tests pass and `flutter analyze` reports no new issues from touched files.

## Open Questions
None.
