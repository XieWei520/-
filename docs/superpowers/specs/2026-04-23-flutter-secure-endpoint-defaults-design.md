# Flutter Secure Endpoint Defaults Design

**Date:** 2026-04-23

**Goal:** Remove the Flutter client's baked-in dependency on the production raw
IP and insecure HTTP/WebSocket defaults, while preserving existing runtime
override behavior and avoiding backend protocol changes in this slice.

## Design Summary

The current client still ships with:

- `http://42.194.218.158` as both dev and prod API base URL defaults
- `42.194.218.158:5100` as both dev and prod IM route defaults
- realtime session gateway URLs derived from `ApiConfig.baseUrl`, which means
  the session event stream defaults to `ws://42.194.218.158/...`

This slice hardens only the Flutter-side defaults:

1. Change the default API base URL to `https://wemx.cc`
2. Change the default IM bootstrap address away from the raw IP to the domain
   host `wemx.cc:5100`
3. Keep the persisted login API base URL override intact
4. Preserve all existing call-site behavior that derives `wss://` session URLs
   from an `https://` base URL

The intent is to stop fresh installs and unconfigured builds from preferring
plaintext endpoints, without changing the server routing contract or the IM SDK
bootstrap semantics in the same patch.

## Confirmed Current State

- `lib/core/config/api_config.dart`
  - `devBaseUrl` and `prodBaseUrl` default to `http://42.194.218.158`
  - `devWsAddr` and `prodWsAddr` default to `42.194.218.158:5100`
- `lib/service/im/im_service.dart`
  - `buildSessionGatewayUri()` maps an `https` base URL to `wss`
- `lib/service/api/im_sync_api.dart`
  - IM route discovery still reads `tcp_addr` from `/v1/users/{uid}/im`

## Approaches Considered

### Recommended: Secure API defaults plus domain-based IM bootstrap fallback

- Set base defaults to `https://wemx.cc`
- Set IM bootstrap defaults to `wemx.cc:5100`
- Leave route discovery behavior unchanged

Why this approach:

- Immediately removes the hardcoded public IP from shipped defaults
- Forces realtime session events onto `wss://wemx.cc/...`
- Minimizes risk because the IM SDK bootstrap format stays unchanged

### Rejected: Full IM bootstrap migration to `wss://` in the client

This would require proving the SDK accepts secure websocket URLs in the same
format across every target and that the server advertises the correct secure IM
route payload. That is a larger protocol-contract change and belongs in a later
slice coordinated with backend rollout.

### Rejected: Leave the client unchanged until the server is fixed

That keeps new builds pointing at insecure defaults even though the public
domain and valid TLS certificate already exist today.

## Target Behavior

- `ApiConfig.baseUrl` defaults to `https://wemx.cc`
- `ApiConfig.wsAddr` defaults to `wemx.cc:5100`
- `buildSessionGatewayUri(baseUrl: ApiConfig.baseUrl, ...)` emits a `wss://`
  URI against `wemx.cc`
- A persisted `AppConstants.keyAuthLoginApiBaseUrl` override still wins

## Testing Strategy

The patch is intentionally test-first and limited to existing coverage points:

- `test/core/config/api_config_test.dart`
  - assert secure default URLs and preserved runtime override behavior
- `test/service/im/im_service_test.dart`
  - assert session gateway URI upgrades to `wss://wemx.cc/...`
- `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
  - assert proxy bypass logic still treats the secure API host as direct

## Non-Goals

- Do not change backend configs in this slice
- Do not modify IM route discovery payload parsing yet
- Do not close ports, reload nginx, or restart containers here
- Do not replace the IM SDK bootstrap transport contract in the same patch
