# Implementation Plan: XiaoeTech Message Forwarding Center

## Overview
Build a WebView-first XiaoeTech forwarding center for circle/community, course interaction, and live comments. The shell opens `https://study.xiaoe-tech.com/#/muti_index`; the operator manually navigates to and stays on the target page. Captured text, image, and file items are normalized into the shared local monitor event model, then routed and forwarded through the existing Wukong monitor forwarding pipeline.

## Architecture Decisions
- Use a local desktop shell for the MVP because XiaoeTech Open API credentials and message-push configuration are unavailable.
- Reuse `LocalMonitorShellClient`, `LocalMonitorShellStatus`, `LocalMonitorMessageEvent`, SSE events, route matching, startup priming, and dedupe patterns instead of building a separate XiaoeTech forwarding stack.
- Extend the shared local monitor model with `file_attachments`; images already fit `image_attachments`.
- Use a 20 MB per-file forwarding limit. Oversized files are skipped with explicit diagnostics.
- Treat WebView page content as untrusted data. The probe extracts structured candidates only; page text cannot become instructions or configuration.

## Dependency Graph
Shared file attachment model -> XiaoeTech probe/parser -> XiaoeTech shell app/server -> XiaoeTech shell client wrappers -> forwarding service -> auto-forward runner -> management UI -> launch/docs/manual verification.

## Task List

### Phase 1: Shared Event Contract

#### Task 1: Add shared file attachment model tests - Done
**Description:** Define the `file_attachments` contract in tests before changing the shared local monitor model.

**Acceptance criteria:**
- [ ] `LocalMonitorObservedMessage.fromJson` parses valid `file_attachments`.
- [ ] `LocalMonitorMessageEvent.fromJson` parses valid `file_attachments`.
- [ ] File records without `source_url` and `local_path` are ignored.

**Verification:**
- [ ] Tests fail before implementation: `flutter test test/modules/local_monitor/local_monitor_shell_models_test.dart`

**Dependencies:** None

**Files likely touched:**
- `test/modules/local_monitor/local_monitor_shell_models_test.dart`

**Estimated scope:** S

#### Task 2: Implement shared file attachment model - Done
**Description:** Add `LocalMonitorFileAttachment` and wire it into observed messages and normalized events without changing existing image behavior.

**Acceptance criteria:**
- [ ] File attachments include `sourceUrl`, `localPath`, `fileName`, `mimeType`, and `sizeBytes`.
- [ ] Existing `image_attachments` parsing remains compatible.
- [ ] Empty file records are filtered.

**Verification:**
- [ ] Tests pass: `flutter test test/modules/local_monitor/local_monitor_shell_models_test.dart`

**Dependencies:** Task 1

**Files likely touched:**
- `lib/modules/local_monitor/local_monitor_shell_models.dart`

**Estimated scope:** S

### Checkpoint: Shared Contract
- [x] Local monitor model tests pass.
- [x] Existing local monitor shell client parsing tests still pass.

### Phase 2: XiaoeTech WebView Capture Core

#### Task 3: Scaffold XiaoeTech shell app package - Done
**Description:** Add a minimal Windows Flutter shell app patterned after existing monitor shells. It should open XiaoeTech `muti_index`, host the local monitor shell server, and persist status.

**Acceptance criteria:**
- [x] Shell app starts a loopback shell server with `/status`, `/health`, `/events`, and capture controls.
- [x] Shell app loads `https://study.xiaoe-tech.com/#/muti_index`.
- [x] Status records runtime URL, title, login unknown/logged-in estimate, and WebView availability.

**Verification:**
- [x] Tests pass: `flutter test tools/xiaoe_monitor_shell_app/test`

**Dependencies:** Task 2

**Files likely touched:**
- `tools/xiaoe_monitor_shell_app/pubspec.yaml`
- `tools/xiaoe_monitor_shell_app/lib/main.dart`
- `tools/xiaoe_monitor_shell_app/test/xiaoe_shell_app_test.dart`

**Estimated scope:** M

#### Task 4: Add XiaoeTech page probe tests - Done
**Description:** Define DOM sample parsing for visible live comments, circle/course text, images, files, duplicates, and malformed content.

**Acceptance criteria:**
- [x] Live comment text sample yields one event per comment.
- [x] Circle/course image sample yields `image_attachments`.
- [x] Circle/course file sample yields `file_attachments`.
- [x] Duplicate samples produce stable dedupe keys.

**Verification:**
- [x] Tests failed before parser: `flutter test tools/xiaoe_monitor_shell_app/test/xiaoe_page_probe_test.dart`

**Dependencies:** Task 2

