# Feishu Strict No-DOM Forwarding Design

Date: 2026-05-10

## Goal

Run Feishu message forwarding without DOM fallback.

The system must not automatically open Feishu conversations to resolve media, and the WuKongIM forwarding service must not treat images discovered from opened conversation DOM probes as sendable production media. Text forwarding can continue from the message-list/feed-card path. Image forwarding is allowed only when a non-DOM source can provide both safe group attribution and a preparable image file or URL.

The safety rule is strict: when image ownership is uncertain, skip the image instead of risking wrong-group forwarding.

## Current Problem

The existing shell can monitor the Feishu message list and can also open pending media feed cards when it sees a feed-card placeholder such as `[图片]`. After opening a conversation, the page probe can discover DOM images and emit events with `captureSource` values such as `dom_probe` or `body_text_probe`.

That path works only because the shell enters Feishu conversations. The user does not want that behavior. It also creates two production risks:

- The shell may navigate away from the message list while multiple groups are active.
- A DOM image discovered after navigation can be easier to send than it is to prove safe across multiple configured routes.

Network diagnostics now prove that WebView2/CDP can see Feishu image resources and blob candidates, and the attribution hook can sometimes bind those resources to feed-card context. In the latest test, the attribution was exact-url matched to group `满满正能量`, but the confidence was `medium`, not stable. That evidence is valuable, but it is not yet enough to enable no-open production image forwarding.

## Approaches Considered

### Approach A: Keep DOM fallback behind a switch

Add a setting that defaults to no-DOM mode but lets the user re-enable automatic opening for images.

This preserves the previous recovery path, but it keeps the behavior the user explicitly rejected and makes support/debugging harder because production runs may silently drift between two very different media paths.

### Approach B: Strict no-DOM production policy

Disable automatic media conversation opening and ignore DOM-probe media for forwarding. Keep DOM/page probes for message-list observation and diagnostics only. If a future network-only resolver reaches high confidence and produces a sendable image, enable that path separately.

This is the recommended approach. It is simple, safe, and matches the user's requirement. It may skip some images for now, but it avoids wrong-group forwarding.

### Approach C: Accept medium-confidence network attribution

Forward images when one feed-card image placeholder and one network image candidate appear in a short window, or when an exact URL attribution exists with `medium` confidence.

This would forward more images sooner, but it still relies on timing and partial context. It is not acceptable for unattended multi-group forwarding.

## Decision

Implement Approach B.

The shell and forwarding service should operate in strict no-DOM mode:

- Do not automatically open pending media feed cards.
- Do not automatically open the latest feed card after feed-list changes.
- Do not forward images whose event `captureSource` is `dom_probe` or `body_text_probe`.
- Do not use medium-confidence network attribution for production image forwarding.
- Continue to expose network candidates and attribution diagnostics so future no-open image work has evidence.

## Runtime Behavior

### Text Messages

Text forwarding continues from feed-card/message-list events. Existing routing by Feishu conversation id or normalized conversation name remains unchanged.

### Image Messages

When the feed list reports a media placeholder without a safe non-DOM image attachment:

- The shell stays on the Feishu message list.
- The forwarding service does not send DOM media.
- The forwarding service does not send a fake image.
- The event may be skipped as an unresolved media event, or forwarded as text only only when that behavior already exists for a non-media event.

The preferred production behavior for image placeholders is to avoid noisy placeholder forwarding. A missed image is safer than a wrong image.

### Network Diagnostics

Existing network capture and attribution diagnostics remain enabled. They should continue exposing fields such as:

- `network_image_candidate_count`
- `network_image_attribution_count`
- `network_recent_image_attributions`
- `network_last_attributed_image_candidate`

These fields are evidence only. Production image forwarding should not consume them until a later design adds a high-confidence resolver that can also produce a local file or externally downloadable URL.

## Component Changes

### Feishu Shell

File: `tools/feishu_monitor_shell_app/lib/main.dart`

The periodic page probe may still refresh message-list state and publish snapshots, but it must not call scripts that open Feishu feed cards for media resolution.

Diagnostics should make the policy visible. For example, `last_media_open_result` and `last_feed_open_result` can report:

- `attempted: false`
- `opened: false`
- `reason: strict_no_dom_forwarding`

This gives the WuKongIM console and future test reports a clear explanation when images are intentionally not opened.

### Forwarding Service

File: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`

The service should treat DOM-derived image attachments as non-production media. A helper should reject image attachments when the event capture source is:

- `dom_probe`
- `body_text_probe`

This filter should apply before send-image, media dedupe, media retry, and priming logic. That prevents older DOM-enriched events from being sent after the shell policy changes.

### Shell Models and UI

No user-facing settings are required for this phase. The product behavior is strict no-DOM globally.

The monitor center may later show a status label such as "严格 no-DOM：图片仅诊断，未开启网络原图转发", but this implementation does not require a UI change.

## Error Handling

If a Feishu image is detected but not forwardable without DOM:

- Do not throw.
- Do not retry by opening the Feishu conversation.
- Record enough diagnostics to explain the skip.
- Keep text forwarding and route processing alive for later events.

If network capture is unavailable:

- Keep existing text forwarding behavior.
- Surface the existing network-unavailable diagnostics.
- Do not fall back to DOM media opening.

## Tests

Automated tests should cover:

- Shell page-probe refresh does not attempt media or latest-feed opening in strict no-DOM mode.
- Forwarding service ignores usable image attachments from `dom_probe`.
- Forwarding service ignores usable image attachments from `body_text_probe`.
- Forwarding service still sends non-DOM image attachments when the image has a preparable local path, `data:image`, or normal HTTP(S) URL.
- Media dedupe and retry logic do not mark DOM media as sent.

Manual joint tests should cover:

1. Launch the shell and WuKongIM desktop client.
2. Keep Feishu shell on the message list.
3. Send text to a configured Feishu group and confirm it forwards.
4. Send an image to a configured Feishu group and confirm the shell does not enter the group conversation.
5. Confirm WuKongIM does not receive a wrong image.
6. Inspect `/status` diagnostics for strict no-DOM media-open reasons and network attribution evidence.

## Success Criteria

This phase succeeds when:

- Feishu shell remains on the message list during image tests.
- No automatic conversation opening occurs for media placeholders.
- DOM-probe images are not forwarded.
- Text forwarding still works.
- Network diagnostics remain available for future no-open image research.

