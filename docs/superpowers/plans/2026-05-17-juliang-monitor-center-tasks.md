# Tasks: Juliang Aggregate Monitor Forwarding Center

Date: 2026-05-17
Spec: `docs/superpowers/specs/2026-05-17-juliang-monitor-center-design.md`
Plan: `docs/superpowers/plans/2026-05-17-juliang-monitor-center.md`

Do not start implementation until this task list is reviewed. Implementation must follow test-driven development: write the failing test first, then the smallest code change that makes it pass.

## Phase 1: App-Side Contract And Forwarding

- [x] Task 1: Add Juliang shell client/model adapter
  - Acceptance: neutral local monitor `/status` payloads parse into `JuliangMonitorShellStatus`; recent events and observed conversations remain accessible; configured source sync delegates to the neutral client without Feishu naming.
  - Verify: `flutter test test/modules/juliang_monitor/juliang_monitor_shell_client_test.dart -r compact`
  - Files: `lib/modules/juliang_monitor/juliang_monitor_shell_models.dart`, `lib/modules/juliang_monitor/juliang_monitor_shell_client.dart`, `test/modules/juliang_monitor/juliang_monitor_shell_client_test.dart`

- [x] Task 2: Add forwarding route/settings model and isolated persistence
  - Acceptance: route/settings JSON round-trip works; default settings are disabled with no routes; SharedPreferences keys are `juliang_monitor_*`; default relay identity is `聚合转发助手`.
  - Verify: `flutter test test/modules/juliang_monitor/juliang_monitor_forwarding_service_test.dart -r compact`
  - Files: `lib/modules/juliang_monitor/juliang_monitor_forwarding_service.dart`, `test/modules/juliang_monitor/juliang_monitor_forwarding_service_test.dart`

- [x] Task 3: Implement text-only forwarding service
  - Acceptance: enabled matching text events forward to the configured WuKong group; duplicate, unmatched, disabled, and non-text events are skipped; forwarded text uses the `[聚合转发]` header.
  - Verify: `flutter test test/modules/juliang_monitor/juliang_monitor_forwarding_service_test.dart -r compact`
  - Files: `lib/modules/juliang_monitor/juliang_monitor_forwarding_service.dart`, `test/modules/juliang_monitor/juliang_monitor_forwarding_service_test.dart`

- [x] Task 4: Implement Juliang auto-forward runner
  - Acceptance: runner starts/stops cleanly; syncs configured source conversations; primes startup events without forwarding old messages; forwards live text events from SSE or 1-second polling fallback; reports errors through `onError`.
  - Verify: `flutter test test/modules/juliang_monitor/juliang_monitor_auto_forward_runner_test.dart -r compact`
  - Files: `lib/modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart`, `test/modules/juliang_monitor/juliang_monitor_auto_forward_runner_test.dart`

### Checkpoint: Phase 1

- [x] Verify: `flutter test test/modules/juliang_monitor -r compact`
- [x] Verify: `flutter analyze lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor`

## Phase 2: Management Entry And Center UI

- [x] Task 5: Add Juliang monitor center page MVP
  - Acceptance: page shows shell state, login state, capture state, manual-login hint, routes, recent text events, and manual "forward recent" action; it can save a source-to-target route using loaded WuKong groups.
  - Verify: `flutter test test/modules/juliang_monitor/juliang_monitor_center_page_test.dart -r compact`
  - Files: `lib/modules/juliang_monitor/juliang_monitor_center_page.dart`, `test/modules/juliang_monitor/juliang_monitor_center_page_test.dart`

- [x] Task 6: Wire management-system entry
  - Acceptance: `管理系统` renders an enabled `聚合信息转发中心` card; tapping it opens `JuliangMonitorCenterPage`; existing Feishu and DingTalk entries still render and navigate.
  - Verify: `flutter test test/modules/vip/vip_management_page_test.dart -r compact`
  - Files: `lib/modules/vip/vip_management_page.dart`, `test/modules/vip/vip_management_page_test.dart`

### Checkpoint: Phase 2

- [x] Verify: `flutter test test/modules/juliang_monitor test/modules/vip -r compact`
- [x] Verify: `flutter analyze lib/modules/vip lib/modules/juliang_monitor test/modules/vip test/modules/juliang_monitor`

