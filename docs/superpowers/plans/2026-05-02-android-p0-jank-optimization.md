# Android P0 Jank Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Android UI jank in the Flutter client with low-risk, testable changes to hot render paths and startup/build side effects.

**Architecture:** Keep the existing Flutter architecture intact. Optimize local hot paths by reducing repeated scans/allocation, lowering Android chat-list prebuild pressure, and moving app-root side effects out of `build()` where practical.

**Tech Stack:** Flutter 3.41.4, Dart 3.11.1, Riverpod, Kotlin Android embedding.

---

### Task 1: Emoji catalog first-code-unit index

**Files:**
- Modify: `lib/wukong_base/emoji/android_emoji_catalog.dart`
- Modify: `lib/widgets/wk_emoji_text.dart`
- Test: `test/widgets/wk_emoji_text_test.dart`

- [ ] Add a failing test asserting the catalog can cheaply reject text positions that cannot start an Android emoji tag and accept positions that can.
- [ ] Run `flutter test test/widgets/wk_emoji_text_test.dart` and confirm the new test fails because the API is missing.
- [ ] Add an immutable first-code-unit index in `AndroidEmojiCatalog`, expose `canStartEmojiAt`, and make `longestMatchAt` iterate only candidate tags.
- [ ] Update `WKEmojiText.containsAndroidEmoji` and span building to benefit from the indexed lookup through `longestMatchAt`.
- [ ] Re-run `flutter test test/widgets/wk_emoji_text_test.dart`.

### Task 2: Android chat list prebuild pressure

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Test: `test/modules/chat/chat_scroll_pagination_test.dart`

- [ ] Change the cache extent test to encode lower Android/mobile cache extent while preserving desktop/web behavior.
- [ ] Run `flutter test test/modules/chat/chat_scroll_pagination_test.dart` and confirm the cache extent test fails.
- [ ] Lower `chatListCacheExtent` only for Android/iOS/Fuchsia mobile targets, keeping desktop/web values unchanged.
- [ ] Re-run `flutter test test/modules/chat/chat_scroll_pagination_test.dart`.

### Task 3: App-root side-effect throttling

**Files:**
- Modify: `lib/app/app.dart`

- [ ] Move bridge registration/navigator binding and call coordinator start/stop out of unconditional build work where possible.
- [ ] Keep behavior equivalent: bridges are registered once, navigator keys stay bound when router changes, and call coordinator starts only when logged in.
- [ ] Verify with analyzer and existing app/widget tests.

### Task 4: Native badge ROM detection fast path

**Files:**
- Modify: `android/app/src/main/kotlin/com/im/wukong_im_app/DeviceBadgeUtils.kt`

- [ ] Avoid spawning `getprop` processes for manufacturers that are clearly not supported by current badge implementations.
- [ ] Cache ROM detection result exactly once and keep supported Huawei/Vivo/Oppo paths intact.
- [ ] Verify with Android assemble if environment permits.

### Task 5: Verification

- [ ] Run focused tests:
  - `flutter test test/widgets/wk_emoji_text_test.dart`
  - `flutter test test/modules/chat/chat_scroll_pagination_test.dart`
- [ ] Run `flutter analyze` and report pre-existing warnings separately from new issues.
- [ ] If feasible, run `flutter build apk --debug` or `flutter build apk --profile` to verify Android compile.
