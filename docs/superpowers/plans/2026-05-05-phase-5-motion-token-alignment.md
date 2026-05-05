# Phase 5 Motion Token Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stable semantic chat motion duration tokens and remove the read-receipt hard-coded duration without changing existing animation behavior.

**Architecture:** Keep `ChatMotionDurations` as the single public token registry. Add semantic tokens alongside existing interaction tokens, preserve all current values, and update `ReadReceiptTicks` to consume the status-change token. Tests lock down new semantic values, old compatibility values, and reduced-motion resolution.

**Tech Stack:** Flutter/Dart 3.11, `flutter_test`, existing `ChatMotion` reduced-motion API, Material animation primitives.

---

## File Structure

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\lib\core\motion\chat_motion.dart`
  - Responsibility: public motion duration/curve token definitions and reduced-motion token resolution.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\lib\core\theme\chat_micro_interactions.dart`
  - Responsibility: chat micro-interaction widgets; this slice only changes `ReadReceiptTicks` duration source.
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\test\core\motion\chat_motion_test.dart`
  - Responsibility: lock down semantic duration values, compatibility duration values, curves, and reduced-motion behavior.

---

### Task 1: Add semantic motion token tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\test\core\motion\chat_motion_test.dart`

- [ ] **Step 1: Replace the first duration test with semantic and compatibility coverage**

In `test/core/motion/chat_motion_test.dart`, replace the current first test:

```dart
  test('motion durations collapse when animations are disabled', () {
    expect(ChatMotionDurations.messageEnter.resolve(), 260.milliseconds);
    expect(
      ChatMotionDurations.messageEnter.resolve(disableAnimations: true),
      Duration.zero,
    );
  });
```

with these two tests:

```dart
  test('motion durations expose stable semantic tokens', () {
    expect(ChatMotionDurations.fast.resolve(), 160.milliseconds);
    expect(ChatMotionDurations.normal.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.pressedScale.resolve(), 120.milliseconds);
    expect(
      ChatMotionDurations.normal.resolve(disableAnimations: true),
      Duration.zero,
    );
  });

  test('motion durations preserve existing compatibility tokens', () {
    expect(ChatMotionDurations.micro.resolve(), 160.milliseconds);
    expect(ChatMotionDurations.messageEnter.resolve(), 260.milliseconds);
    expect(ChatMotionDurations.statusChange.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.badgeBounce.resolve(), 400.milliseconds);
    expect(ChatMotionDurations.pageStandard.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.pageEmphasized.resolve(), 350.milliseconds);
    expect(ChatMotionDurations.pageReverse.resolve(), 250.milliseconds);
  });
```

Keep the existing widget reduced-motion test and curve test unchanged.

- [ ] **Step 2: Run the motion test to verify RED**

Run:

```powershell
flutter test test/core/motion/chat_motion_test.dart
```

Expected before implementation:

```text
Error: Member not found: 'fast'.
Error: Member not found: 'normal'.
Error: Member not found: 'pressedScale'.
```

The exact line numbers may differ, but the test must fail because the new semantic tokens do not exist yet.

- [ ] **Step 3: Commit the failing test**

Run:

```powershell
git add test/core/motion/chat_motion_test.dart
git commit -m "test: lock down chat motion semantic tokens"
```

---

### Task 2: Implement semantic motion tokens

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\lib\core\motion\chat_motion.dart`

- [ ] **Step 1: Add semantic duration tokens while preserving existing public tokens**

In `lib/core/motion/chat_motion.dart`, replace the `ChatMotionDurations` class body with this implementation:

```dart
class ChatMotionDurations {
  ChatMotionDurations._();

  /// Short feedback for lightweight IM micro-interactions.
  static const ChatMotionDuration fast = ChatMotionDuration(
    Duration(milliseconds: 160),
  );

  /// Default state and lightweight component transition duration.
  static const ChatMotionDuration normal = ChatMotionDuration(
    Duration(milliseconds: 300),
  );

  /// Press/scale feedback duration for touch or pointer-down affordances.
  static const ChatMotionDuration pressedScale = ChatMotionDuration(
    Duration(milliseconds: 120),
  );

  /// Compatibility alias for pre-existing micro-interaction callers.
  static const ChatMotionDuration micro = fast;

  static const ChatMotionDuration messageEnter = ChatMotionDuration(
    Duration(milliseconds: 260),
  );

  /// Compatibility alias for read/send status transitions.
  static const ChatMotionDuration statusChange = normal;

  static const ChatMotionDuration badgeBounce = ChatMotionDuration(
    Duration(milliseconds: 400),
  );

  /// Compatibility alias for standard page transitions.
  static const ChatMotionDuration pageStandard = normal;

  static const ChatMotionDuration pageEmphasized = ChatMotionDuration(
    Duration(milliseconds: 350),
  );

  static const ChatMotionDuration pageReverse = ChatMotionDuration(
    Duration(milliseconds: 250),
  );
}
```

Do not change `ChatMotionDuration`, `ChatMotionCurves`, or `ChatMotion`.

- [ ] **Step 2: Format the motion source and test**

Run:

```powershell
dart format lib/core/motion/chat_motion.dart test/core/motion/chat_motion_test.dart
```

Expected:

```text
Formatted ... files
```

- [ ] **Step 3: Run the motion test to verify GREEN**

Run:

```powershell
flutter test test/core/motion/chat_motion_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 4: Run analyzer for the motion source and test**

