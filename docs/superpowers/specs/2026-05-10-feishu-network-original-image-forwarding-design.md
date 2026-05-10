# Feishu Network Original Image Forwarding Design

Date: 2026-05-10

## Goal

Forward Feishu images to WuKongIM without opening Feishu group conversations and without using DOM fallback media extraction.

The shell may keep using the Feishu message list for login state, feed-card observation, and text/message-list events. It must not enter a source group conversation to find image nodes. Image forwarding is allowed only when the network layer provides an actual local image file and the resolver can prove that the image belongs to one configured Feishu source group.

The safety rule is strict: if image ownership is uncertain, skip the image. A missed image is acceptable; a wrong-group image is not.

## Current Evidence

The current shell already has the important foundation:

- `tools/vendor/webview_windows_wukong/windows/webview.cc` subscribes to WebView2 CDP `Network.responseReceived`, `Network.loadingFinished`, and `Network.webSocketFrameReceived`.
- `HandleNetworkLoadingFinished` already calls `Network.getResponseBody` for selected responses.
- `tools/vendor/webview_windows_wukong/windows/webview.h` models network events as `WebviewNetworkEvent`.
- `tools/vendor/webview_windows_wukong/windows/webview_windows_plugin.cc` emits events through MethodChannel `wukong/feishu_network_capture`.
- `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart` receives the MethodChannel events in Dart.
- `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart` can detect image candidates from direct image HTTP responses and JSON payloads.
- `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart` stores recent candidates and attribution diagnostics.
- `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart` can already send WuKongIM images when an event has a usable local file.

The missing pieces are also clear:

- The native WebView2 layer truncates response body into `payload_preview`; it does not save full image bytes.
- Dart receives no `body_local_path`, `body_sha1`, `body_size`, or similar metadata.
- The store can show a matching network candidate and attribution, but it does not produce a production-grade `FeishuMonitorMessageEvent` image attachment.
- Current attribution evidence can be useful but must stay conservative because previous live tests showed plausible-looking matches on non-message feed images.

## Approaches Considered

### Approach A: Native CDP response body saver

Capture direct Feishu image HTTP responses through WebView2 CDP, decode the complete response body, save the image as a local cache file, and emit file metadata to Dart. Dart then resolves that local file against feed-card/group evidence before forwarding.

This is the recommended approach. It uses the same authenticated WebView2 session that loaded the image, avoids external re-download problems, and gives WuKongIM the local file path it already knows how to upload.

### Approach B: JS fetch/blob extraction

Use injected JavaScript to fetch `blob:` or image URLs inside the page and send base64 bytes to Dart.

This is rejected for this phase. It is too close to DOM fallback, may be blocked by browser/CORS/security behavior, increases page-script complexity, and makes wrong attribution easier if the page changes.

### Approach C: Feishu protocol reverse engineering

Map WebSocket or JSON message payloads to message IDs and image resource keys, then request original image bytes using the same internal endpoints.

This may become the strongest long-term option, but it is larger and less certain. It requires more reverse engineering, more protocol drift handling, and more legal/operational caution. It should be treated as a later spike, not the first production implementation.

## Decision

Implement Approach A first: native CDP image body saving plus strict Dart-side attribution and route gating.

The implementation must not:

- open Feishu group conversations for image resolution;
- use `dom_probe` or `body_text_probe` image attachments;
- forward medium-confidence or timing-only image matches;
- forward when multiple candidate images could match the same feed event;
- forward when multiple feed image events could claim the same candidate.

## Architecture

### Native WebView2 capture

Extend `WebviewNetworkEvent` with file/body metadata:

- `body_local_path`
- `body_sha1`
- `body_size`
- `body_mime_type`
- `body_base64_encoded`
- `body_saved`
- `body_save_error`

When `Network.loadingFinished` fires, keep calling `Network.getResponseBody` for image-looking responses. If the response is eligible, decode the complete body and save it to a runtime cache directory.

Eligibility rules:

- HTTP status is 2xx.
- MIME type starts with `image/`.
- URL matches a Feishu message-image-looking host/path such as `internal-api-lark-file.feishu.cn` or `imfile.feishucdn.com/static-resource/v1/`.
- URL does not look like static UI chrome, default avatar, emoji sprite, app icon, or CDN shell asset.
- Decoded body is non-empty.
- Decoded body is below a configured cap, initially 25 MB.

Saved file naming:

- Use `sha1(bytes)` as the base filename.
- Choose extension from MIME type: `jpg`, `png`, `gif`, or `webp`.
- Never include the Feishu URL or auth query tokens in the filename.
- Write atomically when possible, then emit the local path and metadata to Dart.

### Dart network model and bridge

Extend `FeishuNetworkCaptureEvent` and `FeishuNetworkCaptureBridge` to carry the new body metadata.

Extend `FeishuNetworkImageCandidate` so direct image candidates can include:

- `localPath`
- `bodySha1`
- `bodySize`
- `bodyMimeType`

The parser should continue rejecting obvious non-message images. A direct image response is only a candidate when it passes the existing URL/mime checks and has a saved local file.

### Forwardable image resolver

