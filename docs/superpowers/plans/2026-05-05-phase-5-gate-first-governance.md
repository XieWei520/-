# Phase 5 Gate-First Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Phase 5 quality governance enforceable by clearing all current `flutter analyze` issues, adding CI analyze gating, and documenting production release preflight checks before further UX polish.

**Architecture:** This plan treats the analyzer as the first production quality gate. It first stabilizes the unfinished Phase 3 Web cache files so the project compiles, then removes warnings/info with minimal safe edits, then enforces the same gate in GitHub Actions and release documentation. Motion/Jank work remains a follow-up backlog item rather than a code expansion in this batch.

**Tech Stack:** Flutter/Dart 3.11, Flutter analyzer/lints, flutter_test, GitHub Actions YAML, PowerShell/ops runbooks, Web IndexedDB via `dart:js_interop` and `package:web`.

---

## File Structure

### Cache and IndexedDB stabilization

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`
  - Responsibility: in-memory fallback implementation for `WebChatCacheStore`, including user/channel partitioning, dedupe, pagination, and `WKMsg` record normalization.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store_adapter_web.dart`
  - Responsibility: Web-only IndexedDB adapter and JS interop conversion.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store_adapter_io.dart`
  - Responsibility: non-Web adapter stub that fails fast and allows `IndexedDbWebChatCacheStore` to fall back to memory.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store.dart`
  - Responsibility: platform-independent cache store using adapter persistence with memory fallback.
- Test: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\web_chat_cache_store_contract_test.dart`
  - Responsibility: memory fallback contract tests.
- Test: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\indexed_db_web_chat_cache_store_test.dart`
  - Responsibility: IndexedDB store behavior with fake adapters.

### Analyzer cleanup across existing files

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\platform\local_file_picker.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\auth\presentation\widgets\auth_status_banner.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_file_picker.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_media_action_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\robot_card_message.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_press_hold_button.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_record_overlay.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\favorites\favorite_record.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\settings\notification_channel_settings_bridge.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\device_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_robot\robot_exports.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_robot\robot_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\group\all_members_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\uikit_exports.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\views\line_wave_voice_view.dart`
- Modify test files reported by analyzer under `C:\Users\COLORFUL\Desktop\WuKong\test\...`
  - Responsibility: remove unused imports, rename local helpers without leading underscores, fix `unnecessary_underscores`, and remove invalid `override` annotations.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\local_packages\firebase_core_windowsless\example\lib\main.dart`
  - Responsibility: small example constructor lint cleanup.

### CI and production governance

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.github\workflows\flutter-android-ci.yml`
  - Responsibility: add PR trigger and fail-fast `flutter analyze` step before tests/build.
- Create: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\phase-5-release-preflight.md`
  - Responsibility: document required compose, Nginx, smoke, health/log evidence checks.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\README.md`
  - Responsibility: link the Phase 5 release preflight runbook.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\docs\superpowers\specs\2026-05-05-phase-5-gate-first-governance-design.md`
  - Responsibility: approved design document; no implementation edits expected unless verification reveals ambiguity.

---

### Task 1: Stabilize Web cache analyzer errors

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store_adapter_web.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store_adapter_io.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\web_chat_cache_store_contract_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\indexed_db_web_chat_cache_store_test.dart`

- [ ] **Step 1: Run the cache tests and analyzer to capture current failures**

Run:

```powershell
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart
flutter analyze
```

Expected before fixes:

```text
flutter analyze reports undefined_getter toJS in indexed_db_web_chat_cache_store_adapter_web.dart
flutter analyze reports argument_type_not_assignable in web_chat_cache_store_memory.dart
```

- [ ] **Step 2: Fix memory cache `beforeOrderSeq` pagination return type**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`, replace the `beforeOrderSeq` branch in `readMessages` with this exact branch:

```dart
    if (beforeOrderSeq > 0) {
      final filtered = records
          .where((record) => _intValue(record, 'orderSeq') < beforeOrderSeq)
          .toList(growable: false);
      return _pageLatest(filtered, pageLimit)
          .map((record) => _messageFromRecord(record))
          .toList(growable: false);
    }
```

Then change `_pageLatest` in the same file to return records rather than messages:

```dart
  static List<Map<String, Object?>> _pageLatest(
    List<Map<String, Object?>> records,
    int limit,
  ) {
    if (records.length <= limit) {
      return records;
    }
    return records.sublist(records.length - limit);
  }
```

Also ensure the non-`beforeOrderSeq` final return remains:

```dart
    return _pageLatest(records, pageLimit)
        .map((record) => _messageFromRecord(record))
        .toList(growable: false);
```

- [ ] **Step 3: Fix Web IndexedDB JS conversion**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store_adapter_web.dart`, remove this unused import:

```dart
import 'dart:js_interop_unsafe';
```

Then replace this line:

```dart
    await _requestValue(store.put(payload.toJS, _recordKey.toJS));
```

with:

```dart
    await _requestValue(store.put(payload.jsify(), _recordKey.toJS));
```

Keep `dart:js_interop` imported because it provides `toJS`, `dartify`, and `jsify`.

- [ ] **Step 4: Fix non-null IndexedDB availability check**

In the same Web adapter, replace `_openDatabase` with:

```dart
  Future<web.IDBDatabase> _openDatabase() async {
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    }).toJS;
    return (await _requestValue(request)) as web.IDBDatabase;
  }
```

This removes the analyzer dead-code warning caused by `indexedDB == null` on the current `package:web` type.

- [ ] **Step 5: Format cache files**

Run:

```powershell
dart format lib/data/cache/web_chat_cache_store_memory.dart lib/data/cache/indexed_db_web_chat_cache_store_adapter_web.dart lib/data/cache/indexed_db_web_chat_cache_store_adapter_io.dart lib/data/cache/indexed_db_web_chat_cache_store.dart test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected:

```text
Formatted 6 files
```

The number may be lower if some files are already formatted.

- [ ] **Step 6: Verify cache tests pass**

Run:

```powershell
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 7: Verify cache analyzer errors are gone**

Run:

```powershell
flutter analyze lib/data/cache test/data/cache
```

Expected:

```text
No issues found!
```

If `flutter analyze lib/data/cache test/data/cache` does not support directory arguments in the local Flutter version, run full `flutter analyze` and confirm the previous cache error lines no longer appear.

---

### Task 2: Clear analyzer issues in application source

**Files:**
- Modify all application source files listed in the “Analyzer cleanup across existing files” section.

- [ ] **Step 1: Run full analyzer and save the current list**

Run:

```powershell
flutter analyze | Tee-Object -FilePath build\phase5-analyze-before.txt
```

Expected before this task:

```text
Analyzer issues remain outside lib/data/cache.
```

- [ ] **Step 2: Remove unnecessary Dart imports**

Apply these exact source edits:

```text
C:\Users\COLORFUL\Desktop\WuKong\lib\core\platform\local_file_picker.dart
- remove: import 'dart:typed_data';

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_file_picker.dart
- remove: import 'dart:typed_data';

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_media_action_service.dart
- remove: import 'dart:typed_data';

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\robot_card_message.dart
- remove: import 'package:wukongimfluttersdk/type/const.dart';

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_message_bubble.dart
- remove: import 'package:flutter/foundation.dart';
```

Reason: these types are already available through imported Flutter libraries or are unused.

- [ ] **Step 3: Replace deprecated `withOpacity` calls in application source**

Apply these replacements:

```text
C:\Users\COLORFUL\Desktop\WuKong\lib\modules\auth\presentation\widgets\auth_status_banner.dart
palette.foreground.withOpacity(0.84) -> palette.foreground.withValues(alpha: 0.84)
palette.foreground.withOpacity(0.74) -> palette.foreground.withValues(alpha: 0.74)

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_press_hold_button.dart
scheme.primary.withOpacity(0.8) -> scheme.primary.withValues(alpha: 0.8)
scheme.primaryContainer.withOpacity(0.72) -> scheme.primaryContainer.withValues(alpha: 0.72)

C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_record_overlay.dart
Colors.black.withOpacity(0.72) -> Colors.black.withValues(alpha: 0.72)

C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\views\line_wave_voice_view.dart
paintColor.withOpacity(alpha) -> paintColor.withValues(alpha: alpha)
```

If `chat_voice_record_overlay.dart` has a different alpha value than `0.72`, preserve the existing numeric value and only change the API to `withValues(alpha: existingValue)`.

- [ ] **Step 4: Replace deprecated text scaling APIs**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_voice_message_bubble.dart`, replace the `TextPainter` argument:

```dart
      textScaleFactor: MediaQuery.textScaleFactorOf(context),
```

with:

```dart
      textScaler: MediaQuery.textScalerOf(context),
```

- [ ] **Step 5: Remove unnecessary braces in favorite route interpolation**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\favorites\favorite_record.dart`, find the string interpolation reported around line 189. If it is:

```dart
'...${variable}...'
```

and the analyzer reports `unnecessary_brace_in_string_interps`, change only that interpolation to:

```dart
'...$variable...'
```

Do not change interpolations where removing braces would change parsing, such as `${value.property}` or `${value + 1}`.

- [ ] **Step 6: Make empty catch blocks explicit**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\settings\notification_channel_settings_bridge.dart`, replace:

```dart
      } on MissingPluginException {
      } on PlatformException {}
```

with:

```dart
      } on MissingPluginException {
        // Fall back to the app-level notification settings page below.
      } on PlatformException {
        // Fall back to the app-level notification settings page below.
      }
```

- [ ] **Step 7: Use null-aware map entry for device login logs**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\device_api.dart`, replace the query parameter entry:

```dart
        if (deviceId != null) 'device_id': deviceId,
```

with:

```dart
        if (deviceId case final resolvedDeviceId?)
          'device_id': resolvedDeviceId,
```

Keep the existing `'limit': limit` entry. This keeps the map value non-null and satisfies `use_null_aware_elements` without changing request semantics.

- [ ] **Step 8: Remove unnecessary library declarations**

Apply these deletions:

```text
C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_robot\robot_exports.dart
- remove line: library robot_exports;

C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\uikit_exports.dart
- remove line: library uikit_exports;
```

Keep the file-level documentation comments and exports.

- [ ] **Step 9: Prefer collection literals in robot service**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_robot\robot_service.dart`, replace unnecessary constructor calls reported by analyzer:

```dart
final deduped = LinkedHashMap<String, RobotSyncTarget>();
```

with:

```dart
final deduped = <String, RobotSyncTarget>{};
```

and replace:

```dart
final robotIds = LinkedHashSet<String>();
```

with:

```dart
final robotIds = <String>{};
```

If the file no longer uses `dart:collection` after these replacements, remove:

```dart
import 'dart:collection';
```

- [ ] **Step 10: Replace deprecated `WillPopScope` with `PopScope`**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\group\all_members_page.dart`, replace the build method wrapper:

```dart
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasChanges);
        return false;
      },
      child: WKSubPageScaffold(
```

with:

```dart
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_hasChanges);
      },
      child: WKSubPageScaffold(
```

Keep the existing `WKSubPageScaffold` body unchanged.

- [ ] **Step 11: Replace deprecated `RadioListTile` groupValue/onChanged usage**

In the same file, replace the `for` loop inside `_ForbiddenTimePickerState.build`:

```dart
          for (final option in widget.options)
            RadioListTile<int>(
              key: ValueKey<String>(
                'group-forbidden-time-option-${option.key}',
              ),
              value: option.key,
              groupValue: _selected?.key,
              title: Text(option.text),
              onChanged: (_) => setState(() => _selected = option),
            ),
```

with:

```dart
          RadioGroup<int>(
            groupValue: _selected?.key,
            onChanged: (value) {
              final selected = widget.options
                  .where((option) => option.key == value)
                  .firstOrNull;
              if (selected == null) {
                return;
              }
              setState(() => _selected = selected);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in widget.options)
                  RadioListTile<int>(
                    key: ValueKey<String>(
                      'group-forbidden-time-option-${option.key}',
                    ),
                    value: option.key,
                    title: Text(option.text),
                  ),
              ],
            ),
          ),