Run:

```powershell
flutter analyze lib/core/motion test/core/motion/chat_motion_test.dart
```

Expected:

```text
No issues found!
```

- [ ] **Step 5: Commit semantic token implementation**

Run:

```powershell
git add lib/core/motion/chat_motion.dart test/core/motion/chat_motion_test.dart
git commit -m "feat: add chat motion semantic tokens"
```

---

### Task 3: Replace read-receipt hard-coded duration

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-motion-tokens\lib\core\theme\chat_micro_interactions.dart`

- [ ] **Step 1: Replace the read-receipt animation duration**

In `lib/core/theme/chat_micro_interactions.dart`, find the `AnimationController` inside `_ReadReceiptTicksState.initState`:

```dart
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
```

Replace it with:

```dart
    _controller = AnimationController(
      vsync: this,
      duration: ChatMotionDurations.statusChange.value,
    );
```

Do not change the `ConnectionStatusBanner` constructor default in this task. It is outside the accepted `ReadReceiptTicks` scope.

- [ ] **Step 2: Add a source-level regression assertion to the motion test**

In `test/core/motion/chat_motion_test.dart`, add this import at the top before Flutter imports:

```dart
import 'dart:io';
```

Then add this helper before main():

`dart
String _readReceiptSection(String source) {
  final start = source.indexOf('class _ReadReceiptTicksState');
  final end = source.indexOf('/// Connection status banner', start);
  if (start == -1 || end == -1) {
    throw StateError('ReadReceiptTicks source section not found');
  }
  return source.substring(start, end);
}
` 

Then add this test before the extension at the bottom:

```dart
  test('read receipt ticks use the shared status-change duration token', () {
    final source = File(
      'lib/core/theme/chat_micro_interactions.dart',
    ).readAsStringSync();

    expect(source, contains('duration: ChatMotionDurations.statusChange.value'));
    expect(source, contains('duration: ChatMotionDurations.statusChange.value'));
    expect(source, contains('this.duration = const Duration(milliseconds: 300)'));
    expect(_readReceiptSection(source), isNot(contains('Duration(milliseconds: 300)')));
  });
```

This intentionally checks the implementation contract for the accepted slice: `ReadReceiptTicks` should use the shared token, and the old hard-coded duration should not remain.

- [ ] **Step 3: Format touched files**

Run:

```powershell
dart format lib/core/theme/chat_micro_interactions.dart test/core/motion/chat_motion_test.dart
```

Expected:

```text
Formatted ... files
```

- [ ] **Step 4: Run the motion test**

Run:

```powershell
flutter test test/core/motion/chat_motion_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: Run analyzer for touched files**

Run:

```powershell
flutter analyze lib/core/motion lib/core/theme/chat_micro_interactions.dart test/core/motion/chat_motion_test.dart
```

Expected:

```text
No issues found!
```

- [ ] **Step 6: Commit read-receipt token usage**

Run:

```powershell
git add lib/core/theme/chat_micro_interactions.dart test/core/motion/chat_motion_test.dart
git commit -m "refactor: use motion token for read receipts"
```

---

### Task 4: Final verification and evidence

**Files:**
- All modified files in Tasks 1-3.

- [ ] **Step 1: Run final targeted motion test**

Run:

```powershell
flutter test test/core/motion/chat_motion_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 2: Run full analyzer**

Run:

```powershell
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 3: Verify the hard-coded read-receipt duration is gone while banner scope is unchanged**

Run:

```powershell
$source = Get-Content -LiteralPath lib/core/theme/chat_micro_interactions.dart -Raw
if ($source -notmatch 'duration: ChatMotionDurations\.statusChange\.value') { throw 'ReadReceiptTicks does not use statusChange token' }
if ($source -notmatch 'this\.duration = const Duration\(milliseconds: 300\)') { throw 'ConnectionStatusBanner default duration unexpectedly changed' }
'ReadReceiptTicks token usage verified; banner default unchanged'
```

Expected:

```text
ReadReceiptTicks token usage verified; banner default unchanged
```

- [ ] **Step 4: Review git diff for scope**

Run:

```powershell
git diff --stat HEAD~3..HEAD
git diff -- lib/core/motion/chat_motion.dart lib/core/theme/chat_micro_interactions.dart test/core/motion/chat_motion_test.dart
```

Expected:

- Diff is limited to motion tokens, read-receipt duration source, motion tests, and the previously committed design/plan docs.
- No send-state icon mapping, telemetry, or unrelated text changes appear.

- [ ] **Step 5: Prepare final evidence summary**

Final response must include:

```text
Verification:
- flutter test test/core/motion/chat_motion_test.dart: All tests passed!
- flutter analyze: No issues found!
- ReadReceiptTicks token usage: verified
- Full flutter test: not run for this slice because existing unrelated full-suite failures were already documented
```

Do not claim completion unless Steps 1-3 pass in the current session.