Add a focused resolver in the shell app, for example `FeishuNetworkForwardableImageResolver`, owned by the network capture store or a nearby file. Its job is to transform diagnostics into a production-safe image event.

A network image can become forwardable only when all of these are true:

- The candidate has an existing `localPath`.
- The candidate has `bodySha1` and `bodySize > 0`.
- The source URL exactly matches a high-confidence attribution source URL, or a future normalized resource-key matcher proves equivalence.
- Attribution confidence is `high` and `confidence >= 0.8`.
- Attribution includes feed-card context, not only active-feed context.
- The feed card identifies a Feishu conversation id or name that maps to exactly one enabled forwarding route.
- A recent feed-card event for the same conversation reports an image placeholder such as `[图片]`.
- Candidate, attribution, and feed event are close in time, initially within 8 seconds.
- There is exactly one candidate/attribution/feed-event match in that time window.

If any check fails, the resolver records a skip reason and produces no image event.

Initial skip reasons:

- `missing_local_body`
- `body_file_missing`
- `attribution_missing`
- `attribution_not_high_confidence`
- `route_missing`
- `route_disabled`
- `feed_placeholder_missing`
- `ambiguous_candidates`
- `ambiguous_feed_events`
- `stale_match`
- `static_resource_filtered`

### Shell event output

When the resolver succeeds, the shell should emit a normal `FeishuMonitorMessageEvent` in `recent_events` with:

- `capture_source: network_original_image`
- `message_type: image`
- `text: [图片]`
- source conversation id/name from the matched feed event or attribution
- one `image_attachments` item with `local_path` set to the saved image file
- `source_url` retained for dedupe/debugging but redacted in diagnostics
- width/height filled when available, otherwise decoded from the local image if practical

The event dedupe key should include source conversation identity and image hash. The media fingerprint should use the local file/hash so the same image is not sent repeatedly.

### WuKongIM forwarding service

The existing forwarding service should continue to reject `dom_probe` and `body_text_probe` image attachments.

It should accept `network_original_image` events because they carry a local file path. The current `WkImFeishuMonitorTextSender.sendImage` path already uploads a local file through `FileApi.instance.uploadChatFile`, so this phase should avoid introducing a second upload mechanism.

### Diagnostics and UI

Expose enough runtime status for joint testing:

- `network_saved_image_count`
- `network_forwardable_image_count`
- `network_last_forwardable_image`
- `network_last_image_skip_reason`
- recent resolver decisions with redacted URLs

The monitor center can show the latest reason in plain language, but forwarding must not depend on UI state.

## Error Handling

If native body saving fails:

- emit the network event with `body_saved: false` and a short `body_save_error`;
- do not crash the shell;
- do not retry by opening a Feishu conversation.

If attribution is missing or ambiguous:

- keep diagnostics;
- skip forwarding;
- wait for future events.

If WuKongIM upload fails:

- treat it like the existing image send failure path;
- do not fall back to sending an unrelated image;
- only send text fallback when existing forwarding behavior explicitly allows it for that event.

## Privacy and Retention

The shell stores temporary image bytes because WuKongIM upload needs a local file. The cache must stay local to the Windows machine.

Rules:

- Use the app cache/runtime directory, not the project directory.
- Use hash filenames only.
- Do not log full Feishu URLs with tokens.
- Delete cached images older than a short TTL, initially 24 hours.
- Keep diagnostics redacted.

## Testing

Automated tests should cover:

- native/Dart bridge map parsing for body metadata;
- parser rejects image responses without saved local files;
- parser accepts a Feishu image response with saved local file metadata;
- resolver rejects missing local body;
- resolver rejects medium-confidence attribution;
- resolver rejects route mismatches;
- resolver rejects ambiguous candidates;
- resolver rejects ambiguous feed events;
- resolver produces one `network_original_image` event for one high-confidence candidate, one high-confidence attribution, and one matching recent feed image placeholder;
- forwarding service sends `network_original_image` local files;
- forwarding service still rejects `dom_probe` and `body_text_probe` media.

Manual joint test:

1. Start WuKongIM desktop and the Feishu shell.
2. Keep the Feishu shell on the message list.
3. Send text to a configured Feishu group and confirm forwarding still works.
4. Send one image to one configured Feishu group.
5. Confirm the Feishu shell does not enter the group conversation.
6. Confirm WuKongIM receives the image when resolver diagnostics show a single high-confidence match.
7. Send images into two configured Feishu groups within the same short window.
8. Confirm ambiguous cases are skipped rather than misrouted.
9. Inspect status diagnostics for saved body metadata, resolver decision, and skip reasons.

## Success Criteria

This phase succeeds when:

- Feishu image bytes are saved by the native WebView2 network layer.
- Dart receives local image metadata.
- The shell emits `network_original_image` events only for strict, unambiguous matches.
- WuKongIM can forward those local image files.
- The shell stays on the Feishu message list.
- Wrong-group forwarding is prevented by conservative gating.

## Known Limits

This design does not guarantee every Feishu image will forward. Some images may still be skipped when Feishu serves them through blob-only flows, cached responses that CDP cannot read, encrypted payloads, or ambiguous multi-group timing.

The first target is correctness and safety. After the safe path works, latency and coverage can be improved with additional protocol-level research.
