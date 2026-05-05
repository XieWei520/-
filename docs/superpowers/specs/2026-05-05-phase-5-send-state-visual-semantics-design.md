# Phase 5 Send-State Visual Semantics Design

## Context

Phase 5 is improving IM visual experience, monitoring, and long-term governance. The previous Phase 5 visual-governance slice aligned chat motion duration tokens. The next narrow visual slice is to unify outgoing-message send-state semantics so users see a consistent, low-noise progression from sending to sent, delivered/read, or failed.

Current state:

- `lib/core/constants/im_constants.dart` defines legacy integer send states: `sending = 0`, `sendSuccess = 1`, `sendFail = 2`.
- WuKong SDK send status constants also appear in the code as `WKSendMsgResult.sendLoading`, `sendSuccess`, and `sendFail`.
- `lib/core/transitions/message_animations.dart` contains `SendStatusIndicator`, which currently renders raw integer states directly:
  - sending -> `CircularProgressIndicator`,
  - success -> green check-circle,
  - failed -> red error icon.
- `lib/core/theme/chat_micro_interactions.dart` contains `ReadReceiptTicks`, which already represents sent/read receipts with tick-based visual language.
- Chat view models and viewport fingerprints already carry send status and existing read-receipt fields: `message.status`, `readed`, `readedCount`, and `unreadCount`.

The current UI mixes transport status, delivery/read receipt semantics, and icon choices. This makes the visual language harder to govern and can mislead users by showing a green success icon where the desired Phase 5 direction is a quieter messenger-style tick system.

## Goal

Create a conservative semantic layer for outgoing message send-state visuals:

- `sending`: lightweight progress/clock state.
- `sent`: single grey check.
- `delivered`: double grey check.
- `read`: double blue check.
- `failed`: distinct failure/retry state.

The implementation should make visual semantics explicit and testable without changing message delivery protocols or service-side read-receipt behavior.

## Approved Visual Direction

Use the approved **A. Minimal icon semantics** direction:

| Semantic state | Visual treatment | Color intent |
| --- | --- | --- |
| `sending` | small loading indicator or clock-like pending affordance | primary color at reduced opacity |
| `sent` | single check | neutral/secondary text color |
| `delivered` | double check | neutral/secondary text color |
| `read` | double check | primary blue/read accent |
| `failed` | error/retry icon, retaining failure emphasis | error red |

This slice should avoid decorative expansion. The send receipt should feel calm, compact, and consistent with common IM products.

## Recommended Approach

Introduce a small visual-state model and mapping function before changing widget rendering.

### `ChatSendVisualState`

Add an enum with these values:

```dart
enum ChatSendVisualState {
  sending,
  sent,
  delivered,
  read,
  failed,
}
```

The enum represents UI semantics, not SDK transport state. This boundary lets widgets render visual language without depending on raw integer status codes or guessing backend meaning inline.

### Mapping rules

Use conservative mapping:

1. Raw failure status (`SendMsgResult.sendFail` or `WKSendMsgResult.sendFail`) -> `failed`.
2. Raw loading/sending status (`SendMsgResult.sending` or `WKSendMsgResult.sendLoading`) -> `sending`.
3. Raw success status plus explicit read evidence -> `read`.
4. Raw success status plus explicit delivered evidence -> `delivered`.
5. Raw success status without reliable receipt evidence -> `sent`.
6. Unknown status -> `sending` only if it matches known loading value; otherwise fall back to `sent` for self messages that already exist locally, or an empty/neutral state if the existing widget requires no indicator.

Read evidence should be narrowly defined as existing fields that already mean read in the current client model, for example `readed > 0` or a positive `readedCount` when used by current receipt logic.

Delivered evidence must not be invented from `sendSuccess` alone. If the current client has no reliable delivered-but-unread signal, the `delivered` enum and rendering can exist while the mapper defaults successful-but-unread messages to `sent`. This preserves future compatibility without overstating delivery.

## Scope

In scope:

1. Add a semantic send visual state model and mapper.
2. Refactor `SendStatusIndicator` so rendering is based on `ChatSendVisualState`.
3. Preserve an integer-status compatibility path for existing callers.
4. Render the approved minimal icon language:
   - sending progress,
   - sent single grey check,
   - delivered double grey check,
   - read double blue check,
   - failed red error/retry affordance.
