# Realtime Rollout Preflight Report

Updated: 2026-04-17 18:36 (Asia/Shanghai)

## 1. Decision

- Decision: `HOLD`
- Reason: the backend rollout controller and telemetry ingest chain are still safely deployed at `0%`, and an internal Android release APK can now be built locally, but Step 2 gray rollout still cannot start because the Phase 1 internal cohort is not yet frozen and the production rollout telemetry stream still has no real client data.

## 2. Production Metadata

Current deployed backend metadata:

- `BUILD_VERSION=prod-20260417-rollout-preflight`
- `BUILD_COMMIT=task7-rollout-telemetry-20260417`
- `BUILD_COMMIT_DATE=2026-04-17`
- `BUILD_TREE_STATE=manual-sync`

Current production rollout control:

- `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON={"hash_salt":"20260417-rollout","internal_uids":[],"internal_percent":0,"android_external_percent":0,"mobile_external_percent":0,"all_percent":0}`

Interpretation:

- Production is currently in a safe `0%` rollout posture.
- Server-side protocol negotiation is now deployment-scoped and env-driven.
- New websocket sessions continue to fall back to JSON because no cohort is currently enabled.

Observed production state:

- `/opt/wukongim-prod/src` is still not a git checkout, so build provenance is improved by explicit `BUILD_*` metadata but is not yet tied to immutable git history.
- `tsdd-api` and `callgateway` now run from the same rebuilt `wukongim/tsdd-api:production-local` image and both are healthy.

## 3. Verification Evidence Collected

Operator workstation / local Flutter evidence:

- `flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/realtime/session/session_runtime_test.dart test/realtime/session/session_event_gateway_test.dart test/data/providers/conversation_provider_telemetry_test.dart`: PASS (`34/34`)
- `flutter test test/service/api/im_sync_api_test.dart`: PASS (`4/4`)
- `dart analyze lib/realtime/telemetry/realtime_rollout_telemetry.dart lib/realtime/session/session_runtime.dart lib/realtime/session/session_event_gateway.dart lib/data/providers/conversation_provider.dart lib/service/im/im_service.dart test/service/api/im_sync_api_test.dart`: PASS
- `flutter build apk --release --target-platform android-arm64`: PASS
  - Artifact: `build/app/outputs/flutter-apk/app-release.apk`
  - Size: `74251761` bytes (`70.8 MB`)
  - Verified APK contents include `arm64-v8a`, `armeabi-v7a`, and `x86_64` native libraries.
  - Verified signing remains debug-only (`CN=Android Debug`), so this artifact is suitable only for tightly controlled internal sideloading, not store or formal channel release.

Remote backend evidence collected in a disposable `golang:1.20` container mounted on `/opt/wukongim-prod/src`:

- `gofmt -w modules/user/api_session_compat.go modules/user/api_session_delta.go modules/user/api_session_rollout_helpers.go modules/user/api_session_rollout_test.go modules/user/api_session_telemetry_test.go`: PASS
- `go test -v -count=1 ./modules/user -run "TestSessionCompat|TestNegotiateSessionControlProtocol_UsesRolloutCohorts|TestSummarizeProtoRolloutStatus_ComputesEligibleAndEnabledCounts|TestSummarizeRolloutTelemetryWindow_ComputesFixedKPIsAndGuards|TestLoadProtoControlRolloutSpecFromEnvJSON"`: PASS

Runtime verification after production deploy:

- `docker compose --env-file .env ps`: PASS
- `python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10`: PASS
- `python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10`: PASS
- `POST /v1/realtime/session/rollout/telemetry` without auth returns `401`: PASS, confirms the new route is mounted and protected by auth middleware.

Measured probe output after deploy:

- `setting_avg_ms = 1.98`
- `setting_p95_ms = 3.59`
- `favorites_avg_ms = 1.68`
- `favorites_p95_ms = 2.92`

## 4. Rollback Target Captured

Previously captured immutable rollback artifacts remain valid for immediate backend rollback:

- Source snapshot: `/opt/wukongim-prod/rollback_snapshots/20260417_115151/src.tar.gz`
- Source snapshot SHA-256: `f73f032e0af44fa0f9a7cfddfc0122f337db57fc87901bf49f076404c8ccfc53`
- Rollback manifest: `/opt/wukongim-prod/rollback_snapshots/20260417_115151/manifest.txt`
- `tsdd-api` rollback image tag: `wukongim/tsdd-api:rollback-tsdd-20260417_115151`
- `callgateway` rollback image tag: `wukongim/tsdd-api:rollback-callgateway-20260417_115151`

Additional operator backups captured before this deployment:

- Remote source backup directory: `/opt/wukongim-prod/task7_backup_20260417_124743/modules/user`
- Production env backup: `/opt/wukongim-prod/src/deploy/production/.env.task7_before_20260417_125658`

## 5. Production Readiness Checks

Executed against the production host after deploying the new backend:

- `docker compose --env-file .env ps`: PASS
- `python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10`: PASS
- `python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10`: PASS
- `docker compose --env-file .env logs --since=5m tsdd-api callgateway | tail -n 200`: PASS, no crash loop and no decode storm observed

Operational notes:

- The production deploy was intentionally applied with `0%` rollout enablement to keep all clients on JSON while rollout control and telemetry plumbing were verified.
- The telemetry Redis stream currently reports `ZCARD realtime_rollout:telemetry = 0`, which means no real rollout telemetry samples have been ingested yet since the deploy.
- Re-check at 18:36 confirms production metadata and rollout spec are unchanged, and `docker compose --env-file .env ps` still shows `tsdd-api` and `callgateway` healthy.

## 6. KPI Baseline Availability

| KPI | Baseline status | Evidence / current state |
|---|---|---|
| `gateway_connect_success_rate` | Capability wired, baseline still unavailable | Backend now records connect attempt/success events, but the production telemetry stream is still empty after deploy. |
| `gateway_reconnect_count` | Unavailable for rollout decision | Client telemetry transport exists in code but is not yet distributed in a production app build, so no live reconnect series exists. |
| `control_frame_decode_error_count` | Unavailable for rollout decision | Client-side decode error telemetry exists in code but is not yet live in production app traffic. |
| `pull_after_seq_repair_count` | Capability wired, baseline still unavailable | Backend pull path now records repairs, but no post-deploy samples are present yet. |
| `sqlite_page_query_p95_ms` | Blocked on client build rollout | Metric is now emitted by app code, but no production client build is sending it yet. |
| `conversation_list_patch_apply_p95_ms` | Blocked on client build rollout | Metric is now emitted by app code, but no production client build is sending it yet. |

Derived guard denominators are not yet usable in production:

- `inbound_control_frame_count`: no live rollout telemetry samples yet
- `successful_gateway_connect_count`: capability wired, but no live samples yet
- `active_realtime_session_count`: client heartbeat metric is implemented but not yet live in production app traffic

Additional client status as of 13:45:

- The local source tree now wires `sqlite_page_query_p95_ms` and `conversation_list_patch_apply_p95_ms` into the default Riverpod provider path, and the provider regression tests pass locally.
- That fix is not yet present in any distributed production app build, so production KPI availability remains unchanged until a new client release is delivered to real users.

Additional client status as of 18:36:

- The workstation can now produce an Android release artifact after applying local plugin/workstation compatibility fixes for mirror-aware Gradle repositories, legacy Flutter v1 embedding remnants, AGP/Kotlin compatibility, desugaring, and local CMake discovery.
- The successful artifact was built without `google-services.json`, so the Android `google-services` plugin is now conditionally applied only when Firebase config files exist. This unblocks internal test packaging, but Firebase/FCM runtime behavior remains effectively disabled until a real Android Firebase config is supplied.
- The current release build is still signed with the debug keystore, and the repo still has no internal distribution automation or formal release keystore wiring.

## 7. Gray Rollout Capability Check

Result: `BLOCKED`

What is now ready:

- A server-side cohort/percentage rollout controller exists via `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON`.
- Protocol negotiation now executes on the backend instead of trusting the client request alone.
- The client code now batches and uploads rollout telemetry to `/v1/realtime/session/rollout/telemetry`.
- The backend can persist rollout telemetry and summarize the fixed KPI / guard windows.

What is still blocking Phase 1:

- `internal_uids` is still empty, so the Phase 1 internal cohort is not frozen.
- The production app build that contains telemetry POST transport has still not been released to real users, so the KPI stream has no samples.
- Although the workstation can now build an APK, the current Android release config still signs with the debug keystore, the artifact is only suitable for manual internal sideloading, and the repo does not contain an internal distribution automation path.
- The current internal artifact was built without `google-services.json`, so Android FCM is not ready for production use until the real Firebase config is supplied.
- Because the KPI stream is empty, Step 1 baseline capture for the six rollout KPIs cannot be completed.

Consequence:

- Step 2 cannot safely proceed to `10% internal users`.
- Step 3 monitoring guards cannot yet be evaluated with real production samples.
- Step 4 rollback remains prepared and executable, but should not be exercised unless a later non-zero rollout deploy regresses.

## 8. Required Next Work Before Any Real Gray Rollout

1. Freeze the Phase 1 internal cohort and populate `internal_uids` in `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON`.
2. Distribute the newly built telemetry-capable client release to real internal users, or rebuild it with the production Android Firebase config if FCM is required during internal testing.
3. Replace the debug-signing path with a real Android internal/release signing configuration and document the manual or automated internal distribution channel.
4. Wait for real telemetry samples to appear in `realtime_rollout:telemetry`, then capture fresh baseline values for all six KPIs and the three denominator series.
5. Only after Steps 1-4 are complete, change the rollout spec from `0%` to `10% internal` and start the Phase 1 monitoring window.
