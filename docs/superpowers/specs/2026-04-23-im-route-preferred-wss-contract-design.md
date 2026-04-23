# IM Route Preferred WSS Contract Design

**Date:** 2026-04-23

**Goal:** Turn `/v1/users/{uid}/im` into a formal multi-transport contract and
enable the Flutter client to truly prefer `wss_addr`, while preserving backward
compatibility for older clients that still consume `tcp_addr`.

## Design Summary

The current system advertises multiple IM route fields from the server, but the
Flutter app only reads `tcp_addr` and the bundled WuKongIM Flutter SDK only
supports `host:port` TCP socket addresses. That means the current production
route payload can expose `wss_addr`, but the client cannot actually use it.

This slice formalizes the route contract across three layers:

1. The server endpoint `/v1/users/{uid}/im` stops acting as an untyped proxy
   and instead returns an explicit, documented response schema.
2. The Flutter app parses that response into a structured route model and
   applies deterministic transport selection rules.
3. The local WuKongIM Flutter SDK gains `ws://` and `wss://` transport support
   so the preferred secure route can be used in production.

The design keeps `tcp_addr`, `ws_addr`, and `wss_addr` for compatibility, and
adds `preferred_transport` plus `preferred_addr` so transport priority can be
controlled server-side without forcing each client to infer it independently.

## Confirmed Current State

- `lib/service/api/im_sync_api.dart`
  - `fetchUserConnectAddr()` returns only `tcp_addr`
- `lib/service/im/im_service.dart`
  - `_resolveConnectAddr()` receives a single address string and passes it into
    the SDK setup flow
- `../TangSengDaoDao/WuKongIMFlutterSDK-master/lib/manager/connect_manager.dart`
  - `_socketConnect()` splits the address by `:` and calls `Socket.connect`
  - no `ws://` or `wss://` transport support exists today
- Remote server `modules/user/api.go`
  - `userIM()` currently proxies `WuKongIM.APIURL/route?uid=...` and returns
    the upstream JSON body without schema validation or response shaping
- Remote server `modules/user/swagger/api.yaml`
  - `/users/{uid}/im` exists, but its `200` response is documented only as
    `type: object` with no field definitions

## Approaches Considered

### Recommended: Formal route contract plus real client transport support

- Add a documented `/v1/users/{uid}/im` response schema
- Keep compatibility fields and add `preferred_*` fields
- Parse the route into a dedicated Flutter model
- Teach the local SDK to connect through TCP, WS, or WSS based on address form

Why this approach:

- It is the only option that makes "client prefers `wss_addr`" a true runtime
  behavior rather than a documentation claim.
- It centralizes transport preference on the server while keeping older clients
  working through `tcp_addr`.
- It limits risk by confining transport-specific logic to the SDK connection
  layer instead of spreading it through the app.

### Rejected: Document `wss_addr` preference but keep Flutter on `tcp_addr`

This preserves stability but does not satisfy the requirement. The contract
would say the client prefers `wss_addr`, while the actual shipped app would
still open TCP sockets.

### Rejected: Hard-switch Flutter to `wss_addr` without changing the SDK

The current SDK cannot consume `wss://...` addresses. Feeding a secure websocket
URI into the current socket-only connector would fail immediately.

## Target Contract

`GET /v1/users/{uid}/im` returns a fixed `200` response shape:

```json
{
  "tcp_addr": "wemx.cc:5100",
  "ws_addr": "ws://wemx.cc:5200",
  "wss_addr": "wss://wemx.cc/ws",
  "preferred_transport": "wss",
  "preferred_addr": "wss://wemx.cc/ws"
}
```

Field rules:

- `tcp_addr`
  - compatibility field for existing socket-based clients
  - format: `host:port`
- `ws_addr`
  - cleartext websocket route
  - format: full `ws://` URI
- `wss_addr`
  - TLS websocket route
  - format: full `wss://` URI
- `preferred_transport`
  - enum: `wss`, `ws`, `tcp`
  - expresses server-recommended transport
- `preferred_addr`
  - concrete address matching `preferred_transport`
  - avoids repeated client-side guessing

Normalization rules:

- Missing addresses are returned as empty strings, never `null`
- Invalid upstream values are normalized to empty strings before responding
- `preferred_transport` must align with `preferred_addr`; otherwise the server
  must downgrade to the best valid available transport

## Client Selection Rules

The Flutter app resolves the connect address in this order:

1. Use `preferred_addr` when `preferred_transport` is valid and the address
   matches the expected format.
2. Otherwise use `wss_addr` if valid.
3. Otherwise use `ws_addr` if valid.
4. Otherwise use `tcp_addr` if valid.
5. Otherwise fall back to `IMConfig.connectAddr`.