**Files likely touched:**
- `tools/xiaoe_monitor_shell_app/test/xiaoe_page_probe_test.dart`

**Estimated scope:** S

#### Task 5: Implement XiaoeTech page probe and normalizer - Done
**Description:** Implement JavaScript/DOM probe result parsing and Dart normalization into local monitor events.

**Acceptance criteria:**
- [x] Probe output contains observed page source identity, comment candidates, image candidates, file candidates, and diagnostics.
- [x] Normalized events use stable `eventId` and `dedupeKey`.
- [x] Empty/noisy UI text is ignored.

**Verification:**
- [x] Tests pass: `flutter test tools/xiaoe_monitor_shell_app/test/xiaoe_page_probe_test.dart`

**Dependencies:** Task 4

**Files likely touched:**
- `tools/xiaoe_monitor_shell_app/lib/src/xiaoe_page_probe.dart`
- `tools/xiaoe_monitor_shell_app/lib/src/xiaoe_page_observer.dart`

**Estimated scope:** M

#### Task 6: Integrate probe into shell runtime - Done
**Description:** Run the probe periodically and on observer events, merge events into shell status, and publish SSE snapshot updates.

**Acceptance criteria:**
- [x] `/status` shows observed conversations/messages/recent events.
- [x] `/events` emits `snapshot_updated` after new captured items.
- [x] Diagnostics include current URL, title, selector hits, and visible candidate count.

**Verification:**
- [x] Tests pass: `flutter test tools/xiaoe_monitor_shell_app/test`

**Dependencies:** Tasks 3 and 5

**Files likely touched:**
- `tools/xiaoe_monitor_shell_app/lib/main.dart`
- `tools/xiaoe_monitor_shell_app/lib/src/xiaoe_runtime_snapshot_mapper.dart`
- `tools/xiaoe_monitor_shell_app/test/xiaoe_shell_app_test.dart`

**Estimated scope:** M

### Checkpoint: Capture Core
- [x] XiaoeTech shell app tests pass.
- [x] Local shell API returns normalized events in the same shape as existing monitors.

### Phase 3: App-Side Client And Forwarding

#### Task 7: Add XiaoeTech shell client/model wrappers - Done
**Description:** Add thin app-side wrappers over `LocalMonitorShellClient` and `LocalMonitor*` models.

**Acceptance criteria:**
- [x] Status fetch maps common status into XiaoeTech-specific model aliases.
- [x] SSE event watching maps into XiaoeTech shell events.
- [x] Configured source sync reuses `/routing/sources`.

**Verification:**
- [x] Tests pass: `flutter test test/modules/xiaoe_monitor/xiaoe_monitor_shell_client_test.dart`

**Dependencies:** Task 2

**Files likely touched:**
- `lib/modules/xiaoe_monitor/xiaoe_monitor_shell_models.dart`
- `lib/modules/xiaoe_monitor/xiaoe_monitor_shell_client.dart`
- `test/modules/xiaoe_monitor/xiaoe_monitor_shell_client_test.dart`

**Estimated scope:** M

#### Task 8: Add forwarding service tests - Done
**Description:** Specify route matching, dedupe, text/image/file delivery, disabled routes, 20 MB file limit, and unsupported-file diagnostics.

**Acceptance criteria:**
- [x] Matching uses source id first and source name fallback.
- [x] Duplicate text/image/file events are skipped.
- [x] Oversized files are skipped with diagnostics.
- [x] HTTP/HTTPS file sources are downloaded into a bounded temp cache; non-downloadable file sources return explicit unsupported diagnostics.

**Verification:**
- [x] Tests failed before implementation: `flutter test test/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service_test.dart`

**Dependencies:** Task 7

**Files likely touched:**
- `test/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service_test.dart`

**Estimated scope:** S

#### Task 9: Implement XiaoeTech forwarding service - Done
**Description:** Implement route-based forwarding and settings storage. Reuse local monitor text sender and Feishu-style media preparation where possible.

**Acceptance criteria:**
- [x] Text messages forward to Wukong target groups.
- [x] Images download/upload/send through existing media path.
- [x] Files under 20 MB upload/send through the shared local monitor file sender; unsupported source URLs produce explicit diagnostics.
- [x] Dedupe persists enough keys to prevent replay during normal runtime.

**Verification:**
- [x] Tests pass: `flutter test test/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service_test.dart`

**Dependencies:** Task 8

**Files likely touched:**
- `lib/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service.dart`
- `lib/modules/local_monitor/local_monitor_forwarding.dart`

**Estimated scope:** M

#### Task 10: Add XiaoeTech auto-forward runner - Done
**Description:** Add a low-latency runner patterned on Feishu: settings load, startup priming, SSE-triggered forwarding, periodic fallback polling.

