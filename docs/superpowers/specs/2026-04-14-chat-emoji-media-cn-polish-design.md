# Chat Emoji / Media / Chinese-First Polish Design

**Date:** 2026-04-14  
**Scope:** Active chat composer and high-frequency chat interaction fixes for desktop Flutter parity  
**Primary KPI:** Remove the most visible chat regressions blocking day-to-day desktop IM use: emoji insertion, image sending, location/card interaction, and Chinese-first presentation  
**Git Status Note:** This checkout still does not expose `.git` metadata, so the spec is written locally without a commit checkpoint from this workspace

## 1. Problem Summary

The current desktop chat path is structurally correct but still has four user-visible product breaks:

- the emoji panel opens but contains no insertable emoji
- image sending enters the upload path and then fails with a red-dot send error
- location and card messages render as static content but cannot be opened
- the app remains mixed-language because global locale wiring is missing and several high-traffic pages still carry English or broken text

These are not separate architecture failures. They are closure gaps on top of the already-established `ChatPageShell` mainline.

## 2. Root Cause Findings

### 2.1 Emoji panel

The active composer route is `ChatPage -> ChatPageShell`, and the face-panel branch inside `_buildPanel(...)` is a placeholder that renders only the title `表情面板`. No emoji dataset, grid, or insertion callback is attached in this path.

### 2.2 Image upload

The attachment send chain reaches `FileApi._requestUploadUrl()`, but the returned absolute upload URL points at `https://wemx.cc/v1/file/upload?...`. On this Windows machine, direct requests to `https://wemx.cc` time out, which reproduces the local `Attachment upload failed` error and explains the red send-failure dot. The same backend remains reachable through the configured `ApiConfig.baseUrl` (`http://42.194.218.158`).

### 2.3 Location and card interaction

The message bubble already supports a generic `onTap`, but `ChatPageShell` currently only wires taps for image messages. Location and card content therefore display correctly but never navigate anywhere.

### 2.4 Chinese-first behavior

`MaterialApp.router` has no locale wiring, `flutter_localizations` is not enabled, and language preference stored by `WKSettingPreferences` is not consumed by the app root. High-traffic chat/location surfaces also contain mixed English or broken copy.

## 3. User-Approved Direction

Use the previously approved superpowers execution path and treat this as a mainline closure pass rather than a new subsystem:

- keep the active `modules/chat` architecture
- fix the root cause instead of adding UI-only workarounds
- prefer Chinese-first behavior immediately
- restore the minimum Android-reference chat ergonomics needed for desktop daily use

## 4. Target Design

### 4.1 Upload URL normalization

Add a focused normalization path for backend-issued absolute upload URLs:

- keep relative upload paths on the existing `ApiConfig.resolveUrl(...)` path
- if the upload URL is absolute and targets the same backend API route (`/v1/file/upload`) but a different host than the configured `baseUrl`, rewrite it onto the active `baseUrl` host
- do not rewrite arbitrary CDN/media URLs

This keeps attachment upload stable without changing server contracts.

### 4.2 Emoji composer panel

Replace the placeholder panel with a real emoji grid that:

- renders a curated default emoji list
- inserts the selected emoji into the active text field at the current cursor position
- keeps the composer text state in sync with `ChatComposerController`
- exposes a delete action so the panel remains usable without the hardware keyboard

This is sufficient for the approved “can open panel and send emoji” requirement without rebuilding the full Android emoji asset engine.

### 4.3 Bubble interaction routing

Extend `ChatPageShell` bubble taps so that:

- image continues to open the existing media viewer
- location opens `LocationViewPage`
- card opens `UserDetailPage`

The router should resolve both native message-content objects and structured payload fallbacks so older or unknown-card payloads remain tappable.

### 4.4 Chinese-first app root

Apply language preference at the app root:

- add `flutter_localizations`
- expose `supportedLocales` for `zh_CN` and `en_US`
- set `localizationsDelegates`
- default to Simplified Chinese unless the user explicitly selected English

Also replace the highest-frequency hard-coded chat/location English strings in this pass.

## 5. Scope

### In scope

- active chat emoji panel usability
- image upload timeout fix for desktop
- location/card tap-to-open
- app-root locale wiring
- Chinese copy cleanup in active chat/location surfaces

### Out of scope

- full ARB/gen_l10n migration
- full emoji store / sticker-market rebuild
- file open behavior redesign
- server-side upload contract changes unless client normalization proves insufficient

## 6. Verification Strategy

- unit test upload URL normalization
- widget test emoji panel rendering/insertion
- widget test location/card bubble tap routing from `ChatPageShell`
- widget test app root locale wiring
- targeted Windows desktop smoke test for image send, emoji insert, location open, and card open
