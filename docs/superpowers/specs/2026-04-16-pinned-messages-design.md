# Pinned Messages Design

**Date:** 2026-04-16  
**Scope:** Close the pinned-message migration gap across sync, permissions, chat actions, and visible chat surfaces in the Flutter client  
**Primary KPI:** Let users pin, unpin, sync, browse, and jump to pinned messages with behavior aligned to the TangSengDaoDao server and Android reference flows  
**Git Status Note:** This checkout still does not expose `.git` metadata, so the spec is written locally without a commit checkpoint from this workspace

## 1. Problem Summary

`WuKongIM_Migration_Gap_Analysis_Report.md` still lists pinned messages as an unimplemented Flutter gap even though the backend already exposes `/v1/message/pinned`, `/v1/message/pinned/sync`, and `/v1/message/pinned/clear`.

The missing behavior is deeper than a missing UI entry:

- the SDK sync models do not carry `isPinned` end to end
- app-side sync parsers also drop `is_pinned`
- IM command routing ignores the backend `syncPinnedMessage` command
- the runtime group model does not expose `allow_member_pinned_message`
- chat surfaces provide neither a pin/unpin action nor a pinned-message banner/list

If only the UI is added, remote pin-state changes will still drift, group permission checks will be wrong, and pinned content will not survive sync reliably.

## 2. Root Cause Findings

### 2.1 Sync chain drops `is_pinned`

The Flutter SDK already defines `WKMsgExtra.isPinned`, but `WKSyncMsg`, `WKSyncExtraMsg`, and `MessageManager.saveRemoteExtraMsg(...)` do not propagate the field. The app duplicates the same gap in `IMSyncApi._parseSyncMsg(...)`, `IMSyncApi._parseSyncExtra(...)`, and `MessageApi.syncMessageExtras(...)`.

### 2.2 Backend command is not mapped

The server emits `syncPinnedMessage` after pin, unpin, clear-all, and message-delete cleanup. The active Flutter IM command resolver only reacts to `wk_sync_message_extra` and therefore misses the canonical pinned-state invalidation command.

### 2.3 Permission state is incomplete on the app side

The active runtime group model in `lib/data/models/group.dart` exposes `allowViewHistoryMsg` and `joinGroupRemind` but not `allowMemberPinnedMessage`. This prevents the chat layer and group detail settings page from evaluating the real server rule for normal members in groups.

### 2.4 Chat entry points are missing

The active long-press action policy exposes reply, forward, copy, edit, favorite, select, recall, and react, but no pin/unpin action. The main chat shell also has no pinned banner, no pinned list entry point, and no “jump to pinned message” surface even though `messageListProvider.loadAroundOrderSeq(...)` already exists.

## 3. User-Approved Direction

Use the existing Flutter chat mainline and close the pinned-messages slice end to end without pausing for another approval round:

- keep the current Riverpod chat architecture
- reuse existing `showModalBottomSheet` patterns for actions and list surfaces
- reuse `messageListProvider.loadAroundOrderSeq(...)` for jump-to-message
- do not rebuild the full Android pinned-message adapter stack in this pass
- prioritize correct sync and permission semantics over decorative UI

## 4. Target Design

### 4.1 Authoritative pinned-state sync

Treat `message_extra.is_pinned` as the authoritative per-message state in Flutter. The sync chain will be completed in both the shared SDK and the app-side parser layer:

- add `isPinned` to `WKSyncExtraMsg`
- map top-level and nested `is_pinned` values into `WKMsgExtra.isPinned`
- update `saveRemoteExtraMsg(...)` and `wkSyncExtraMsg2WKMsgExtra(...)` so message-extra refreshes mutate the pinned flag locally
- treat `syncPinnedMessage` as a trigger for the same message-extra refresh flow used by other extra updates

This keeps pin state correct for initial sync, incremental extra sync, and remote changes from other devices.

### 4.2 API layer for pinned message operations

Add Flutter API wrappers for the server contracts:

- `POST /v1/message/pinned`
  toggles pin/unpin for a specific message using `channel_id`, `channel_type`, `message_id`, and `message_seq`
- `POST /v1/message/pinned/sync`
  returns `pinned_messages` plus `messages` for a channel after a given `version`
- `POST /v1/message/pinned/clear`
  clears all pinned messages for a channel

The app model for synced pinned rows should keep:

- `messageId`
- `messageSeq`
- `channelId`
- `channelType`
- `isDeleted`
- `version`
- `createdAt`
- `updatedAt`

The chat layer will resolve the visible pinned list by combining the pinned metadata rows with the returned `messages` payload.

### 4.3 Group permission alignment

Expose `allowMemberPinnedMessage` in the runtime `GroupInfo` model and carry it through `GroupApi.getGroupInfo(...)`. Group detail settings will show an owner/admin switch for this setting using the existing `_updateGroupSetting(...)` path and the server key `allow_member_pinned_message`.

Permission behavior in chat should match the backend rule:

- personal chats: pin allowed
- group owner/admin: pin allowed
- normal group member: pin allowed only when `allowMemberPinnedMessage == 1`
- clear-all pinned in groups: manager-only surface

### 4.4 Chat interaction model

Add a pin-aware chat action model and visible pinned surfaces:

- long-press action sheet shows `置顶` or `取消置顶`
- message bubble shows a compact pinned marker when `wkMsgExtra.isPinned == 1`
- chat body shows a pinned banner above the message viewport when the channel has pinned messages
- tapping the banner opens a compact pinned-message list bottom sheet
- tapping a pinned item loads the message via `loadAroundOrderSeq(...)`
- the banner includes a clear-all action only when the current user has permission

The banner/list only needs to support the active high-value flows in this pass:

- see that the channel has pinned content
- browse pinned entries
- jump to the original message
- clear all when allowed

Full Android-style multi-layout rendering for pinned rows is out of scope.

## 5. Scope

### In scope

- SDK and app sync propagation for `is_pinned`
- command routing for `syncPinnedMessage`
- pinned message API wrappers and parsing
- runtime group model support for `allow_member_pinned_message`
- group-detail settings toggle for allowing members to pin
- chat long-press pin/unpin action
- pinned badge in message bubble
- pinned banner/list and jump-to-message in chat
- focused tests for sync, permissions, and chat behavior

### Out of scope

- a fully separate pinned-message page
- Android-equivalent provider registry for pinned-only message rendering
- server contract changes
- pagination-heavy pinned-history UX beyond the server’s incremental sync payload

## 6. Verification Strategy

- unit test `syncPinnedMessage` command mapping
- unit test `GroupInfo` parsing of `allow_member_pinned_message`
- unit test message API parsing of `is_pinned` and pinned sync payloads
- widget test group detail pinned-permission switch rendering and toggling
- unit test chat action policy for pin/unpin exposure and ordering
- widget test pinned indicator and pinned banner/list flows in chat
- focused regression run for adjacent chat/group tests
- Windows debug build verification after the slice is green