```

Dart 3.11 provides `Iterable.firstOrNull`; no extra package is needed.

- [ ] **Step 12: Format application source files**

Run:

```powershell
dart format lib/core/platform/local_file_picker.dart lib/modules/auth/presentation/widgets/auth_status_banner.dart lib/modules/chat/chat_file_picker.dart lib/modules/chat/chat_media_action_service.dart lib/modules/chat/robot_card_message.dart lib/modules/chat/widgets/chat_voice_message_bubble.dart lib/modules/chat/widgets/chat_voice_press_hold_button.dart lib/modules/chat/widgets/chat_voice_record_overlay.dart lib/modules/favorites/favorite_record.dart lib/modules/settings/notification_channel_settings_bridge.dart lib/service/api/device_api.dart lib/wukong_robot/robot_exports.dart lib/wukong_robot/robot_service.dart lib/wukong_uikit/group/all_members_page.dart lib/wukong_uikit/uikit_exports.dart lib/wukong_uikit/views/line_wave_voice_view.dart
```

Expected:

```text
Formatted ... files
```

- [ ] **Step 13: Run analyzer on lib**

Run:

```powershell
flutter analyze lib
```

Expected:

```text
No issues found!
```

If new issues appear because exact source context differs, fix them with the same minimal-safe rule and rerun this step.

---

### Task 3: Clear analyzer issues in tests and local package example

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\local_packages\firebase_core_windowsless\example\lib\main.dart`
- Modify test files reported by analyzer under `C:\Users\COLORFUL\Desktop\WuKong\test\...`

- [ ] **Step 1: Run analyzer on tests and local package example**

Run:

```powershell
flutter analyze test local_packages/firebase_core_windowsless/example
```

Expected before fixes:

```text
Analyzer reports unnecessary imports, unnecessary underscores, no_leading_underscores_for_local_identifiers, and one invalid override.
```

- [ ] **Step 2: Remove unnecessary imports in tests**

Apply these exact deletions:

```text
C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\chat_file_opening_test.dart
- remove: import 'package:wukong_im_app/core/config/api_config.dart';

C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\robot_card_message_test.dart
- remove: import 'package:wukongimfluttersdk/entity/channel.dart';

C:\Users\COLORFUL\Desktop\WuKong\test\service\im\message_auto_delete_runtime_test.dart
- remove: import 'dart:async';
- remove: import 'package:sqflite/sqflite.dart';

C:\Users\COLORFUL\Desktop\WuKong\test\service\im\message_search_runtime_test.dart
- remove: import 'package:sqflite/sqflite.dart';

C:\Users\COLORFUL\Desktop\WuKong\test\widgets\wk_emoji_text_test.dart
- remove: import 'dart:typed_data';

C:\Users\COLORFUL\Desktop\WuKong\test\wukong_push\desktop_message_alert_manager_test.dart
- remove: import 'package:flutter/foundation.dart';
```

- [ ] **Step 3: Fix invalid override in voice feedback test**

In `C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\chat_voice_feedback_service_test.dart`, remove the `@override` annotation immediately above:

```dart
  double getAmplitude() => 0.0;
```

Do not remove the method unless compilation says it is unused; the test fake may still call it directly.

- [ ] **Step 4: Replace unnecessary double-underscore unused callback parameters**

In these files, replace callback parameters named `(_, __)` with `(_, _)` only where analyzer reports `unnecessary_underscores`:

```text
C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\auth_provider_session_refresh_test.dart
C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\chat_password_guard_test.dart
C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\chat_password_runtime_test.dart
C:\Users\COLORFUL\Desktop\WuKong\test\modules\search\local_search_service_test.dart
C:\Users\COLORFUL\Desktop\WuKong\test\wukong_uikit\search\add_friends_page_parity_test.dart
C:\Users\COLORFUL\Desktop\WuKong\test\wukong_uikit\search\mail_list_page_parity_test.dart
```

Example replacement:

```dart
clearChannelMessages: (_, __) async {},
```

becomes:

```dart
clearChannelMessages: (_, _) async {},
```

For callback signatures with more than two unused parameters, use exactly one underscore for each unused parameter:

```dart
(_, _, _) async {}
```

- [ ] **Step 5: Rename local helper functions that start with underscores**

In `C:\Users\COLORFUL\Desktop\WuKong\test\wukong_uikit\group\all_members_page_search_mode_test.dart`, replace local helper names:

```dart
Widget _wrapWithApp(Widget child) {
```

with:

```dart
Widget wrapWithApp(Widget child) {
```

and replace every call to `_wrapWithApp(` with `wrapWithApp(`.

Also replace:

```dart
GroupMember _member({
```

with:

```dart
GroupMember member({
```

