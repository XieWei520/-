# WuKongIM UI redesign handoff

Last updated: 2026-05-01

This document summarizes the UI redesign work already completed and the remaining work needed to finish the Web, Windows desktop, and Android interface refresh.

## Project context

- App: Flutter IM client for Web, Windows desktop, and Android.
- Design direction approved by product owner:
  - Warm off-white page background: `#FFFAF5`.
  - Graphite text, orange primary action, teal online state.
  - Web/Windows: four-zone workspace with brand rail, conversation list, chat pane, and optional right workbench.
  - Android: single-column mobile layout with compact controls and bottom composer.
  - Shared semantic tokens and adaptive layout rules across platforms.
- Figma preview file:
  - `https://www.figma.com/design/5ca3ZbEbwsUkYRQuUHngFE/WuKongIM--Copy-?node-id=2005-3&t=n2YZfNYoOoANogLc-0`
- Local preview artifacts were removed from the repository cleanup pass.
  Regenerate them under `output/ui-preview/` if a future visual QA pass needs
  local static previews.

## Current status

The redesign is not fully complete across every page yet.

Completed so far:

- Figma/static preview was created and approved.
- Phase 1 adaptive UI foundation was implemented.
- Phase 2 was started and partially implemented for Contacts, User/Profile, and Workplace catalog surfaces.
- Core chat workspace, tab rail, auth button, composer, and text message bubble adaptive behavior have targeted test coverage.

Still pending:

- Full UI pass across all secondary pages and all rich message types.
- Full Web/Windows/Android visual QA.
- Full repository analyzer/test cleanup.
- Final build verification for Web, Windows, and Android.

## Completed work

### 1. Design preview

Created the approved redesign preview for the IM product:

- Web/Windows layout:
  - Left brand rail.
  - Conversation list.
  - Main chat pane.
  - Optional right conversation workbench for wider screens.
- Android layout:
  - Single-column screen.
  - Bottom tab pattern.
  - Bottom message composer.
- Visual language:
  - Warm page surface.
  - White panels with warm borders.
  - Restrained radius.
  - Orange action color.
  - Teal online status.

### 2. Shared Web UI tokens

Updated `lib/widgets/wk_web_ui_tokens.dart`:

- `WKWebRadius.panel = WKRadius.md`.
- Desktop rail width set to `72`.
- Conversation list width set to `350`, minimum `260`.
- Right context width set to `304`.
- Chat pane minimum width set to `420`.
- Message bubble sizing constants added/adjusted:
  - `messageBubbleMinWidth`
  - `messageBubbleMaxWidth`
  - `messageBubbleRobotMaxWidth`
  - `messageBubbleWidthRatio`

Associated tests:

- `test/widgets/wk_web_ui_tokens_test.dart`

### 3. Web/Windows navigation rail

Updated `lib/widgets/wk_tab_shell.dart`:

- Desktop rail width now follows the approved `72px` token.
- Brand mark and rail buttons use stable square sizing.
- Removed negative letter spacing.
- Rail layout is less likely to shift under hover/selection states.

Associated tests:

- `test/widgets/wk_tab_shell_web_test.dart`

### 4. Conversation workspace adaptive layout

Updated `lib/modules/conversation/web_conversation_workspace.dart`:

- Conversation list width adapts inside available desktop width.
- Right context panel hides when the viewport is too narrow.
- Chat area keeps a minimum usable width.
- Layout avoids squeezing the chat pane into an unreadable state.

Associated tests:

- `test/modules/conversation/web_conversation_workspace_test.dart`

### 5. Message bubble adaptive sizing

Updated `lib/widgets/message_bubble.dart`:

- Text message bubbles now size from the message lane constraints instead of stretching against the whole window.
- Bubble width is capped by shared Web tokens.
- Robot bubble max width is capped separately.
- Long names/group labels keep zero letter spacing.
- This improves Web/Windows desktop chat and Android narrow-screen behavior.

Associated tests:

- `test/modules/chat/message_bubble_experience_test.dart`

Remaining message-bubble work:

- Apply the same audit to non-text message bubbles:
  - image
  - video
  - voice
  - file
  - location
  - card/business messages
  - reply/quote messages
  - system messages
  - robot or custom extension messages

### 6. Auth action button overflow protection

Updated `lib/modules/auth/presentation/widgets/auth_action_button.dart`:

- Long button labels now scale down safely inside the button.
- Prevents button text overflow in narrow layouts and translated strings.

Associated tests:

- `test/modules/auth/auth_page_scaffold_test.dart`

### 7. Chat composer compact action row

Updated `lib/modules/chat/chat_page_shell.dart`:

- Composer action row uses `LayoutBuilder`.
- Below narrow thresholds, action buttons/icons/gaps compact automatically.
- Reduces Android and narrow desktop composer overflow risk.

Associated existing Android parity tests were run for composer/call action behavior.

### 8. Contacts Web frame

Updated `lib/modules/contacts/contacts_page.dart`:

- Forced Web frame now centers the Contacts surface.
- Adds a bounded `WKWebPanel` with max width `920`.
- Adds key `contacts-web-panel` for future UI tests.

