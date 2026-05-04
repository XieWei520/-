# Realtime Baseline Capture Template

Use this template before and after any realtime/session rollout change.

## 1. Change Metadata

- Date:
- Owner:
- Task/PR:
- Environment (local/staging/prod):
- Build/version:
- Scope (what changed):

## 2. Baseline Verification

Run and record exact output summary:

```powershell
flutter test test/realtime/control/control_proto_codec_test.dart test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart test/service/im/im_service_test.dart
dart analyze lib/realtime/session/session_runtime.dart test/realtime/session/session_runtime_test.dart lib/service/im/im_service.dart test/service/im/im_service_test.dart
```

- Test result:
- Analyze result:
- Known pre-existing warnings/infos:

## 3. Runtime Observability Snapshot

Capture from `SessionRuntime.snapshot`:

- `retryAttempt`:
- `lastAckedSeq`:
- `lastReceivedSeq`:
- `gatewayDegradedSince`:

Optional notes:
- Expected retry/backoff behavior observed:
- Any seq gap (`lastReceivedSeq - lastAckedSeq`):

## 4. Protocol Negotiation / Kill Switch Check

Record current realtime control protocol mode and fallback plan:

- Query param sent (`control_protocol`):
- Header sent (`X-Realtime-Control-Protocol`):
- Current default mode:
- Kill switch action if degradation occurs:
- Owner for switch decision:

## 5. Rollout Decision

- Decision: `GO` / `HOLD` / `ROLLBACK`
- Reason:
- Follow-up actions:
- Next verification time:
