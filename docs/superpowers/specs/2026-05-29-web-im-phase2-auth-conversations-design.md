# Web IM Phase 2 Auth And Conversations Design

## Status

Approved design for Phase 2 planning. This phase connects the independent `web_im/` PWA to real authentication and read-only conversation sync while keeping Android, Windows, and the existing Flutter client untouched.

## Background

Phase 1 created a standalone Vue 3 + TypeScript + Vite Web IM PWA under `web_im/` with fake login, fake conversations, fake chat, IndexedDB boundaries, PWA shell, service worker, iOS touch icon, and smoke tests.

The next risk to retire is whether the new DOM-based Web client can authenticate against the real production backend and display a real user's conversation list without depending on Flutter Web canvas rendering. This must be done as a narrow, reversible slice before adding WebSocket, send-message, media, or push behavior.

## Goals

- Replace Phase 1 fake login with real phone/password login against `/v1/user/login`.
- Persist real `uid`, `token`, optional `im_token`, current user, and selected API base URL in Web-local storage.
- Load current user details from `/v1/users/{uid}` after login and during session restore.
- Load a read-only conversation list from `/v1/conversation/sync`, matching the existing Flutter Web fallback path.
- Map real conversation sync rows into the existing `Conversation` UI model.
- Keep the fake-data mode available for local development and Playwright smoke tests.
- Keep all Phase 2 changes scoped to `web_im/`, docs, and release wiring only if needed.
- Do not modify Android, Windows, or existing Flutter runtime behavior.

## Non-Goals

- WebSocket connection and reconnect handling.
- Sending text, image, file, voice, or any other message to the real backend.
- Real message history pagination.
- Contacts and groups real-data integration.
- Web Push registration or notification delivery.
- Replacing the current production Flutter Web entry point.
- Any backend schema migration or endpoint behavior change.

## Runtime Mode

The Web IM client has two runtime modes:

- `mock`: current Phase 1 behavior, using fake login, fake conversations, and fake chat messages.
- `live`: real HTTP login, current user, and conversation sync.

Mode is controlled by Vite environment configuration:

- `VITE_WK_WEB_IM_MODE=mock|live`
- `VITE_WK_API_BASE_URL=https://infoequity.cn`

If `VITE_WK_WEB_IM_MODE` is absent, the app defaults to `mock`. This preserves existing tests and avoids accidentally pointing local development builds at production. A production gray-release build can explicitly set `live`.

## API Compatibility

Phase 2 uses existing backend endpoints only:

- `POST /v1/user/login`
- `GET /v1/users/{uid}`
- `POST /v1/conversation/sync`

No existing endpoint response shape changes. Android and Windows continue using their existing clients and request paths.

## HTTP Signing

The Web client mirrors the Flutter HTTP signing contract:

- `appid`: `wukongchat`
- `timestamp`: current Unix milliseconds as a string
- `noncestr`: 16-character nonce
- `sign`: MD5 digest of `body + noncestr + timestamp + appKey`
- `token`: included when authenticated
- `Content-Type`: `application/json`
- `Accept`: `application/json`

The app key defaults to the existing Flutter value, `25b002c6be2d539f264c`, via `VITE_WK_APP_KEY`. The value is already public in the existing client and is used as a request-signing compatibility key, not as a server-side secret.

For login, the body must be serialized once and signed as the exact request body string. For object requests, the Web client serializes the payload to JSON before signing and sending.

## Login Flow

Phone login:

1. User enters phone and password.
2. The client normalizes zone `86` to `0086`.
3. The client posts:

```json
{
  "username": "0086{phone}",
  "password": "{password}",
  "flag": 5,
  "device": {
    "device_id": "{webDeviceId}",
    "device_name": "Web PWA",
    "device_model": "{userAgent-derived model}",
    "device_install_id": "{stable install id}"
  }
}
```

4. A successful response must include non-empty `uid` and `token`, either under `data` or as direct fields.
5. `im_token` is stored when present; otherwise `token` is used as the IM token fallback.
6. The client fetches `/v1/users/{uid}` to hydrate the display user.
7. The app routes to `/conversations` and loads conversations.

Login failure:

- Response `code !== 0` shows `msg` or `message` from the backend.
- HTTP 401/403 clears stored auth and returns to login.
- Network failures show a retryable error and do not persist partial credentials.
- Login verification code `110` is not implemented in this phase; it displays a clear unsupported message.

## Session Restore

On app startup:

1. Read stored auth snapshot from localStorage.
2. If `uid` or `token` is missing, stay logged out.
3. If both exist, set in-memory auth immediately.
4. Fetch `/v1/users/{uid}` to validate and refresh user details.
5. If validation fails with unauthorized/session-expired status, clear auth and route to login.
6. If validation fails due to network, keep the stored session visible but mark it as offline/degraded.