**Acceptance criteria:**
- [x] Startup visible historical events are primed, not forwarded.
- [x] New `snapshot_updated` events trigger immediate forwarding.
- [x] Periodic polling forwards missed events.

**Verification:**
- [x] Tests pass: `flutter test test/modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner_test.dart`

**Dependencies:** Task 9

**Files likely touched:**
- `lib/modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner.dart`
- `test/modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner_test.dart`

**Estimated scope:** M

### Checkpoint: Forwarding Core
- [x] XiaoeTech client/forwarding/runner tests pass.
- [x] Existing local monitor and Feishu forwarding tests still pass.

### Phase 4: Management UI And Launch

#### Task 11: Add XiaoeTech monitor center page - Done
**Description:** Add the management UI using shared monitor center sections where practical.

**Acceptance criteria:**
- [x] Page shows shell status, login/session hint, capture state, and diagnostics.
- [x] Page supports start/stop/reload/manual forward controls.
- [x] Page supports route configuration from active observed source to Wukong target group.

**Verification:**
- [x] Tests pass: `flutter test test/modules/xiaoe_monitor/xiaoe_monitor_center_page_test.dart`

**Dependencies:** Task 10

**Files likely touched:**
- `lib/modules/xiaoe_monitor/xiaoe_monitor_center_page.dart`
- `test/modules/xiaoe_monitor/xiaoe_monitor_center_page_test.dart`

**Estimated scope:** M

#### Task 12: Register app route and launcher - Done
**Description:** Expose XiaoeTech forwarding center in the admin/navigation surface and add local run scripts.

**Acceptance criteria:**
- [x] Management system has a reachable XiaoeTech information forwarding entry.
- [x] Local shell can be launched with a stable port/token.
- [x] Route registration does not disrupt existing monitor entries.

**Verification:**
- [x] Tests pass for route/widget coverage related to the entry point.
- [x] Shell build command works: `flutter build windows` from the shell app.

**Dependencies:** Task 11

**Files likely touched:**
- `lib/app/app.dart`
- `run_xiaoe_monitor_shell_app.bat`
- `tools/xiaoe_monitor_shell_app/pubspec.yaml`

**Estimated scope:** S

#### Task 13: Manual runtime verification
**Description:** Verify the real workflow with an operator-controlled XiaoeTech page.

**Acceptance criteria:**
- [ ] Login/session persists in the shell.
- [ ] Operator manually opens one target page from `muti_index`.
- [ ] One live text comment forwards once.
- [ ] One image interaction forwards once.
- [ ] One file under 20 MB forwards once or returns explicit unsupported-file diagnostic.

**Verification:**
- [ ] `flutter analyze`
- [ ] `flutter test test/modules/xiaoe_monitor`
- [ ] `flutter test tools/xiaoe_monitor_shell_app/test`
- [ ] Manual workflow check recorded in an implementation note.

**Dependencies:** Task 12

**Files likely touched:**
- `docs/superpowers/artifacts/2026-05-17-xiaoe-message-forwarding-center-test-report.md`

**Estimated scope:** S

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| XiaoeTech changes DOM selectors | High | Keep selector diagnostics in `/status`, isolate selectors in `xiaoe_page_probe.dart`, and avoid broad UI assumptions. |
| WebView cannot access downloadable file URLs outside session | Medium | Prefer browser/body capture where possible; otherwise record explicit unavailable-file diagnostics. |
| Wukong file message type is unavailable or unclear | Medium | Implement file attachment model first; forwarding service can initially emit explicit unsupported-file diagnostics while preserving event capture. |
| Startup replays old visible comments | High | Prime dedupe on runner start before forwarding live events. |
| Duplicate image/file events from DOM plus network capture | Medium | Use stable content fingerprints and per-route media dedupe keys. |
| Current worktree has many unrelated changes | Medium | Touch only XiaoeTech/local-monitor files required for this feature and avoid reverting existing changes. |

## Parallelization Opportunities
- After Task 2, shell probe tests and app-side client wrapper tests can be written independently.
- After Task 7, forwarding service and management UI test scaffolding can proceed in parallel if write sets are kept separate.
- Manual runtime verification must remain sequential after UI and shell launch are connected.

## Review Checkpoints
- Foundation checkpoint after Tasks 1-2.
- Capture checkpoint after Tasks 3-6.
- Forwarding checkpoint after Tasks 7-10.
- Final checkpoint after Tasks 11-13 with code review and manual verification.

## Approval Gate
Implementation can start after this plan is approved. The first implementation slice should be Tasks 1-2 only, because the shared file attachment contract is the dependency for file capture and forwarding.
