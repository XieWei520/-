# iOS PWA Core Web IM Rewrite Design

## Status

Approved design for the first production-grade rewrite slice of the customer-facing Web IM client.

## Background

The existing customer Web entry point is Flutter Web. Customers use Web as a primary daily product surface, and multiple users report blank screens after long background periods, long foreground sessions, and deep history scrolling. The first rewrite must remove the Canvas/WebGL rendering risk from the customer Web surface, especially for iOS Home Screen PWA users.

Apple documents Web Push support for Home Screen web apps on iOS and iPadOS 16.4 or later, and Apple requires notification permission to be requested from a user gesture. WebKit also documents that a manifest with `display: standalone` or `fullscreen` opens as a Home Screen web app and that iOS/iPadOS 16.4 added Web Push, Badging API, and Manifest ID support for these apps.

References:
- Apple Developer: https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers
- WebKit: https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- WebKit Badging: https://webkit.org/blog/14112/badging-for-home-screen-web-apps/

## Goals

- Build a new customer IM Web PWA that iOS Home Screen PWA customers can use daily instead of Flutter Web.
- Deploy the new client to `/im` or `/web-v2` for controlled customer gray release.
- Preserve existing Android and Windows behavior by keeping current REST, WebSocket, file, and IM protocol behavior compatible.
- Add only small, explicit Web/PWA adapter APIs where the current backend does not provide the required Web capability.
- Make Web Push a first-version acceptance requirement.
- Use DOM-based rendering, virtualized lists, native browser media elements, and IndexedDB instead of Flutter Web canvas rendering.

## Non-Goals

- Full Flutter Web feature parity in the first release.
- Audio or video calling.
- Voice recording and sending.
- Full video message preview.
- Friend requests, group creation, group member management, or complex group settings.
- Full favorites, forwarding, and advanced robot-card parity.
- Rewriting Android or Windows clients.
- Replacing the current Flutter Web homepage before gray-release metrics pass.

## First Release Product Scope

The first release includes:

- iOS Home Screen PWA installation and standalone-window use.
- Phone-number and password login.
- Conversation list with unread counts, last message, pinned state, mute state, and connection status.
- Read-only contacts and group lists.
- Chat entry from conversations, contacts, or groups.
- Text send and receive.
- Image send, thumbnail display, and preview.
- File send, display, download, and preview/open affordance.
- Voice message playback.
- Upward history pagination.
- IndexedDB cache for conversation summaries, recent messages, paged history anchors, media metadata, and drafts.
- WebSocket real-time receive, reconnect, and foreground/background recovery.
- Web Push subscription, server delivery, and notification-click deep link into chat.

## Technology Choice

Create a new independent Vue 3 + TypeScript + Vite application under `web_im/`.

Reasons:

- The existing admin Web project already uses Vue 3, TypeScript, and Vite, so build and deployment knowledge can be reused.
- The customer IM PWA has different authentication, permissions, mobile layout, long-session, and PWA lifecycle needs than the admin console; it should not be mixed into the admin project.
- Vue 3 plus a dedicated virtual list implementation can render message history through native DOM nodes, avoiding Flutter Web CanvasKit/WebGL blank-screen failure modes.

## Deployment Model

- Serve the new client from the same production origin as the existing app.
- Mount the first release at `/im` or `/web-v2`.
- Keep the current Flutter Web entry point available as rollback.
- Configure the PWA manifest, service worker scope, icon paths, offline page, and Web Push subscription flow for the new route.
- Keep static assets cacheable, but ensure `index.html`, service worker, and manifest are deployed with update-safe cache headers.

## Backend Compatibility Boundary

Existing Android, Windows, and Flutter Web endpoints must remain compatible. No existing endpoint may change its default response shape or protocol semantics for old clients.

The rewrite may add Web-specific endpoints for capabilities such as:

- Web Push VAPID config and subscription registration.
- PWA client state reporting, including visibility, standalone status, notification permission, endpoint, and user agent.
- Batch Web summaries for contacts, groups, and conversation metadata when existing endpoints are too chatty for mobile Web.
- Optional Web diagnostics and long-session telemetry.

New endpoints should use an explicit namespace such as `/v1/web/*`, or existing explicit Web Push endpoints where already present. Any new fields on existing responses must be additive and safe for old clients.

## Client Architecture

The client is organized into focused modules:

- `app`: router, route guards, app shell, PWA lifecycle integration.
- `auth`: phone/password login, token persistence, current-user load, logout.
- `api`: typed REST client, endpoint adapters, error normalization.
- `im`: WebSocket session, reconnect policy, message send queue, sync orchestration.
- `store`: Pinia stores for auth, conversations, contacts, groups, chat viewport, and connectivity.
- `db`: IndexedDB repositories and migrations.
- `push`: service worker registration, permission prompt, subscription lifecycle, notification-click handling.
- `features/conversations`: conversation list UI and reducers.
- `features/contacts`: read-only contacts and groups UI.
- `features/chat`: chat page, virtual message list, composer, media messages, read markers.
- `features/me`: account, PWA, notification status, and logout.

## Data Flow

After login:

1. The client stores the user token and device identity.
2. It loads the current user.
3. It opens or resumes IndexedDB caches.
4. It fetches conversation sync data through the existing sync API.
5. It opens the IM WebSocket connection.
6. It renders cached conversations immediately, then reconciles with backend-authoritative state.
7. It registers or refreshes Web Push subscription from a user-triggered notification setup action.

Message receive:

1. WebSocket receives a message or event.
2. The event is normalized into a typed message model.
3. The in-memory conversation/message stores update.
4. IndexedDB persists the conversation summary and affected message page.
5. Visible chat routes update through DOM virtual list state.
6. If sequence gaps are detected, the client runs incremental sync.

Message send:

1. Composer creates a local pending message with a client message id.
2. The message is queued in memory and IndexedDB.
3. The WebSocket or existing send path sends the message.
4. Server ack reconciles sequence, message id, timestamp, and status.
5. Failure leaves a visible retry affordance.

History pagination:

1. The chat viewport keeps a top anchor message and offset.
2. Upward scroll requests older messages from IndexedDB first.
3. Cache misses call `/v1/message/channel/sync` or the existing history endpoint.
4. DOM virtual list prepends rows while preserving the visual anchor.

## PWA Lifecycle

The app handles:

- `visibilitychange`, `pagehide`, `pageshow`, `online`, and `offline`.
- Foreground resume by checking WebSocket state, syncing sequence gaps, and restoring the current chat anchor.
- Background transition by flushing send queue and important state to IndexedDB.
- Standalone detection to distinguish Home Screen PWA from normal Safari.
- Safe-area and keyboard behavior for iOS bottom composer.

The app must not rely on canvas state for core UI. A lost rendering context cannot blank the full app because the UI is normal DOM.

## Web Push Design

Web Push is required for first release.

Frontend requirements:

- Register a service worker under the new PWA route scope.
- Fetch VAPID public key from backend config.
- Request notification permission only after a user taps a clear notification setup control.
- Subscribe through `PushManager`.
- Send subscription endpoint and keys to backend.
- Handle `push`, `pushsubscriptionchange`, and `notificationclick`.
- Deep link notification clicks to `/im/chat/:channelType/:channelId`.
- Feature-detect badge APIs and update unread badge when supported.
- Show explicit unsupported states for non-standalone iOS Safari or unsupported browsers.

Backend requirements:

- Persist subscription by user, device identity, endpoint, and user agent.
- Remove invalid endpoints after failed push responses.
- Send push for new messages when the Web client is not active or connection state is stale.
- Include channel id, channel type, message id, title, body, and click target in push payload.
- Avoid exposing message secrets in notification body when the message type is unsupported or privacy settings require a generic notification.