and replace every call to `_member(` with `member(`.

- [ ] **Step 6: Use a super parameter in local package example**

In `C:\Users\COLORFUL\Desktop\WuKong\local_packages\firebase_core_windowsless\example\lib\main.dart`, if the widget constructor is:

```dart
  const MyApp({Key? key}) : super(key: key);
```

replace it with:

```dart
  const MyApp({super.key});
```

If the class has a different name, apply the same super-parameter replacement to the constructor reported by analyzer.

- [ ] **Step 7: Format test and example files**

Run:

```powershell
dart format test local_packages/firebase_core_windowsless/example/lib/main.dart
```

Expected:

```text
Formatted ... files
```

- [ ] **Step 8: Run analyzer on tests and local package example**

Run:

```powershell
flutter analyze test local_packages/firebase_core_windowsless/example
```

Expected:

```text
No issues found!
```

If analyzer reports additional test info not listed above, fix those with minimal local edits and rerun this step.

---

### Task 4: Add CI analyze gate

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.github\workflows\flutter-android-ci.yml`

- [ ] **Step 1: Inspect existing workflow**

Run:

```powershell
Get-Content -LiteralPath .github/workflows/flutter-android-ci.yml -Raw
```

Expected current workflow has `push` and `workflow_dispatch`, but no `pull_request` and no `flutter analyze` step.

- [ ] **Step 2: Add PR trigger and analyze step**

Replace the workflow `on:` block with:

```yaml
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:
```

Add this step immediately after `Flutter pub get` and before `Run tests`:

```yaml
      - name: Flutter analyze
        run: flutter analyze
```

The final relevant step order must be:

```yaml
      - name: Flutter pub get
        run: flutter pub get

      - name: Flutter analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test

      - name: Build Android APK
        run: flutter build apk --release --target-platform android-arm64
```

- [ ] **Step 3: Verify workflow contains gate in correct order**

Run:

```powershell
$workflow = Get-Content -LiteralPath .github/workflows/flutter-android-ci.yml -Raw
$pubGet = $workflow.IndexOf('Flutter pub get')
$analyze = $workflow.IndexOf('Flutter analyze')
$tests = $workflow.IndexOf('Run tests')
$build = $workflow.IndexOf('Build Android APK')
"pubGet=$pubGet analyze=$analyze tests=$tests build=$build"
if ($workflow -notmatch 'pull_request:') { throw 'pull_request trigger missing' }
if ($analyze -lt 0) { throw 'Flutter analyze step missing' }
if (!($pubGet -lt $analyze -and $analyze -lt $tests -and $tests -lt $build)) { throw 'CI step order is incorrect' }
```

Expected:

```text
pubGet=<non-negative> analyze=<greater than pubGet> tests=<greater than analyze> build=<greater than tests>
```

No exception should be thrown.

---

### Task 5: Add Phase 5 production release preflight runbook

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\phase-5-release-preflight.md`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\README.md`
- Test: `C:\Users\COLORFUL\Desktop\WuKong\test\scripts\ops\collect_im_performance_baseline_test.dart`

- [ ] **Step 1: Create runbook with concrete commands**

Create `C:\Users\COLORFUL\Desktop\WuKong\docs\production\phase-5-release-preflight.md` with this content:

```markdown
# Phase 5 Release Preflight

This runbook is the Phase 5 quality gate for production releases. A release is not ready if any required evidence below is missing.

## Required local evidence

Run from the repository root:

```powershell
flutter analyze
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected result:

- `flutter analyze` prints `No issues found!`.
- Cache tests print `All tests passed!`.

## Required remote production evidence

Current production host context: `ubuntu@42.194.218.158`.

Validate Docker Compose rendering:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose config >/tmp/wukongim-compose-rendered.yml && test -s /tmp/wukongim-compose-rendered.yml"
```

Validate Nginx syntax:

```powershell
ssh ubuntu@42.194.218.158 "docker exec wukongim-prod-nginx nginx -t"
```