Associated tests:

- `test/modules/contacts/contacts_page_parity_test.dart`
  - Updated warm Web frame test to assert panel max width and surface color.

### 9. User/Profile header redesign

Updated `lib/modules/user/user_page.dart`:

- Replaced the old full background image header with an approved warm adaptive profile card.
- Added:
  - `user-profile-card`
  - `user-profile-accent`
- QR button is now inside a bounded warm control shell.
- Avatar size adapts for narrow widths.
- Name and badges continue to wrap/truncate safely.

Associated tests:

- `test/modules/user/user_page_parity_test.dart`
  - Added test for the approved warm adaptive profile card.

### 10. Workplace app tile adaptive actions

Updated `lib/modules/workplace/workplace_catalog_page.dart`:

- Replaced `ListTile.trailing` action cluster with a custom adaptive layout.
- Wide screens use a row layout.
- Narrow screens move actions below the title/subtitle content.
- Action group gets key `workplace-app-actions-<appId>`.
- Action labels are constrained and ellipsized.
- Reorder icon buttons are preserved for added apps.

Associated tests:

- `test/modules/workplace/workplace_catalog_page_test.dart`
  - Added narrow mobile layout test to ensure actions stay within the tile.

## Verification already performed

### Passed before Phase 2

The following command passed with 98 tests:

```powershell
flutter test test/widgets/wk_web_ui_tokens_test.dart test/widgets/wk_tab_shell_web_test.dart test/widgets/wk_conversation_item_parity_test.dart test/modules/conversation/web_conversation_workspace_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/auth/auth_page_scaffold_test.dart
```

The following Android chat parity subset passed with 3 tests:

```powershell
flutter test test/modules/chat/chat_page_android_parity_test.dart --name "personal chat places call actions|chat composer toolbar action artwork|chat composer keeps Android input row"
```

Targeted analyzer over the Phase 1 changed UI files/tests reported no issues.

Full `flutter analyze` was not clean because of existing unrelated issues. One known blocker:

- `test/modules/settings/support/live_backup_restore_acceptance_harness.dart:33:43`
- Return type mismatch around `Directory` vs `Future<UnsupportedBackupDirectory>`.

### Phase 2 red/green verification

These new Phase 2 tests were first run and failed for the expected missing behavior:

- Missing `user-profile-card`.
- Missing `contacts-web-panel`.
- Missing `workplace-app-actions-collaboration-suite`.

After implementation, the same targeted command passed with 3 tests:

```powershell
flutter test test/modules/user/user_page_parity_test.dart test/modules/contacts/contacts_page_parity_test.dart test/modules/workplace/workplace_catalog_page_test.dart --name "user web profile header uses approved warm adaptive card|contacts page can render inside warm Web frame|workplace app tile keeps actions within a narrow mobile layout"
```

### Full page test files are not clean yet

Running the full three page test files currently fails due to existing test/data issues outside the new Phase 2 assertions:

```powershell
flutter test test/modules/user/user_page_parity_test.dart test/modules/contacts/contacts_page_parity_test.dart test/modules/workplace/workplace_catalog_page_test.dart
```

Observed failures:

- `UserPage renders ordered production rows...`
  - Test expects text `Me`; current rendered/localized text did not match.
- `contacts page uses Android default header entries`
  - Test expects text `Contacts`; current rendered/localized text did not match.
- `contacts page shows vip badge beside vip contact name`
  - Leaves a pending timer from `WKAvatar` network loading.
- `contacts page blocks non vip add-friend and create-group menu entries`
  - Test expects English menu labels such as `Add friend`; current rendered/localized labels did not match.

Recommendation: fix these tests separately from the UI redesign pass, because they appear to be localization/test-harness issues rather than direct regressions from the new adaptive UI code.

## Current working tree notes

Run this before continuing:

```powershell
git status --short
```

Important: there are unrelated dirty files in the working tree. Do not revert or mix them into the UI redesign commit without checking ownership.

Known unrelated dirty areas:

- `.playwright-cli/page-2026-04-30T15-46-40-958Z.yml`
- `lib/realtime/session/session_socket_auth.dart`
- `lib/realtime/session/session_socket_connector_io.dart`
- `lib/realtime/session/session_socket_connector_stub.dart`
- `lib/service/api/message_api.dart`
- `lib/service/im/im_service.dart`
- `lib/wukong_push/notification/web_notification_manager_web.dart`
- `test/realtime/session/session_socket_auth_test.dart`
- `test/service/api/message_api_test.dart`
- `test/service/im/im_service_web_policy_test.dart`
- `test/wukong_push/web_notification_integration_policy_test.dart`

UI-related changed files from this redesign pass include:

- `lib/widgets/wk_web_ui_tokens.dart`
- `lib/widgets/wk_tab_shell.dart`
- `lib/modules/conversation/web_conversation_workspace.dart`
- `lib/widgets/message_bubble.dart`
- `lib/modules/auth/presentation/widgets/auth_action_button.dart`
- `lib/modules/chat/chat_page_shell.dart`
- `lib/modules/contacts/contacts_page.dart`
- `lib/modules/user/user_page.dart`
- `lib/modules/workplace/workplace_catalog_page.dart`
- `test/widgets/wk_web_ui_tokens_test.dart`
- `test/widgets/wk_tab_shell_web_test.dart`
- `test/modules/conversation/web_conversation_workspace_test.dart`
- `test/modules/chat/message_bubble_experience_test.dart`
- `test/modules/auth/auth_page_scaffold_test.dart`
- `test/modules/contacts/contacts_page_parity_test.dart`
- `test/modules/user/user_page_parity_test.dart`
- `test/modules/workplace/workplace_catalog_page_test.dart`
- `output/ui-preview/*`

Some UI files have staged changes and some have unstaged changes. Check both `git diff --cached` and `git diff` before committing.

## Local preview server

The earlier local Flutter web preview server and its logs were stopped and
removed during cleanup. Start a fresh preview server before relying on local
visual QA URLs.

## Remaining work

### 1. Finish page inventory

Create a full route/page inventory before continuing broad UI changes. Suggested groups:

- Auth/login/register/forgot password.
- Home shell and tabs.
- Conversation list.
- Chat page and all message cells.
- Contacts directory.
- User profile and personal center.
- Settings pages.
- Notification/privacy/account security pages.
- Favorites.
- Search.
- Add friend/create group/group detail.
- Tag management.
- Moments.
- VIP pages.
- QR code/profile detail pages.
- Workplace/catalog/app modules.
- Any plugin/slot-provided pages.

### 2. Apply adaptive layout rules everywhere

For every screen/component:

- Replace fragile fixed widths/heights with `LayoutBuilder`, `Expanded`, `Flexible`, `ConstrainedBox`, `Wrap`, or scroll containers.
- Keep every button/action cluster inside bounded constraints.
- Long labels must use ellipsis, wrapping, or `FittedBox` depending on context.
- Cards/panels must not overflow at 320px Android width.
- Web/Windows panels should use shared warm tokens and max-width rules where appropriate.
- Text should not use negative letter spacing.
- Avoid nested cards unless the component is genuinely a repeated item, modal, or framed tool.

### 3. Complete message bubble audit

Text bubbles have been improved, but rich message cells still need a full pass:

- Image messages should cap decode/render width and adapt to lane width.
- Video/file/location cards should use responsive max width and not overflow at 320px.
- Voice message rows should handle long durations/translations.
- Reply/quote previews should not force bubble overflow.
- System messages should stay centered and wrap safely.
- Custom/robot cards should use the robot max-width token.

### 4. Complete Web/Windows responsive QA

Test at minimum:

- 1024 x 768
- 1280 x 800
- 1440 x 900
- 1920 x 1080

Check:

- Rail width and icon alignment.
- Conversation list width.
- Chat pane minimum width.
- Right context hide/show behavior.
- Composer actions and send button.
- Long conversation names.
- Long group/user names.
- Empty/loading/error states.

### 5. Complete Android responsive QA

Test at minimum:

- 320 x 568
- 360 x 740
- 390 x 844
- 430 x 932
- Text scale 1.0, 1.3, 1.8.

Check:

- Auth buttons and inputs.
- Bottom tabs.
- Chat composer with keyboard open.
- Message bubbles.
- Contacts rows and alphabet index.
- User profile header.
- Workplace action buttons.
- Settings rows with long labels.

### 6. Stabilize tests

Recommended next test work:

- Fix localization-sensitive expectations in `user_page_parity_test.dart` and `contacts_page_parity_test.dart`.
- Mock or disable network avatar loading in the VIP contact test to avoid pending timers.
- Add targeted tests for every high-risk responsive surface.
- Add tests for rich message bubble width caps.
- Add at least one Web/Windows workspace test around 1024px and 1280px breakpoints.
- Add at least one Android narrow-width test per top-level tab.

### 7. Run final verification

Before calling the redesign complete, run:

```powershell
dart format .
flutter test
flutter analyze
flutter build web
flutter build windows
flutter build apk --debug
```

If full `flutter test` is too large, run the UI-related suites first, then expand:

```powershell
flutter test test/widgets test/modules/auth test/modules/chat test/modules/conversation test/modules/contacts test/modules/user test/modules/workplace
```

Also perform manual visual QA on Web/Windows/Android after builds succeed.

### 8. Recommended commit strategy

Keep commits separated:

1. Design preview documentation.
2. Shared tokens and Web/Windows shell.
3. Chat workspace, composer, and message bubbles.
4. Auth and top-level page adaptive fixes.
5. Remaining page-by-page UI pass.
6. Test harness cleanup.

Do not include unrelated realtime/session/push/service changes in the UI commits unless their owner confirms they belong.

## Suggested next developer starting point

1. Run `git status --short`.
2. Review `git diff --cached` and `git diff`.
3. Restart the Flutter web server for a fresh visual preview.
4. Fix the existing full page test failures listed above.
5. Continue the UI inventory from the remaining work section.
6. Expand adaptive tests before each new page-level UI change.