## Phase 3: App Startup Auto-Forward Wiring

- [x] Task 7: Register runner in app coordinator
  - Acceptance: `WuKongApp` creates `JuliangMonitorAutoForwardRunner`; the existing `LocalMonitorAutoForwardCoordinator` starts it on WuKong login, stops it on logout, and disposes it with other monitor runners.
  - Verify: `flutter test test/modules/juliang_monitor test/modules/local_monitor -r compact`
  - Files: `lib/app/app.dart`, `lib/modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart`, `test/modules/juliang_monitor/juliang_monitor_auto_forward_runner_test.dart`

### Checkpoint: Phase 3

- [x] Verify: `flutter test test/modules/juliang_monitor test/modules/local_monitor -r compact`
- [x] Verify: `flutter analyze lib/app lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor`
- [ ] Human review before browser-shell capture work starts.

## Phase 4: Strict-Incognito Shell Skeleton

- [x] Task 8: Scaffold Juliang shell package and incognito runtime policy
  - Acceptance: `tools/juliang_monitor_shell_app` exists; strict policy exposes no persistent profile/session paths; fresh session directories are unique and recursively destroyed without deleting sibling files.
  - Verify: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_incognito_runtime_test.dart -r compact`
  - Files: `tools/juliang_monitor_shell_app/pubspec.yaml`, `tools/juliang_monitor_shell_app/lib/src/juliang_incognito_runtime.dart`, `tools/juliang_monitor_shell_app/test/juliang_incognito_runtime_test.dart`

- [x] Task 9: Add shell app, status store, and loopback server
  - Acceptance: shell starts `ShellServer` with token `wukong-juliang-shell-dev`; initial `/status` reports online shell, login required, stopped capture, strict incognito diagnostics, and target URL `https://msg.juliang888.top/`.
  - Verify: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_shell_app_test.dart -r compact`
  - Files: `tools/juliang_monitor_shell_app/lib/main.dart`, `tools/juliang_monitor_shell_app/lib/src/juliang_runtime_snapshot_mapper.dart`, `tools/juliang_monitor_shell_app/test/juliang_shell_app_test.dart`

- [x] Task 10: Add Windows WebView shell loading the aggregate panel
  - Acceptance: shell opens `https://msg.juliang888.top/` in a fresh session directory; UI clearly states manual login is required every launch; shutdown cleanup destroys the session directory.
  - Verify: `cd tools/juliang_monitor_shell_app; flutter analyze lib test`
  - Files: `tools/juliang_monitor_shell_app/lib/main.dart`, `tools/juliang_monitor_shell_app/lib/src/juliang_incognito_runtime.dart`, `tools/juliang_monitor_shell_app/test/juliang_shell_app_test.dart`

### Checkpoint: Phase 4

- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter test test -r compact`
- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter analyze lib test`
- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter build windows --debug`

## Phase 5: Logged-In Runtime Capture

- [x] Task 11: Inspect logged-in aggregate runtime and record parser contract
  - Acceptance: identify whether stable text messages are available from network/API payloads; if not, document DOM selectors/events used for MVP; no credentials, cookies, or captured secrets are saved.
  - Verify: manual notes added to the plan or a focused runtime fixture test.
  - Files: `docs/superpowers/plans/2026-05-17-juliang-monitor-center.md`, optional shell parser fixture under `tools/juliang_monitor_shell_app/test/fixtures/`

- [x] Task 12: Implement text event parser and snapshot mapper
  - Acceptance: parser normalizes source conversation ID/name, sender, message ID, text, observed time, and dedupe key into `NormalizedMessageEvent`; non-text events are ignored; parser tests cover at least one real logged-in payload or DOM fixture.
  - Verify: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_text_event_parser_test.dart -r compact`
  - Files: `tools/juliang_monitor_shell_app/lib/src/juliang_text_event_parser.dart`, `tools/juliang_monitor_shell_app/lib/src/juliang_runtime_snapshot_mapper.dart`, `tools/juliang_monitor_shell_app/test/juliang_text_event_parser_test.dart`

- [x] Task 13: Publish real-time shell events
  - Acceptance: new parsed text messages update `/events/recent`; `/events` emits a snapshot-updated SSE event; configured routing sources limit active capture where the runtime can filter sources.
  - Verify: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_runtime_capture_test.dart -r compact`
  - Files: `tools/juliang_monitor_shell_app/lib/src/juliang_runtime_capture.dart`, `tools/juliang_monitor_shell_app/lib/main.dart`, `tools/juliang_monitor_shell_app/test/juliang_runtime_capture_test.dart`

### Checkpoint: Phase 5

- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter test test -r compact`
- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter analyze lib test`
- [x] Verify: `cd tools/juliang_monitor_shell_app; flutter build windows --release`
- [x] Manual: close and relaunch shell, confirm aggregate login is required again.

## Phase 6: End-To-End Verification And Review

- [ ] Task 14: Run app-to-shell forwarding integration check
  - Acceptance: one configured aggregate source forwards one new text message to one WuKong test group exactly once; refresh/replay does not duplicate it; non-text events do not forward.
  - Verify: manual end-to-end checklist in the implementation summary plus targeted tests below.
  - Files: no expected code changes unless defects are found.

  Notes from 2026-05-17 follow-up:
  - A logged-in shell session reached `logged_in` / `running` at `https://msg.juliang888.top/user`, but the first DOM probe was too broad and mixed login-page/navigation/source-list text into `recent_events`.
  - Added failing regression coverage, then fixed the shell DOM probe and text normalization filters so login chrome and aggregate UI text are not treated as forwardable messages.
  - Passed after fix: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_text_event_parser_test.dart -r compact`
  - Passed after fix: `cd tools/juliang_monitor_shell_app; flutter test test/juliang_page_observer_test.dart -r compact`
  - Passed after fix: `cd tools/juliang_monitor_shell_app; flutter test test -r compact`
  - Passed after fix: `cd tools/juliang_monitor_shell_app; flutter analyze lib test`
  - Passed after fix: `cd tools/juliang_monitor_shell_app; flutter build windows --release`
  - Relaunched the fixed shell; login page reports `event_count=0`, `recent_events=0`, and strict incognito diagnostics.
  - Full app target tests passed after fixing VIP navigation tests to inject no-op center pages instead of triggering real shell launches.
  - Task remains pending because the fixed no-trace shell still needs a fresh manual login, one configured source-to-WuKong test group route, and one new aggregate text message to prove real forwarding.

- [x] Task 15: Final quality review and cleanup
  - Acceptance: targeted analyzer/tests pass; no secrets/session data are present in git status; no Feishu/DingTalk behavior is changed unintentionally; any dead code is listed before removal.
  - Verify: `flutter test test/modules/juliang_monitor test/modules/vip test/modules/local_monitor -r compact`; `flutter analyze lib/app lib/modules/vip lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor test/modules/vip`
  - Files: documentation summary only unless review finds defects.

  Notes from 2026-05-17 final review:
  - Passed: `flutter test test/modules/juliang_monitor test/modules/vip test/modules/local_monitor -r compact`
  - Passed: `flutter analyze lib/app lib/modules/vip lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor test/modules/vip`
  - Passed shell checks: `flutter test test -r compact`, `flutter analyze lib test`, `flutter build windows --release`
  - Manual shell relaunch reached `login_required` at `https://msg.juliang888.top/login` with strict incognito diagnostics and zero recent events.
  - Startup cleanup removed stale `juliang_fresh_session_*` runtime directories; no聚合 shell process, WebView2 child process, or `18796` listener remained after cleanup.
  - Review coverage now includes Feishu, DingTalk, Mengxia, and Juliang management-card navigation tests.
  - Task 14 remains pending because the active no-trace shell session was not logged in and no new aggregate text message plus WuKong test group route was available for real forwarding verification.

## Final Completion Criteria

- [ ] Spec, plan, and tasks are committed or ready for commit with implementation.
- [ ] Every new behavior has a test.
- [x] Shell strict-incognito behavior is tested and manually verified.
- [ ] Real-time text forwarding works for a configured source route.
- [x] Feishu and DingTalk monitor entries still work.
