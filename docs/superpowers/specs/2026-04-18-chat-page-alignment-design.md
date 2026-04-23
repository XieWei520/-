# Chat Page Alignment Design

**Date:** 2026-04-18

**Status:** Draft approved in terminal, pending written-spec review

## Background

The Flutter project at `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` already has a working chat page with message sending, reply/edit state, mention suggestions, voice recording, function panels, rich text sending, GIF sending, and flame mode support. The open-source Android project at `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master` uses a different chat composer structure and a much richer emoji asset set.

The current user-visible gap is not that Flutter lacks all chat features. The bigger gap is that the composer area is arranged differently from Android, making the page feel unlike the Android reference even where the capability already exists.

## Goals

1. Align the Flutter chat composer layout with the Android chat page interaction model.
2. Move rich-text entry to the input row, beside the text field, matching Android.
3. Move toolbar actions into a dedicated toolbar row below the input row, matching Android.
4. Migrate the Android static emoji catalog and image assets into Flutter.
5. Keep dynamic-expression behavior aligned with Android's real behavior:
   - GIF sending through `WKGifContent`
   - text-to-sticker conversion hooks where applicable
6. Preserve existing Flutter chat behavior such as reply, edit, voice recording, mentions, flame mode, and function panel actions.

## Non-Goals

1. Do not redesign the entire chat page shell.
2. Do not change server-side message protocols.
3. Do not build a brand-new local animated sticker pack system that Android does not already provide.
4. Do not replace Flutter's text editor with a fully custom span-based editor in this round.

## Reference Findings

### Android

The Android chat composer is organized into three visible layers:

1. Top accessory area for reply/edit/flame strips.
2. Input row with:
   - text field
   - rich-text button inside the input area (`markdownIv`)
   - flame entry when enabled
   - send button
3. Dedicated bottom toolbar row with:
   - emoji
   - voice
   - album
   - at
   - more

Android also includes:

1. A full emoji catalog in `wkbase/src/main/assets/emoji/emoji.xml`
2. Emoji image assets under `wkbase/src/main/assets/emoji/default/`
3. Emoji grouping by `0_`, `1_`, and `2_`
4. Rich-text entry triggered through `show_rich_edit`
5. GIF sending through `WKGifContent`
6. A text-to-emoji-sticker conversion hook before normal text sending

### Flutter

The Flutter chat page already includes:

1. `ChatPageShell` as the main chat-page orchestration point
2. `ChatComposerController` state for text, voice mode, emoji panel, function panel, robot GIFs, and reply/edit state
3. `showChatRichTextComposeDialog()` and `WKRichTextContent` sending
4. Mention handling through `ChatMentionsController`
5. Voice recording overlays and hold-to-record support
6. Function panel actions such as image, file, location, card, and rich text
7. GIF sending through `WKGifContent`

The current mismatch is primarily layout and resource alignment:

1. Toolbar actions are split around the input row instead of living in a dedicated bottom toolbar.
2. The rich-text entry exists but is not positioned like Android.
3. The emoji panel uses a very small hardcoded Unicode palette instead of Android's full image-based emoji set.
4. The text-to-sticker conversion path is not aligned with Android.

## Selected Approach

Use a structure-alignment-plus-resource-migration approach.

This is preferred over:

1. A minimal emoji-only migration, because the chat page would still look structurally different from Android.
2. A full composer rewrite from scratch, because that would create unnecessary regression risk and duplicate existing Flutter chat logic.

The selected approach keeps the current Flutter chat state and sending logic, but rearranges the composer UI to match Android and replaces the emoji data source with Android-derived catalog data.

## UX Design

### Composer Layout

The composer area in Flutter will be restructured to match Android's visual hierarchy:

1. Reply/edit strip at the top when active.
2. Main input row containing:
   - text input
   - rich-text button beside the text field
   - flame button when flame is enabled
   - send button
3. Dedicated toolbar row under the input row containing:
   - emoji
   - voice
   - album
   - at
   - more

Behavior rules:

1. Tapping emoji toggles the emoji panel.
2. Tapping more toggles the function panel.
3. Tapping album directly opens media selection.
4. Tapping at inserts `@` into the input and keeps mention suggestions working.
5. Tapping voice toggles the hold-to-record mode.
6. Rich text is removed from the more panel and exposed beside the input field.

### Rich Text

The existing Flutter rich-text compose dialog remains the authoring UI for this round. Only the entry point changes:

1. Remove rich text from the "more" function panel.
2. Place the entry beside the text field, matching Android.
3. Hide or visually subordinate it when flame mode requires Android-equivalent behavior.

### Emoji Panel

The Flutter emoji panel will switch from hardcoded Unicode-only entries to Android-derived catalog data:

1. Use the Android `emoji.xml` catalog as the source of truth.
2. Use image assets from the Android `default` emoji directory.
3. Preserve Android grouping:
   - `0_`: default/smileys and main expressions
   - `1_`: nature and related symbols
   - `2_`: symbol set
4. Support skin-tone variants present in Android assets.

### Dynamic Expression Alignment

Dynamic expression behavior will follow Android's actual behavior instead of inventing a new local animated-pack system:

