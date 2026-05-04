# Chat Expression Panel / Sticker Alignment Design

**Date:** 2026-04-19

**Status:** Draft approved in terminal, pending written-spec review

**Scope:** Complete the remaining Android-alignment work for the chat expression surface by introducing one integrated expression panel, a local sticker message model, and resilient GIF compatibility

**Git Status Note:** This workspace does not currently expose `.git` metadata at `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app`, so the design doc can be written and reviewed here but cannot be committed from this workspace context

## Background

The Flutter project at `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` already completed the first visible round of chat-composer alignment:

1. two-row Android-like composer layout
2. rich-text entry beside the input field
3. Android static emoji asset migration
4. group-only `@` entry alignment
5. inline emoji rendering improvements
6. Android-style pre-send text-to-emoji conversion parity

Those changes closed the obvious layout gap, but the expression area is still materially behind the Android reference:

1. Flutter still lacks a dedicated local sticker message type
2. emoji, sticker, and GIF behaviors are not yet unified into one expression-panel model
3. the current Flutter expression experience still feels assembled from separate features instead of one Android-like surface
4. animated/local sticker behavior still has no robust fallback path when assets are missing or unknown

This design extends the earlier chat-page alignment work and focuses only on the remaining expression-surface parity.

## Problem Summary

The current remaining gap is not "Flutter has no emoji or GIF support." Flutter already supports static emoji and `WKGifContent`. The real gap is that Android treats expression interaction as one coherent chat surface, while Flutter still lacks that unified architecture.

The user-approved product target is:

1. one expression panel opened from the emoji button
2. `emoji`, `stickers`, and `GIF` living inside that panel instead of acting like separate outer layers
3. local stickers using a dedicated sticker content type instead of overloading GIF semantics
4. safe rendering and conversation-preview fallbacks when sticker resources are missing

## Goals

1. Keep the Android-aligned two-row composer and use it as the entry point for one integrated expression panel.
2. Introduce a new local sticker content type for Flutter: `WKStickerContent`.
3. Preserve the existing `WKGifContent` send/render path for network GIF behavior.
4. Organize emoji packs, local sticker packs, recent items, and the GIF entry through one panel registry.
5. Ship a built-in sample local sticker pack for v1 so the sticker flow is real and testable even without a downloaded marketplace.
6. Ensure message rendering remains resilient when local sticker assets are missing, stale, or unknown.

## Non-Goals

1. Do not replace `WKGifContent` with `WKStickerContent`.
2. Do not build a full sticker marketplace, downloader, or server-driven pack sync in this round.
3. Do not invent Android behavior that does not exist in the open-source reference, such as a fully populated downloadable local animated sticker store.
4. Do not rewrite the entire chat page shell or message list.
5. Do not rebuild the live text editor into a custom span editor.

## Reference Findings

### Android

The open-source Android project does not contain a ready-to-migrate full local animated sticker pack. Instead, the sticker surface is built around extension points and toolbar registration:

1. `chat_toolbar_sticker`
2. `is_register_sticker`
3. `text_to_emoji_sticker`
4. `StickerViewMenu`
5. `wk_refresh_sticker_category`

Observed behavior from the Android reference:

1. the toolbar scans registered sticker integrations rather than hardcoding one local pack implementation
2. local emoji fallback is injected when a sticker toolbar is not registered
3. GIF taps continue to send `WKGifContent`
4. text send can route through a text-to-sticker conversion hook before plain-text fallback

### Flutter

The Flutter project already has the key foundations needed for a safe incremental design:

1. `ChatPageShell` remains the chat-scene orchestration boundary
2. `ChatComposerController` already owns composer and panel state
3. `WKGifContent` already has a stable send/render path
4. Android static emoji assets and image-based emoji rendering are already present
5. there is currently no dedicated `WKStickerContent`

## User-Approved Direction

The terminal design review converged on these decisions:

1. build both architecture and UI, but lock the architecture first
2. support both local sticker packs and network GIF inside the same expression experience
3. use a distinct local sticker message type instead of forcing local stickers through `WKGifContent`
4. ship a built-in sample local sticker pack for v1
5. keep `emoji`, `stickers`, and `GIF` inside one integrated expression panel rather than a separate source-tab shell

## Selected Approach

Use a unified-expression-panel architecture with split send paths:

1. `emoji` remains a local asset-backed expression category
2. `sticker` becomes a new local pack-backed category using `WKStickerContent`
3. `GIF` remains a network-backed category using `WKGifContent`
4. all three live in one integrated panel and are exposed through one shared registry

This is preferred over:

1. overloading all stickers into `WKGifContent`, which would blur semantics and make local fallback behavior harder to reason about
2. keeping separate top-level panels for emoji, sticker, and GIF, which the user explicitly rejected as too fragmented
3. delaying local sticker support until a network marketplace exists, which would block parity even though a built-in sample pack is sufficient for v1

## UX Design

### Composer And Panel Hierarchy

The chat composer keeps the previously aligned Android-style structure:

1. top accessory strips for reply/edit/flame states
2. input row with text field, rich-text button, and send button
3. bottom toolbar row for voice, emoji, album, group `@`, and the remaining extension actions already aligned in the previous pass

The expression button opens one expression panel surface. The panel itself does not expose an outer "source switcher" row. Instead, `emoji`, local sticker packs, recent items, and the GIF entry all appear as internal panel categories.

This rule is user-approved and non-negotiable for this design:

1. `stickers`, `emoji`, and `GIF` must be integrated inside the expression panel
2. switching among them must feel like changing panel content, not jumping across unrelated panels

### Integrated Expression Panel

The integrated panel behaves like this:

1. the panel opens to the default emoji category
2. the bottom category strip contains recent, emoji pack entries, sticker pack entries, and the GIF entry in one shared row
3. selecting a different category only swaps the active content region inside the same panel shell
4. selecting GIF changes the content region into the GIF search/results state without visually leaving the expression panel

The panel should feel stable while the content region changes. No separate outer tab layer should appear above the content area.

### Recent Items

Recent items live inside the same expression system rather than as a separate feature. The recent category can contain a mixed history of:

1. emoji
2. local stickers
3. GIFs

Recent selections must replay the correct send path based on item kind rather than on where the item was originally selected.

## Message Model And Rendering Design

### Sticker Message Type

Add a new local sticker message content type:

`WKStickerContent`

Suggested payload fields:

1. `packId`
2. `stickerId`
3. `packVersion`
4. `title`
5. `mimeType`
6. `width`
7. `height`
8. `loopCount`
9. `previewKey`
10. `animationKey`
11. `fallbackText`

Design rules:

1. `WKStickerContent` represents local pack-backed stickers
2. `WKGifContent` continues to represent network GIF content
3. the send path branches by selected expression kind, not by UI panel shape

### Conversation Preview

Conversation preview text for sticker messages should be:

`[贴纸]`

This keeps parity with a message-type summary rather than pretending sticker messages are plain text or GIF URLs.

### Bubble Rendering Fallback

Sticker rendering must degrade safely in this exact order:

1. resolve and render the animation resource
2. if animation is unavailable, resolve and render the preview resource
3. if preview is unavailable, render a sticker placeholder card
4. if even placeholder metadata is insufficient, render textual fallback `[贴纸]`

Missing resources must never produce a blank bubble or a fatal render error.

## Resource Organization

### Local Asset Layout

The Flutter project should add a local sticker-pack asset structure with one manifest per pack.

Each pack manifest should include:

1. `packId`
2. `packVersion`
3. `title`
4. `cover`
5. `stickers`

Each sticker entry should include:

1. `stickerId`
2. `title`
3. `preview`
4. `animation`
5. `width`
6. `height`
7. `mimeType`
8. optional `loopCount`
9. optional `fallbackText`

The v1 product ships with one built-in sample sticker pack so the feature is complete without depending on downloaded content.

### Registry

The panel category strip should not be hardcoded directly in the widget tree. It should be generated from one registry that can produce entries for:

1. recent
2. emoji packs
3. sticker packs
4. GIF entry

This keeps ordering and future expansion manageable while preserving one panel shell.

### Recent Storage

Recent items should store logical IDs, not absolute local file paths.

Recommended key shape:

1. `kind`
2. `packId`
3. `stickerId`
4. optional GIF payload identity

This keeps recent history stable even if asset directories change.

## Technical Design

### UI Boundary

The current chat page already has a large orchestration surface, so the new expression work should be added as focused units instead of piling all logic directly into `ChatPageShell`.

Recommended boundary split:

1. `ChatPageShell`
   - owns chat-scene orchestration
   - decides when the expression panel is shown
   - routes send actions into the correct content sender
