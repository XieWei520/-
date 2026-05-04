# Phase 3 Large History / Storage / Web Acceptance Record

Date: 2026-05-04
Branch: `codex/phase3-large-history-storage-web`
Worktree: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\phase3-large-history-storage-web`

## Scope

This record covers Phase 3 of the IM optimization plan:

1. Web refresh/restart/offline restores recent history from the Web cache.
2. Large native history pagination remains smooth and observable.
3. Image-heavy long chat lists avoid obvious decode/jank pressure.

## Commits included

- `d75ec05` — `feat: add web indexeddb chat cache store`
- `4a424e0` — `feat: persist web chat history through gateway`
- `b6a0714` — `perf: harden native message paging indexes`
- `0cefcbe` — `perf: cap chat image decode cost`
- `20abfb2` — `feat: add chat jank timing monitor`

## Automated verification

### Web cache / history persistence

Command:

```powershell
flutter test test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart test/data/providers/chat_history_gateway_web_cache_test.dart
```

Result: PASS, 19 tests.

Coverage highlights:

- Web cache contract isolates by uid/channel and supports latest/older/around reads.
- IndexedDB-backed store supports hydration, retry after transient persistence failure, retention trimming, external-tab preservation, default-uid hydration, and client-temp-message replacement.
- Web direct history sync writes successful remote pages into cache and falls back to cache on remote failure.

### Native large-history / telemetry / image jank

Command:

```powershell
flutter test test/data/providers/chat_history_gateway_test.dart test/data/providers/conversation_provider_telemetry_test.dart test/data/providers/message_list_repository_boundary_test.dart test/data/providers/native_message_repository_index_test.dart test/core/cache/media_cache_manager_test.dart test/telemetry/message_query_jank_monitor_test.dart
```

Result: PASS, 30 tests.

Coverage highlights:

- Native repository/gateway boundaries still delegate paging through the expected query modes.
- Defensive native message indexes are asserted for large-history pagination.
- Query telemetry records `latest_page`, `older_page`, and `around_page` modes.
- Chat list media decode requests are bounded for list bubbles.
- Media-heavy list rows keep alive only where appropriate.
- Jank monitor counts build/raster threshold breaches, is viewport-scoped, disposes callbacks, and supports explicit production opt-in while keeping release quiet by default.

### Task 5 telemetry regression

Command:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/telemetry/message_query_jank_monitor_test.dart test/data/providers/conversation_provider_telemetry_test.dart
```

Result: PASS, 16 tests.

### Analyzer

Full command:

```powershell
flutter analyze
```

Result: FAIL with 65 existing project-wide issues outside the Phase 3 touched files.

The reported items are existing unrelated warnings/infos in modules such as auth widgets, voice chat widgets, robot cards, search tests, notification bridge, UIKit group pages, and local package examples. They are not introduced by this Phase 3 branch.

Phase 3 touched-file analyzer command:

```powershell
$changed = git diff --name-only d57666c..HEAD -- '*.dart' | Sort-Object
flutter analyze @($changed)
```

Result: PASS, 26 analyzed Phase 3 Dart files, no issues found.

## Manual acceptance checklist

These checks require a live target account/browser/native runtime with realistic message history. They were not executed inside this coding worktree because the worktree verification was automated-only.

Use this checklist before promoting the branch:

1. Web recent history persistence
   - Open a Web conversation with recent messages.
   - Load at least one latest page and one older page.
   - Refresh the browser tab.
   - Temporarily disable network or force remote sync failure.
   - Reopen the same conversation.
   - Expected: recent cached history appears from IndexedDB for the current uid/channel only.

2. Native large-history pagination
   - Open a native conversation with a large history.
   - Load latest, older, and around-anchor pages.
   - Expected: pagination remains stable and telemetry emits `latest_page`, `older_page`, and `around_page` timings.

3. Image-heavy long-list jank
   - Open an image-heavy conversation.
   - Scroll repeatedly through long image sections.
   - Expected: list bubble decode dimensions remain bounded; no obvious frame jank spikes appear. In release, enable `messageQueryJankMonitorEnabledProvider` through runtime/remote config if production telemetry sampling is required.

## Phase 4 follow-up

- Decide how production remote config should override `messageQueryJankMonitorEnabledProvider` for sampled release telemetry.
- Clean up the repository-wide existing analyzer warnings separately; do not mix that cleanup with Phase 3 storage/performance changes.
- Run the manual acceptance checklist on a real Web browser and native device/emulator before merging to a release branch.
