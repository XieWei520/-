# Phase 5 Motion Token Alignment Design

## Context

Phase 5 has established the analyzer and release-preflight gate. The next visual-governance slice is to align chat motion naming so later UI work can use stable semantic tokens instead of ad-hoc durations.

Current state:

- `lib/core/motion/chat_motion.dart` exposes interaction-specific duration tokens such as `messageEnter`, `statusChange`, `badgeBounce`, and page transition tokens.
- `ChatMotion.duration(...)` already respects `MediaQuery.disableAnimations` by resolving tokens to `Duration.zero`.
- `lib/core/theme/chat_micro_interactions.dart` still contains at least one hard-coded animation duration in `ReadReceiptTicks`.
- `test/core/motion/chat_motion_test.dart` already verifies reduced-motion behavior and named curves.

## Goal

Introduce a small semantic motion vocabulary for IM visual polish:

- `fast`: short micro feedback.
- `normal`: default state and lightweight component transition.
- `pressedScale`: press/scale feedback duration.

This is a foundation slice only. It must not implement send-state visual semantics or Jank telemetry.

## Recommended Approach

Use a compatibility-first token alignment.

`ChatMotionDurations` will gain the new semantic tokens while keeping all existing public tokens. Existing tokens will either reference semantic tokens where the duration is intentionally the same or keep their current values when they represent a distinct interaction.

Expected values:

- `fast`: `160ms`.
- `normal`: `300ms`.
- `pressedScale`: `120ms`.
- Existing values remain stable:
  - `micro`: `160ms`.
  - `messageEnter`: `260ms`.
  - `statusChange`: `300ms`.
  - `badgeBounce`: `400ms`.
  - `pageStandard`: `300ms`.
  - `pageEmphasized`: `350ms`.
  - `pageReverse`: `250ms`.

`ReadReceiptTicks` should stop using `const Duration(milliseconds: 300)` directly and use the motion token that describes status changes.

## Scope

In scope:

1. Add semantic duration tokens in `lib/core/motion/chat_motion.dart`.
2. Replace the read-receipt hard-coded duration with a `ChatMotionDurations` token.
3. Extend `test/core/motion/chat_motion_test.dart` to lock down:
   - new token values,
   - reduced-motion zero behavior for a semantic token,
   - old token compatibility values.
4. Run targeted motion tests and analyzer for touched files.

Out of scope:

- Changing message send-state icons.
- Mapping SDK delivery/read fields.
- Adding frame timing or Jank telemetry.
- Fixing unrelated encoded Chinese copy in `chat_micro_interactions.dart`.
- Broad visual redesign.

## Components and Boundaries

### `ChatMotionDurations`

Responsibility: expose stable named duration tokens. It remains a static token registry and does not depend on widget context.

### `ChatMotion`

Responsibility: resolve tokens against user/system reduced-motion settings. No API change is required.

### `ReadReceiptTicks`

Responsibility: render receipt tick animation. It should consume duration tokens, not define raw motion values.

### Motion tests

Responsibility: prevent accidental duration drift and preserve reduced-motion behavior.

## Testing Strategy

Targeted tests:

```powershell
flutter test test/core/motion/chat_motion_test.dart
```

Static analysis:

```powershell
flutter analyze lib/core/motion lib/core/theme/chat_micro_interactions.dart test/core/motion/chat_motion_test.dart
```

Final Phase 5 smoke check for this slice:

```powershell
flutter test test/core/motion/chat_motion_test.dart
flutter analyze
```

Full `flutter test` is not a completion gate for this slice because the current branch already has unrelated full-suite failures documented during the previous Phase 5 gate-first batch.

## Acceptance Criteria

- `ChatMotionDurations.fast`, `normal`, and `pressedScale` exist with stable values.
- Existing duration token values do not regress.
- Reduced-motion resolution works for at least one semantic token.
- `ReadReceiptTicks` no longer hard-codes `Duration(milliseconds: 300)`.
- Targeted motion test passes.
- Analyzer reports no issues for touched motion files.