## UI Information Architecture

Mobile-first routes:

- `/im/login`: phone/password login, PWA status, notification setup status.
- `/im/conversations`: conversation list, connection state, search entry.
- `/im/contacts`: read-only contacts and groups.
- `/im/chat/:channelType/:channelId`: chat title, status, virtual message list, composer.
- `/im/me`: account, PWA install state, notification state, logout.

Desktop-compatible layout:

- A wider viewport may use a three-pane layout: conversations, chat, and details/empty state.
- Desktop support is useful, but iOS PWA is the first acceptance target.

UI principles:

- No marketing landing page. Open to login or the IM workspace.
- Every async state has visible loading, empty, error, retry, and reconnect states.
- Message rows have stable dimensions where possible; media reserves layout space before load.
- Long text, file names, and status labels wrap safely on narrow iPhone viewports.
- Composer stays above the iOS Home indicator and keyboard.

## Reliability Acceptance Criteria

- iOS Home Screen PWA can log in, send and receive text, send and preview images, send and preview files, and play voice messages.
- The app runs in foreground for 8 hours without blank screen or unrecoverable interaction loss.
- The app resumes after 2 hours in background and can reconnect, sync missed messages, and preserve the active chat route.
- A chat can scroll through at least 2,000 historical messages without full-page blanking, composer loss, or conversation mismatch.
- WebSocket reconnect fills message gaps through incremental sync.
- Web Push subscription works on iOS Home Screen PWA, receives notifications, and opens the correct conversation.
- Existing Android and Windows contract tests pass.
- The new route can be disabled or rolled back without redeploying old clients.

## Testing Strategy

Unit tests:

- Message payload parsing and fallback rendering.
- Conversation reducer and unread reconciliation.
- Send queue state transitions.
- IndexedDB repository reads, writes, pagination, and schema migration.
- Web Push payload parsing and notification target resolution.

Component tests:

- Conversation list rows.
- Chat virtual list anchor preservation.
- Composer send state and retry state.
- Image, file, and voice message components.
- PWA and notification status surfaces.

End-to-end tests:

- Login and session restore.
- Conversation sync and chat route open.
- History scroll and anchor preservation.
- Text/image/file send flow.
- WebSocket disconnect and reconnect recovery.
- Service worker notification-click routing.
- iOS-sized viewport safe-area and keyboard layout checks.

Contract tests:

- Existing login, conversation sync, channel sync, message read, clear unread, and file upload interfaces keep old response shapes.
- New Web/PWA endpoints are additive and do not alter old Android/Windows behavior.

Long-session tests:

- Foreground idle and periodic message receive.
- Background/resume simulation.
- Deep history scroll with media rows.
- IndexedDB restore after reload.

## Migration Plan

Phase 1: Build the PWA shell and fake-data UI to validate routing, mobile layout, virtual list stability, IndexedDB schema, and service worker registration.

Phase 2: Connect real phone/password login, current user, conversation sync, contacts, groups, and history read.

Phase 3: Connect WebSocket, text send, image send, file send, voice playback, read markers, and retry states.

Phase 4: Connect Web Push, notification permission setup, backend subscription lifecycle, notification-click routing, badge state, and PWA resume telemetry.

Phase 5: Deploy to `/im` or `/web-v2` for small-customer gray release. Compare blank-screen reports, reconnect success, push delivery, scroll stability, send success, and crash/error telemetry against Flutter Web.

Phase 6: Expand gray release and prepare a controlled homepage switch only after acceptance metrics pass.

## Open Decisions Resolved

- First version excludes audio/video calls.
- First version uses phone/password login first.
- Backend may add small Web-specific adapter APIs.
- Android and Windows must not be affected.
- iOS Home Screen PWA users are the priority.
- Web Push is a first-release acceptance requirement.
- Delivery target is daily-use replacement quality for iOS PWA gray customers, not full parity.
