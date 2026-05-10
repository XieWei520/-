# Feishu Network Image Attribution Diagnostics Design

Date: 2026-05-10

## Goal

Add a diagnostics-only attribution layer that answers one question before we enable any no-open image forwarding:

Can a network image/blob candidate be bound to a specific Feishu group and message with enough evidence to avoid wrong-group forwarding?

This design does not change production forwarding. DOM fallback remains the safe image path until the attribution evidence is stable.

## Current Evidence

The existing WebView2/CDP network capture works. In the latest joint test, the shell saw image/webp and blob candidates while the Feishu shell stayed on the message list. The problem is that the final network image candidate had empty `conversation_name`, empty `conversation_id`, and `quality=unknown`.

That means the network layer can see an image resource, but it cannot yet prove the resource belongs to the new feed card for the configured group. Forwarding it today would rely on timing guesses, which is not acceptable.

## External API Notes

The implementation should continue using current browser primitives rather than a new browser. WebView2 can inject JavaScript at document creation, before page scripts run, through `AddScriptToExecuteOnDocumentCreated`. WebView2 also exposes DevTools Protocol methods and event receivers that the current vendored plugin already uses for the Network domain. Browser blob URLs are opaque object URLs created with `URL.createObjectURL(blob)`, and image nodes can be detected with a `MutationObserver` over child and attribute changes.

References:

- Microsoft WebView2 `ICoreWebView2::AddScriptToExecuteOnDocumentCreated`: https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2
- Microsoft WebView2 DevTools Protocol event receiver example: https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_11
- MDN blob URLs: https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/blob
- MDN MutationObserver: https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver

## Approaches Considered

### Approach A: Timing-Only Correlation

When a feed card changes to `[image]` and exactly one network image appears nearby, promote the image.

This is fast and simple, but it is not stable enough. Multiple groups can update in the same short window, avatars and previews can create noise, and the evidence cannot survive UI or network timing changes.

### Approach B: DOM Object-URL Attribution Hook

Inject a page hook at document creation that records image blob URLs, observes image/background-image DOM usage, and posts attribution events with nearby feed-card/message context. Correlate those events with network image candidates by exact URL first, not by time.

This is the recommended approach. It can prove when a `blob:` URL is actually attached to a Feishu message node or feed-card node. When it cannot prove that, it keeps the candidate diagnostic-only.

### Approach C: Full Feishu Protocol Reverse Engineering

Decode Feishu Web's realtime payloads or internal APIs enough to map file resources to chat/message ids.

This might eventually produce stronger identifiers, but it is larger, fragile, and likely to depend on private binary/protobuf payload formats. It should remain a later research track, not the next production step.

## Recommended Design

Implement Approach B as a diagnostics layer with exact-match correlation.

The shell will inject a new `feishuNetworkImageAttributionScript` at document-created time and also install it after navigation as a fallback. The script will:

- Wrap `URL.createObjectURL` and record image blob URLs with MIME type, size, and timestamp.
- Observe `img` `src/currentSrc/data-src` changes and inline `background-image` changes.
- For every image-like URL, find the closest Feishu message node, closest feed card, and active feed card.
- Parse feed-card text into conversation name, display time, sender, and message preview when possible.
- Emit a `feishu_monitor_image_attribution` web message with redacted, bounded metadata only.

Dart will parse those messages into a pure model, store recent attributions beside network candidates, and expose:

- `network_image_attribution_count`
- `network_last_image_attribution`
- `network_recent_image_attributions`
- `network_last_attributed_image_candidate`

The exact match rule is:

- If `FeishuNetworkImageCandidate.resourceUrl == FeishuNetworkImageAttribution.sourceUrl`, the candidate is attributed.
- If the attribution includes a non-empty conversation name and high confidence context, the status may mark it as `stable=true`.
- If exact URL match is missing, the status may show diagnostic proximity, but must not mark it stable.

## Confidence Rules

The diagnostic layer should use conservative confidence labels:

- `high`: image URL is found inside a concrete message node or feed-card node with parsed conversation context.
- `medium`: image URL is tied to an active feed card or message-like ancestor, but message id or sender is missing.
- `low`: only a recent blob creation and feed snapshot are available.

Only `high` should be considered a future production candidate, and even then production forwarding remains disabled until live tests prove the same pattern across multiple groups.

## Data Boundaries

The diagnostics must not store raw image bytes, tokens, cookies, or full sensitive URLs. Status JSON should redact query values and resource keys the same way the existing network capture status does.

The hook should cap text fields and arrays:

- Feed-card text: 500 characters.
- Node text/message text: 240 characters.
- Recent attributions: bounded ring buffer.
- Evidence list: small strings, no raw HTML.

## Tests

Unit tests should cover:

- Attribution model parsing from WebView messages.
- Redacted status JSON for attribution events.
- Store ring-buffer output and exact URL candidate-attribution matching.
- Observer script contains the document-created hook, `URL.createObjectURL`, `MutationObserver`, and the attribution message type.

Manual joint test should cover:

1. Rebuild and launch the shell.
2. Keep Feishu on the message list page.
3. Send an image to one configured Feishu group.
4. Inspect `/status` for network candidate and attribution fields.
5. Confirm whether exact URL matching exists and whether the attribution is stable.
6. Repeat with two groups sending close together before any production forwarding decision.

## Success Criteria

This phase succeeds if the report can say one of these with evidence:

- Stable no-open attribution exists: exact URL match plus high-confidence group/message context.
- Stable no-open attribution does not exist yet: the browser sees image resources, but they are not tied to a safe group/message field.

Both outcomes are useful. The first unlocks a carefully gated production experiment. The second tells us to keep optimizing DOM fallback and avoid unsafe timing-based forwarding.

