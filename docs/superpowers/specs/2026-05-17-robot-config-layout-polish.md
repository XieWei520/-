# Spec: Robot Config Layout Polish

## Objective
Improve the DingTalk and Feishu robot configuration pages so desktop layouts read left-to-right instead of placing controls near the visual center, and reduce dense explanatory copy in the robot setup flow.

Acceptance criteria:
- Settings row arrows, switches, and custom trailing controls align to the right edge of the row on wide desktop windows.
- Feishu and DingTalk robot pages use clearer sections for identity, access mode, credentials, and actions.
- Robot configuration copy is short enough to scan; long protocol explanations are removed from the main form.
- Existing robot config save, test, regenerate, delete, avatar upload, and official webhook payload behavior stays unchanged.

## Tech Stack
Flutter 3 / Dart, Material widgets, existing `WKSubPageScaffold` and `WKSettingsCell` components.

## Commands
- Analyze: `flutter analyze`
- Focused tests: `flutter test test\widgets\wk_settings_cell_overflow_test.dart test\wukong_uikit\group\group_feishu_bot_page_test.dart test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`

## Project Structure
- `lib/widgets/wk_sub_page_scaffold.dart` -> shared settings list rows.
- `lib/wukong_uikit/group/group_feishu_bot_page.dart` -> Feishu robot page.
- `lib/wukong_uikit/group/group_dingtalk_bot_page.dart` -> DingTalk robot page.
- `lib/wukong_uikit/group/group_robot_identity_section.dart` -> shared IM display identity section.
- `lib/wukong_uikit/group/group_robot_webhook_mode_section.dart` -> shared webhook mode section.
- `test/widgets/` and `test/wukong_uikit/group/` -> regression coverage.

## Code Style
Prefer compact, explicit widgets that follow the existing settings page style:

```dart
WKSettingsCell(
  title: '保存当前配置',
  onTap: _isSaving ? null : _saveConfig,
)
```

Keep state and API behavior in the existing page state classes. Use existing color tokens and spacing rather than introducing a new design system.

## Testing Strategy
Use widget tests for layout regressions and existing payload tests for behavior. Add a regression test proving settings row trailing controls stay pinned to the right edge on wide screens.

## Boundaries
- Always: preserve existing API payload fields and validation rules.
- Ask first: adding dependencies, changing backend endpoints, changing robot protocol behavior.
- Never: remove save/test/regenerate/delete flows, commit secrets, or alter unrelated dirty worktree changes.

## Success Criteria
- The focused widget tests pass.
- `flutter analyze` has no new issues from touched files.
- The updated pages render compact Chinese UI labels for Feishu and DingTalk robot configuration.

## Open Questions
None for this pass; screenshots make the main layout issue clear.