Validate public web and websocket smoke checks by running the existing baseline collector with remote checks enabled:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/collect_im_performance_baseline.ps1 -SkipFlutterBuild
```

The generated `build/performance-baseline/<timestamp>` directory must include:

- `flutter_analyze.txt`
- `flutter_test_smoke.txt`
- `remote_docker_status.txt`
- `remote_nginx_config.txt`
- `remote_public_web_smoke.txt`
- `remote_websocket_handshake.txt`
- `remote_recent_nginx_log.txt`
- `remote_recent_api_log.txt`

## Failure handling

- Analyzer failure blocks merge and release.
- Cache test failure blocks merge and release.
- Docker Compose or Nginx syntax failure blocks production deploy.
- Smoke failure blocks production deploy until the failure is triaged and a fresh passing baseline directory is captured.
- Telemetry upload failures must not break the IM runtime, but release evidence must include the failed upload symptom and fallback behavior.

## Phase 5 follow-up backlog

After this gate is green, continue Phase 5 with separate slices for:

1. Motion token naming alignment (`fast`, `normal`, `pressedScale`).
2. Send-state visual semantics (clock, single gray check, double gray check, double blue check).
3. Frame timing/Jank telemetry and dashboard queries.
```

- [ ] **Step 2: Link runbook from production README**

In `C:\Users\COLORFUL\Desktop\WuKong\docs\production\README.md`, under “Operator Entry Points”, add this bullet after “Release”:

```markdown
- Phase 5 release preflight: `docs/production/phase-5-release-preflight.md`
```

- [ ] **Step 3: Extend ops script test to cover runbook expectations**

In `C:\Users\COLORFUL\Desktop\WuKong\test\scripts\ops\collect_im_performance_baseline_test.dart`, add assertions near the existing remote smoke assertions:

```dart
      expect(content, contains('remote_docker_status'));
      expect(content, contains('remote_nginx_config'));
      expect(content, contains('remote_recent_nginx_log'));
      expect(content, contains('remote_recent_api_log'));
```

These strings already exist in the script and make the release evidence contract explicit.

- [ ] **Step 4: Format docs-related test**

Run:

```powershell
dart format test/scripts/ops/collect_im_performance_baseline_test.dart
```

Expected:

```text
Formatted 1 file
```

- [ ] **Step 5: Run ops script test**

Run:

```powershell
flutter test test/scripts/ops/collect_im_performance_baseline_test.dart
```

Expected:

```text
All tests passed!
```

---

### Task 6: Final verification and evidence capture

**Files:**
- All modified files from Tasks 1-5.

- [ ] **Step 1: Run full analyzer**

Run:

```powershell
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 2: Run targeted Phase 5 tests**

Run:

```powershell
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart test/core/motion/chat_motion_test.dart test/scripts/ops/collect_im_performance_baseline_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 3: Run full test suite if time allows**

Run:

```powershell
flutter test
```

Expected:

```text
All tests passed!
```

If the full suite fails on unrelated pre-existing integration/environment tests, record the exact failing test names and rerun the targeted Phase 5 tests before completing.

- [ ] **Step 4: Verify CI workflow gate order one more time**

Run:

```powershell
$workflow = Get-Content -LiteralPath .github/workflows/flutter-android-ci.yml -Raw
$pubGet = $workflow.IndexOf('Flutter pub get')
$analyze = $workflow.IndexOf('Flutter analyze')
$tests = $workflow.IndexOf('Run tests')
$build = $workflow.IndexOf('Build Android APK')
if ($workflow -notmatch 'pull_request:') { throw 'pull_request trigger missing' }
if (!($pubGet -lt $analyze -and $analyze -lt $tests -and $tests -lt $build)) { throw 'CI step order is incorrect' }
'CI gate order verified'
```

Expected:

```text
CI gate order verified
```

- [ ] **Step 5: Review git diff for accidental scope creep**

Run:

```powershell
git diff --stat
git diff -- .github/workflows/flutter-android-ci.yml docs/production/README.md docs/production/phase-5-release-preflight.md
```

Expected:

- Diff includes analyzer cleanup, CI gate, and runbook changes.
- Diff does not include unrelated visual redesign or new IM features.

- [ ] **Step 6: Prepare final evidence summary**

In the final response, include:

```text
Verification:
- flutter analyze: No issues found!
- cache + motion + ops targeted tests: All tests passed!
- CI gate order: verified
- Full flutter test: passed OR not run / failed with listed environment-specific failures
```

Do not claim completion unless Step 1 and Step 2 pass in the current session.