Validation rules:

- `tcp_addr` is valid only when it parses as `host:port`
- `ws_addr` is valid only when it parses as a `ws://` URI
- `wss_addr` is valid only when it parses as a `wss://` URI
- whitespace-only strings are treated as missing

This allows the server to shift preferred transport over time without forcing a
new client release for every policy change.

## Architecture And Component Boundaries

### Server

Remote file targets:

- `/opt/wukongim-prod/src/modules/user/api.go`
- `/opt/wukongim-prod/src/modules/user/swagger/api.yaml`
- related `modules/user/*_test.go`

Responsibilities:

- fetch upstream route data from WuKongIM
- normalize it into the formal response schema
- guarantee stable response keys and transport preference rules
- document the response in swagger

The endpoint should stop returning upstream JSON verbatim. It should shape the
response explicitly so future upstream route changes do not silently alter the
public contract.

### Flutter App

Repo file targets:

- `C:\Users\COLORFUL\Desktop\WuKong\lib\service\api\im_sync_api.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\service\im\im_service.dart`
- related tests under `test/service/api` and `test/service/im`

Responsibilities:

- parse `/v1/users/{uid}/im` into a dedicated `ImRouteInfo` model
- validate transport-specific fields
- choose the best usable address using the fixed fallback rules
- keep business code unaware of socket vs websocket connection details

The app layer should not operate on raw response maps once parsing is complete.

### Local SDK

Local dependency target:

- `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\manager\connect_manager.dart`

Responsibilities:

- detect whether the chosen address is TCP, WS, or WSS
- keep existing packet framing, heartbeats, ACK handling, and reconnect logic
- swap only the underlying transport connector

The transport layer should expose one unified send/listen lifecycle so the rest
of the SDK continues to operate on bytes and packet semantics.

## Data Flow

1. Flutter app requests `/v1/users/{uid}/im`
2. Server fetches the upstream WuKongIM route payload
3. Server normalizes the payload into the formal response schema
4. Flutter parses the response into `ImRouteInfo`
5. Flutter selects the best address using `preferred_*` then fallback rules
6. The selected address is passed to the SDK
7. SDK opens either:
   - a TCP socket for `host:port`
   - a websocket for `ws://...`
   - a TLS websocket for `wss://...`
8. Existing IM packet exchange, ACK, heartbeat, reconnect, and sync flows
   continue on top of the chosen transport

## Error Handling

Server-side:

- if the upstream route request fails, preserve the current endpoint failure
  behavior and return an error response rather than an incomplete contract
- if upstream fields are malformed, normalize them to empty strings before
  calculating the preferred transport

Client-side:

- if `preferred_addr` is invalid, ignore it and continue the fallback chain
- if all remote addresses are unusable, fall back to `IMConfig.connectAddr`
- malformed remote data must not crash initialization

SDK-side:

- invalid or unsupported address formats should fail deterministically and feed
  the existing connection failure path
- reconnect behavior should stay transport-agnostic where possible

## Testing Strategy

### Server Tests

- add handler-level tests for `/v1/users/{uid}/im`
- verify the response always includes the fixed fields
- verify `preferred_transport` and `preferred_addr` are derived correctly
- verify missing or malformed upstream values normalize to empty strings
- update swagger to document the exact response schema

### Flutter App Tests

- extend `test/service/api/im_sync_api_test.dart`
  - parse full route responses into a structured route object
- extend `test/service/im/im_service_test.dart`
  - prefer `preferred_addr`
  - fall back from invalid `preferred_addr` to `wss_addr`
  - fall back from `wss_addr` to `ws_addr`
  - fall back from `ws_addr` to `tcp_addr`
  - fall back to `IMConfig.connectAddr` when all remote values are unusable

### SDK Tests

- validate address-type detection for TCP, WS, and WSS
- verify websocket transports still feed packet bytes into the existing decode
  path
- verify connection failures continue to trigger the existing reconnect path

## Rollout And Compatibility

- Old clients remain compatible through `tcp_addr`
- New clients can immediately prefer `wss_addr` when available
- The server can switch the recommended transport at runtime by changing
  `preferred_transport` and `preferred_addr`
- If a transport-specific issue appears after rollout, the server can downgrade
  preference to `tcp` or `ws` without a mandatory client release

## Non-Goals

- Do not redesign the IM packet protocol itself
- Do not change message payload formats or ACK semantics in this slice
- Do not remove `tcp_addr` from the contract
- Do not make unrelated server deployment or database changes as part of the
  route-contract implementation
