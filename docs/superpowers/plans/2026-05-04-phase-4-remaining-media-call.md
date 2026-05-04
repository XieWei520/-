# Phase 4 Remaining Media and Call Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Phase 4.2 large-file multipart resume and Phase 4.3 LiveKit call state/telemetry gaps after Phase 4.1 is already implemented.

**Architecture:** Keep existing compatible APIs, add missing production hardening with small vertical slices: Nginx streaming config, client-side parallel/retry upload, server-side multipart validation, strict public call lifecycle states, structured call failure reasons, client telemetry buffering, and TS-DD telemetry intake. Preserve old endpoints where needed for rollback.

**Tech Stack:** Flutter/Dart tests for client behavior; Go tests in TS-DD for server behavior; Python unittest for deployment config; remote SSH path `ubuntu@42.194.218.158:/opt/wukongim-prod/src`.

---

### Task 1: Large File Multipart Weak-Network Hardening

**Files:**
- Modify: `lib/data/upload/resumable_file_uploader.dart`
- Modify: `test/data/upload/resumable_file_uploader_test.dart`
- Modify: `lib/core/config/api_config.dart`
- Modify: `lib/service/api/file_multipart_upload_client.dart`
- Modify: `test/service/api/file_multipart_upload_client_test.dart`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Remote test/create: `/opt/wukongim-prod/src/deploy/production/scripts/test_multipart_nginx_config.py`
- Remote modify: `/opt/wukongim-prod/src/modules/file/api.go`
- Remote modify: `/opt/wukongim-prod/src/modules/file/service.go`
- Remote modify: `/opt/wukongim-prod/src/modules/file/multipart_temp_store.go`
- Remote modify: `/opt/wukongim-prod/src/modules/file/multipart_service_test.go`

- [ ] **Step 1: Write failing Flutter tests**
  - Add a test proving `ResumableFileUploader` runs up to 3 part uploads concurrently for 4+ parts and checkpoints each successful part without losing progress.
  - Add a test proving a part that fails twice is retried with injected exponential backoff delays and then completes.
  - Add a test proving the multipart client sends the standard `/v1/file/multipart/parts/{part_no}` path.

- [ ] **Step 2: Run Flutter tests and verify RED**
  - Run: `flutter test test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart`
  - Expected: FAIL because uploads are serial, no retry delay is injected, and the client still uses `/multipart/part`.

- [ ] **Step 3: Implement minimal Flutter changes**
  - Add `maxConcurrentParts`, `maxPartAttempts`, and injectable delay/backoff to `ResumableFileUploader`.
  - Upload missing parts through a bounded worker pool of size 3.
  - Persist checkpoint after each successful part.
  - Keep complete part list deterministic.
  - Switch client part upload path to `/v1/file/multipart/parts/{partNumber}` while retaining config constant names.

- [ ] **Step 4: Run Flutter tests and verify GREEN**
  - Run: `flutter test test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart test/service/api/file_api_test.dart`
  - Expected: PASS.

- [ ] **Step 5: Write failing remote tests**
  - Add Python config test proving Nginx has an exact multipart part location with `proxy_request_buffering off`.
  - Extend Go multipart service tests proving complete rejects missing/short parts.
  - Extend server route to cover `/multipart/parts/:part_no` in code.

- [ ] **Step 6: Run remote tests and verify RED**
  - Run deployment Python test and Go file module tests on remote.
  - Expected: new tests fail before implementation.

- [ ] **Step 7: Implement minimal remote changes**
  - Add Nginx `location = /v1/file/multipart/part` and `location ~ ^/v1/file/multipart/parts/[0-9]+$` with request buffering off.
  - Add route `PUT /multipart/parts/:part_no` while keeping old `/multipart/part`.
  - Track part size, validate total size equals session file size before upload.

- [ ] **Step 8: Run remote tests and verify GREEN**
  - Run: `python3 -m unittest scripts/test_multipart_nginx_config.py -v`
  - Run: Docker Go test for `./modules/file`.

### Task 2: LiveKit Call State and Telemetry Hardening

**Files:**
- Modify: `lib/realtime/call/call_state_machine.dart`
- Modify: `test/realtime/call/call_state_machine_test.dart`
- Modify: `lib/modules/video_call/media/call_media_engine.dart`
- Modify: `lib/modules/video_call/media/livekit_call_media_engine.dart`
- Modify: `test/modules/video_call/livekit_call_media_engine_test.dart`
- Modify: `lib/modules/video_call/call_session_service.dart`
- Modify: `test/modules/video_call/call_session_service_test.dart`
- Modify: `lib/realtime/telemetry/realtime_rollout_telemetry.dart`
- Modify: `test/realtime/telemetry/realtime_rollout_telemetry_test.dart`
- Remote create/modify: `/opt/wukongim-prod/src/modules/extra/call_telemetry.go`
- Remote create/modify: `/opt/wukongim-prod/src/modules/extra/api_call_telemetry_test.go`
- Remote modify: `/opt/wukongim-prod/src/modules/extra/api.go`

- [ ] **Step 1: Write failing Flutter call tests**
  - Add tests that incoming invite maps to public `ringing`, successful media connect advances to `connected`, reconnect events toggle `reconnecting -> connected`, and media failure enters `failed` with structured reason.
  - Add tests that telemetry transport failure does not break call start or mask the original call error.

- [ ] **Step 2: Run Flutter tests and verify RED**
  - Run: `flutter test test/realtime/call/call_state_machine_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/modules/video_call/call_session_service_test.dart test/realtime/telemetry/realtime_rollout_telemetry_test.dart`
  - Expected: FAIL because reconnect/media state streams and call telemetry are missing.

- [ ] **Step 3: Implement minimal Flutter call changes**
  - Add structured call failure reason values.
  - Add media connection state stream to `CallMediaEngine`.
  - Drive `CallStore` to `connected/reconnecting/failed` from media events.
  - Extend `RealtimeRolloutTelemetry` with call event recording that buffers and never throws into call flow.

- [ ] **Step 4: Run Flutter tests and verify GREEN**
  - Run the same targeted Flutter tests.

- [ ] **Step 5: Write failing remote telemetry tests**
  - Add Go tests for `POST /v1/extra/call/telemetry`: accepts valid call events, rejects invalid reason, and aggregates success/failure counts in memory.

- [ ] **Step 6: Run remote tests and verify RED**
  - Run Docker Go test for `./modules/extra`.

- [ ] **Step 7: Implement minimal remote telemetry intake**
  - Add call telemetry validator/store in `modules/extra`.
  - Register `/v1/extra/call/telemetry` behind auth middleware.
  - Keep telemetry errors isolated from existing call room/signal flow.

- [ ] **Step 8: Run remote tests and verify GREEN**
  - Run Docker Go test for `./modules/extra`.

### Task 3: Review and Verification

- [ ] **Step 1: Spec review**
  - Compare implemented behavior against Phase 4.2 and 4.3 requirements.

- [ ] **Step 2: Code quality/security review**
  - Check concurrency races, token leakage, buffering config precedence, and telemetry failure isolation.

- [ ] **Step 3: Full targeted verification**
  - Run local Flutter targeted tests and analyze for changed files.
  - Run remote TS-DD module tests and deployment config tests.

- [ ] **Step 4: Report**
  - Summarize files changed, tests run, remaining deployment notes, and do not print secrets.