5. Add targeted unit/widget tests for mapping and visual semantics.
6. Use existing Phase 5 motion tokens for state-change animations.

Out of scope:

- Adding or changing service/server delivered receipt protocols.
- Changing WuKong SDK send/read semantics.
- Adding Jank telemetry or monitoring dashboards.
- Reworking message bubble layout beyond the status indicator slot.
- Fixing unrelated encoded Chinese/mojibake text.
- Running or fixing the unrelated full test-suite failures already documented during prior Phase 5 work.

## Components and Boundaries

### Semantic model and mapper

Responsibility: convert raw SDK/app status plus optional receipt evidence into `ChatSendVisualState`.

Design constraints:

- Pure Dart logic.
- No dependency on `BuildContext`.
- Easy to unit test.
- Does not mutate `WKMsg`.
- Treats delivered/read evidence conservatively.

A small immutable input model can be introduced if it keeps the mapper readable, for example:

```dart
class ChatSendVisualStatus {
  const ChatSendVisualStatus({
    required this.sendStatus,
    this.readed = 0,
    this.readedCount = 0,
    this.unreadCount = 0,
  });
}
```

The exact API may be adjusted during planning, but the boundary must remain: raw message fields go in; semantic visual state comes out.

### `SendStatusIndicator`

Responsibility: render one compact visual indicator for the semantic state.

Expected API direction:

- Preferred constructor accepts `ChatSendVisualState`.
- Compatibility constructor/factory accepts the existing raw int status and maps it to a semantic state.
- Animations continue using existing `ChatMotionDurations.statusChange.value` and `ChatMotionCurves` where appropriate.

Rendering should keep the current compact size default. Failure remains visually distinct because it has user action implications.

### Receipt ticks / read indicator

Responsibility: reusable double-check visual language for delivered/read states if this avoids duplication.

`ReadReceiptTicks` may be reused or lightly adapted only if it helps keep icon semantics consistent. Do not broaden it into a large receipt subsystem in this slice.

### Chat providers / viewport

Responsibility: expose only the small state needed by status UI.

If a provider currently exposes only `message.status`, it may need a narrow sibling selector or return object that includes receipt evidence. The selector must stay granular so message content does not rebuild on unrelated viewport changes.

## Error Handling and Edge Cases

- Failed send state remains red and prominent enough for retry affordance discovery.
- Unknown raw status must not crash; it should render a neutral/safe fallback.
- Missing receipt fields default to zero and therefore do not produce `read` or `delivered`.
- Incoming messages should not gain outgoing send-state visuals unless existing call sites already show them intentionally.
- Reduced-motion behavior should continue through existing motion tokens rather than ad-hoc durations.

## Testing Strategy

Use test-first implementation.

Targeted tests:

1. Mapper unit tests:
   - loading/sending -> `sending`,
   - failed -> `failed`,
   - success without receipt evidence -> `sent`,
   - success with read evidence -> `read`,
   - success with explicit delivered evidence -> `delivered` only if such evidence is supported by the chosen API,
   - unknown status does not throw and maps to documented fallback.
2. Widget tests for `SendStatusIndicator`:
   - `sending` renders progress/pending affordance,
   - `sent` renders single neutral check,
   - `delivered` renders double neutral checks,
   - `read` renders double read-accent checks,
   - `failed` renders error affordance.
3. Provider or integration-level test only if provider shape changes.

Verification commands for this slice should include:

```powershell
flutter test <targeted send-state test files>
flutter analyze lib/core lib/modules/chat <targeted test files>
flutter analyze
```

Full `flutter test` is not a completion gate unless the broader branch is first cleaned up, because unrelated full-suite failures were already documented during earlier Phase 5 work.

## Acceptance Criteria

- `ChatSendVisualState` or equivalent semantic model exists.
- Raw send statuses are no longer rendered directly as final icon semantics inside `SendStatusIndicator`.
- Existing integer-status callers remain source-compatible or have a narrow migration path completed in this slice.
- Successful messages without read/delivery evidence display as `sent`, not green success circles.
- Read messages display double blue ticks.
- Failed messages remain clearly failed and retry-discoverable.
- Targeted tests pass.
- `flutter analyze` reports no issues.
