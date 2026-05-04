# Phase 3 Large History / Storage / Web Acceptance Record

Date: 2026-05-04
Branch: `codex/phase3-large-history-storage-web`
Worktree: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\phase3-large-history-storage-web`

## Scope

This record covers Phase 3 of the IM optimization plan:

1. Web refresh/restart/offline restores recent history from the Web cache.
2. Large native history pagination remains smooth and observable.
3. Image-heavy long chat lists avoid obvious decode/jank pressure.
4. External closeout: real Web/Native runtime acceptance, analyzer gate, and remote/PR readiness.

## Commits included before closeout

- `d75ec05` — `feat: add web indexeddb chat cache store`
- `4a424e0` — `feat: persist web chat history through gateway`
- `b6a0714` — `perf: harden native message paging indexes`
- `0cefcbe` — `perf: cap chat image decode cost`
- `20abfb2` — `feat: add chat jank timing monitor`
- `6a93423` — `docs: record phase 3 acceptance verification`

The external-closeout commit adds analyzer cleanup plus a dedicated runtime probe:

- `tool/phase3_large_history_runtime_probe.dart`
- `test/tool/phase3_large_history_runtime_probe_test.dart`

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

### Runtime probe regression

Command:

```powershell
flutter test test/tool/phase3_large_history_runtime_probe_test.dart
```

Result: PASS, 2 tests.

Coverage highlights:

- Probe UI renders Web cache, Native storage, and Media/Jank result sections.
- Probe exercises real cache and telemetry primitives without relying on account credentials.

### Full analyzer gate

Command:

```powershell
flutter analyze
```

Result: PASS, no issues found.

Closeout cleanup removed the previous project-wide analyzer findings by applying safe Dart fixes and targeted SDK migrations:

- `withOpacity` -> `withValues(alpha: ...)`
- `textScaleFactor` -> `textScaler`
- `WillPopScope` -> `PopScope`
- deprecated `RadioListTile.groupValue/onChanged` -> `RadioGroup`
- invalid override / unused imports / collection literal cleanup
- restored the notification channel bridge `try` block to valid catch/fallback behavior

## Real Web / Native runtime acceptance

A dedicated runtime probe was added for Phase 3 closeout. It validates the Phase 3 primitives in real platform runtimes without reading account tokens or requiring a live user session.

### Web runtime: Codex app browser / Chrome

Commands and actions:

```powershell
flutter build web -t tool/phase3_large_history_runtime_probe.dart --debug
python -m http.server 53124 --bind 127.0.0.1 --directory build\web
```

Then opened the built app in the Codex app browser at:

```text
http://localhost:53124/
```

Result: PASS.

Observed on the Web page:

- `Platform: web`
- `store_type=IndexedDbWebChatCacheStore`
- `latest_orders=105,106,107`
- `older_orders=101,102`
- `around_orders=102,103,104`
- `uid_isolation_count=0`
- `indexeddb_runtime_exercised=true`
- `estimated_decode_bytes=262144`
- `jank_events=2`

Evidence artifacts:

- `docs/superpowers/artifacts/phase3-runtime-closeout/web-build.log`
- `docs/superpowers/artifacts/phase3-runtime-closeout/codex-app-browser-phase3-page.png`
- `docs/superpowers/artifacts/phase3-runtime-closeout/web-static-server.stderr.log`

### Native runtime: Windows desktop

Commands and actions:

```powershell
flutter build windows -t tool/phase3_large_history_runtime_probe.dart --debug
build\windows\x64\runner\Debug\InfoEquity.exe
```

Result: PASS.

Observed on the Windows runtime page:

- `Platform: windows`
- Web cache contract still works through the native fallback store:
  - `store_type=MemoryWebChatCacheStore`
  - `latest_orders=105,106,107`
  - `older_orders=101,102`
  - `around_orders=102,103,104`
  - `uid_isolation_count=0`
- Native SQLite storage probe creates and verifies indexes:
  - `idx_message_channel_order_seq`
  - `idx_message_channel_seq`
  - `idx_message_client_msg_no`
  - `idx_message_message_id`
- Media/jank probe verifies:
  - `estimated_decode_bytes=262144`
  - `jank_events=2`
  - `chat_scroll_build_jank_frame_ms`
  - `chat_scroll_raster_jank_frame_ms`

Evidence artifacts:

- `docs/superpowers/artifacts/phase3-runtime-closeout/windows-build.log`
- `docs/superpowers/artifacts/phase3-runtime-closeout/windows-runtime-probe-screen.png`

## Remote / PR publishing status

Local branch is ready for publishing:

```text
codex/phase3-large-history-storage-web
```

Publishing is blocked by repository/account setup outside this worktree:

1. `git remote -v` in both this worktree and `C:\Users\COLORFUL\Desktop\WuKong` returns no remote URL.
2. `gh auth status` reports: not logged into any GitHub host.

To publish the PR, provide the GitHub repository URL and complete GitHub CLI login, then run:

```powershell
git remote add origin <github-repo-url>
gh auth login
git push -u origin codex/phase3-large-history-storage-web
gh pr create --draft --title "[codex] Phase 3 large history storage web closeout" --body-file <pr-body-file>
```

## Phase 4 follow-up

- Decide how production remote config should override `messageQueryJankMonitorEnabledProvider` for sampled release telemetry.
- Keep `tool/phase3_large_history_runtime_probe.dart` as a reusable smoke/manual acceptance entry for future Phase 3 regressions.
- After remote/auth are configured, push this branch and open a draft PR before merging to a release branch.