2. `ChatComposerController`
   - remains the source of truth for active panel state
   - tracks the selected expression category
   - coordinates panel open/close transitions
3. new expression-panel widgets and adapters
   - render the unified panel shell
   - resolve the active category view
   - render emoji grid, sticker grid, or GIF state inside one panel boundary
4. new registry and sticker-catalog services
   - translate local manifests and emoji assets into UI categories and sendable items

### Send Routing

Panel selection should branch into three explicit send paths:

1. emoji inserts compatible text into the composer and continues through the normal send path
2. local sticker tap sends `WKStickerContent` immediately
3. GIF tap sends the existing `WKGifContent`

This keeps each content type aligned with its real semantics.

### GIF State

GIF remains inside the integrated expression panel, but it is still operationally different from local assets:

1. it needs search
2. it needs loading and empty states
3. it can fail due to network issues

That difference should be isolated to the GIF category content region only. A GIF failure must not disable emoji or local sticker browsing.

## Error Handling And Fallback Behavior

### Local Sticker Failures

If a local pack manifest references a missing animation or preview asset:

1. the app should still resolve the sticker identity
2. rendering should step down through the fallback chain
3. send-time logic should still produce a valid `WKStickerContent`

If a receiving device does not have the referenced local assets:

1. the message should still render as a sticker placeholder or `[贴纸]`
2. the conversation preview should remain stable
3. the chat page must not crash

### GIF Failures

If GIF search or fetch fails:

1. only the GIF category shows loading failure or retry UI
2. emoji and local sticker categories remain fully usable
3. switching away from GIF clears the failure from the visible surface

## Migration Strategy

The rollout should happen in two controlled stages.

### Stage 1: Integrated Panel Foundation

Deliver:

1. unified expression panel shell
2. registry-driven category strip
3. emoji categories inside the new panel
4. sample local sticker pack inside the same panel
5. `WKStickerContent` model and rendering support
6. existing GIF entry moved into the integrated panel shell

Purpose:

1. establish the architecture
2. prove the new sticker message type
3. lock the user-visible hierarchy before scale-up

### Stage 2: Hardening And Expansion

Deliver:

1. recent mixed-item persistence
2. additional sticker packs when assets are available
3. caching and preload polish
4. more complete GIF/search state polish

Purpose:

1. improve robustness and polish after the base structure is verified
2. avoid overloading the first change with scale concerns

## Verification Strategy

Testing should cover four layers.

### Component Tests

1. category strip ordering and selection
2. sticker-pack switching inside the same panel shell
3. GIF search-state switching
4. empty-state and retry-state presentation

### Message Model Tests

1. `WKStickerContent` encode/decode behavior
2. conversation-preview output for sticker messages
3. bubble fallback order when assets are missing
4. unknown pack or unknown sticker handling

### Page Interaction Tests

1. expression button opens the integrated panel
2. rich-text button still sits beside the input and is unaffected by sticker work
3. group `@` behavior remains intact
4. tapping a sticker sends `WKStickerContent`
5. tapping a GIF still sends `WKGifContent`

### Regression Tests

1. plain text send still works
2. image, file, location, and voice actions still work
3. existing GIF messages still render
4. static emoji rendering remains Android-aligned
5. text-to-emoji conversion parity remains intact

High-risk assertions that must be explicit:

1. missing local sticker resources do not crash rendering
2. unknown or stale sticker IDs still degrade to placeholder or `[贴纸]`
3. GIF network failures do not break emoji or sticker browsing
4. recent mixed-item replay chooses the correct send path by item kind

## Risks

1. The Android reference uses extension hooks instead of a fully packaged local sticker implementation, so Flutter must define clearer local asset contracts than Android exposes directly.
2. Adding a new message content type introduces protocol-model and renderer-surface work that must be isolated carefully from existing chat content types.
3. Recent mixed-item history can become brittle if it stores physical asset paths instead of logical IDs.
4. If GIF state is not properly isolated, network failures can make the whole expression panel feel broken.

## Deferred Work

These items are intentionally out of scope for this round:

1. downloadable sticker marketplace
2. server-driven sticker pack synchronization
3. full span-based inline sticker rendering inside the live text editor
4. replacing `WKGifContent` with a new unified remote-media protocol

## Workspace Note

This workspace is being treated as a non-Git workspace in the current Codex app context. The design document is written locally for review, but the brainstorming workflow's "commit the design doc" checkpoint cannot be completed from this workspace state.