This allows iOS PWA users to reopen the app without a blank screen during temporary network loss.

## Conversation Sync Flow

The read-only conversation list uses the same remote sync path already used by Flutter Web:

```json
{
  "version": 0,
  "last_msg_seqs": "",
  "msg_count": 200,
  "device_uuid": "{webDeviceId}"
}
```

The client reads `data.conversations` or top-level `conversations`. Each row maps to:

- `channel_id` -> `Conversation.channelId`
- `channel_type` -> `Conversation.channelType`
- `unread` -> `Conversation.unreadCount`
- `timestamp` or latest recent message timestamp -> `Conversation.lastMessageAt`
- latest displayable `recents[]` message -> `Conversation.lastMessage`
- `last_msg_seq` and `last_client_msg_no` retained for future Phase 3 history/send reconciliation

Rows with empty `channel_id` or unsupported `channel_type` are ignored.

## Message Summary Mapping

Phase 2 only needs a safe text summary for conversation rows.

The mapper supports:

- text payloads: `payload.content`, `payload.text`, or string payload body
- image payloads: `[图片]`
- file payloads: `[文件]`
- voice payloads: `[语音]`
- revoked/deleted/unsupported payloads: `[不支持的消息]`

The mapper must tolerate malformed JSON, missing payloads, numeric strings, and unknown message types without throwing. Bad rows are skipped or rendered with fallback text.

## Storage

Use small, explicit localStorage keys under a Phase 2 namespace:

- `wk_web_im_auth_v1`
- `wk_web_im_device_v1`
- `wk_web_im_api_base_url_v1`

The auth snapshot contains:

- `uid`
- `token`
- `imToken`
- `user`
- `savedAt`

Storage failures are non-fatal. Login can continue in memory if localStorage is blocked by iOS private or locked-down contexts. Logout always clears in-memory state even if storage removal fails.

IndexedDB keeps the existing Phase 1 repository boundary. Conversation sync writes real conversations by `uid` so cached data remains user-scoped.

## UI Changes

Login page:

- Switch submit handler to async auth store login.
- Keep mobile-first layout.
- Show backend errors in the existing form error region.
- Keep default demo credentials only in mock mode.

Conversation page:

- Read conversations from the chat/conversation store instead of importing `fakeConversations` directly.
- Show loading, empty, error, and retry states.
- Open existing `/chat/:channelType/:channelId` route.
- In live mode, chat route remains a read-only/fake-message placeholder until Phase 3. The header should not imply real send support.

Me page:

- Display real user name, phone, uid, and connection state from auth store when live.
- Logout clears auth and cached in-memory state.

## Error Handling

Use a typed `ApiError` shape:

- `status`
- `code`
- `message`
- `retryable`
- `unauthorized`

Unauthorized errors clear auth. Retryable network errors keep the session and expose a retry action. Backend validation errors stay on the current form or list.

## Testing Strategy

Unit tests:

- HTTP signed header generation is deterministic under fixed timestamp and nonce.
- Login request serializes and signs the exact JSON body sent.
- Login response parser supports `data` and direct response shapes.
- Current-user parser maps `uid`, `name`, `avatar`, `phone`, and fallback fields.
- Conversation sync parser maps real rows, skips invalid rows, and produces safe message summaries.
- Auth storage survives localStorage read/write/remove failures.
- Auth store clears credentials on unauthorized session restore.

Component/store tests:

- Login page calls async login and navigates on success.
- Conversation page renders loading, empty, error, retry, and loaded states.

E2E tests:

- Existing mock-mode smoke tests continue to pass.
- A new mocked-live Playwright path intercepts `/v1/user/login`, `/v1/users/{uid}`, and `/v1/conversation/sync`, then verifies real-mode login and conversation rendering.

Build verification:

- `pnpm --dir web_im test`
- `pnpm --dir web_im build`
- `pnpm --dir web_im e2e`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/build_web_im_release.ps1`
- `flutter test test/scripts/ops/web_im_release_build_test.dart`

## Acceptance Criteria

- `web_im` can run in mock mode with all Phase 1 tests still passing.
- `web_im` can run in live mode and authenticate a real account through the existing signed login contract.
- A restored live session validates against `/v1/users/{uid}`.
- The conversation list renders backend conversation sync rows without fake conversation imports.
- Network and unauthorized failures do not blank the app.
- No Android, Windows, or existing Flutter app files are changed.
- The final build artifact remains an independent `/im/` PWA.

## Rollback

Phase 2 remains isolated behind `/im/` and the `live` runtime mode. Rollback options:

- Build/deploy with `VITE_WK_WEB_IM_MODE=mock`.
- Hide or disable the `/im/` route in production entry configuration.
- Serve the previous Phase 1 or existing Flutter Web bundle.

No database rollback is required because Phase 2 does not change backend storage or schemas.