1. Keep GIF sending via `WKGifContent`
2. Improve the Flutter GIF/robot-expression presentation so it behaves closer to Android
3. Add an Android-aligned pre-send text-to-sticker conversion layer where the message content qualifies

## Technical Design

### Composer UI Boundary

The current `chat_page_shell.dart` already handles too many responsibilities. To reduce further growth, the composer rendering should be extracted into a focused widget or widget group while `ChatPageShell` remains the orchestration entry point.

Recommended split:

1. `ChatPageShell`
   - owns high-level chat scene orchestration
   - owns sending callbacks and message-level actions
2. New composer presentation widget(s)
   - render Android-aligned input row
   - render toolbar row
   - render active panel container
3. Existing controllers remain the source of truth:
   - `ChatComposerController`
   - `ChatMentionsController`
   - voice state providers/services

### Emoji Data Model

Flutter needs a new Android-compatible emoji catalog model, not just more strings.

Required fields:

1. catalog id
2. tag/string inserted into the composer
3. asset file path
4. group/category
5. optional variant relationship

This catalog should be generated from Android source assets rather than maintained by hand. The migration output should live in Flutter assets plus a generated catalog file in the Flutter project.

### Emoji Rendering Strategy

For this round:

1. Message display uses Android emoji images.
2. Picker uses Android emoji images.
3. Insert/send still uses the textual tag/emoji value, preserving protocol compatibility.
4. Input editing remains text-based in `TextField`.

This tradeoff is intentional. Android uses span rendering inside `EditText`, but reproducing that safely in Flutter would require a deeper editor rewrite and would put mentions, edit mode, reply mode, and cursor handling at risk. The chosen approach preserves compatibility and lowers regression risk while still making sent and received messages look like Android.

### Function Panel Cleanup

The more panel should contain only extension-style actions, such as:

1. image
2. file
3. location
4. card
5. group call

Rich text should be removed from this panel because Android exposes it beside the input field.

### Mention Alignment

The Flutter mention system already works, but the entry path should be aligned with Android:

1. add an explicit toolbar `@` button
2. keep existing mention suggestions and selected-member tracking
3. keep current reply/edit/typing interactions intact

### Text-to-Sticker Conversion

Android attempts a conversion path before sending ordinary text when the content matches a sticker mapping. Flutter should gain an equivalent hook in the send flow:

1. inspect outgoing plain text
2. resolve whether it maps to an emoji sticker/GIF conversion
3. send the converted content when a mapping exists
4. fall back to plain text otherwise

## Delivery Plan

Implementation should proceed in three delivery blocks:

### Block 1: Composer Structure Alignment

Deliverables:

1. Android-like input row
2. Android-like bottom toolbar row
3. Rich-text button beside the input
4. Stable toggling for emoji/function/voice modes

Purpose:

1. Make the page structure feel like Android first.
2. Avoid mixing layout changes with asset migration in the same first step.

### Block 2: Static Emoji Migration

Deliverables:

1. Android emoji asset copy into Flutter assets
2. generated or parsed emoji catalog data
3. picker rendering from Android assets
4. message rendering from Android assets
5. recent-use support based on the new catalog

Purpose:

1. Close the visible emoji gap.
2. Ensure sent and historical messages render consistently.

### Block 3: Remaining Android Behavior Gaps

Deliverables:

1. explicit `@` toolbar entry
2. rich-text entry relocation completion
3. GIF behavior polish
4. text-to-sticker conversion alignment
5. flame/rich-text visibility logic cleanup

Purpose:

1. Finish the remaining behavioral mismatches without destabilizing the earlier steps.

## Validation Plan

Each block must be validated independently.

### Core Regression Checks

1. plain text send
2. reply send
3. edit send
4. mention insertion and mention send
5. voice hold-to-record
6. emoji panel toggle
7. more panel toggle
8. image send
9. file send
10. location send
11. rich-text send
12. flame mode button visibility and panel behavior

### Emoji Checks

1. picker shows Android-derived groups
2. picker entries display image assets instead of a tiny Unicode-only list
3. inserting an emoji sends compatible textual content
4. new outgoing messages render Android-style emoji images
5. existing historical messages render Android-style emoji images
6. skin-tone variants resolve correctly where supported

### Behavior Checks

1. rich text is no longer buried in the more panel
2. the toolbar visually lives below the input row
3. `@` has an explicit entry point
4. GIF sending still produces `WKGifContent`
5. text-to-sticker conversion falls back safely when no mapping exists

## Open Risks

1. The current chat shell file is already large, so keeping all UI changes inline would increase maintenance cost.
2. Emoji display compatibility depends on correctly mapping Android tags to Flutter message rendering.
3. Input-field image-span parity is intentionally deferred to avoid destabilizing text editing.
4. Text-to-sticker conversion may depend on Android-side assumptions that need to be re-expressed clearly in Flutter.

## Deferred Work

These items are intentionally out of scope for this round unless a later spec expands them:

1. full span-based image rendering inside the live Flutter text editor
2. a new local animated sticker-pack system unrelated to Android behavior
3. unrelated chat-page refactors outside the composer and expression-alignment scope

## Workspace Note

This workspace is currently being treated as a non-Git workspace in the Codex app context. The design document can be written and reviewed normally, but the "commit the design doc" step from the brainstorming workflow cannot be completed here unless the project is opened as a Git workspace.
