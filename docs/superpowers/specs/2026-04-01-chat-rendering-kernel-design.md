# Chat Rendering Kernel Design

**Date:** 2026-04-01
**Scope:** Android / iOS first, aggressive refactor allowed
**Primary KPI:** Message list scrolling and input interaction smoothness

## 1. Problem Statement

The current chat implementation in [chat_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) mixes message list rendering, composer state, reminder state, read synchronization, panel toggles, search overlays, and message side effects inside one large stateful widget. This creates several high-risk performance patterns:

- Dense `setState` usage on the main chat page causes unrelated UI regions to rebuild together.
- Message-related side effects run from `build`, including reply restoration and read-sync scheduling.
- Message presentation work is still performed on the scroll hot path, including structured payload decoding in [message_bubble.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart).
- Message collection updates rely on list-level recomputation in [conversation_provider.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\providers\conversation_provider.dart), which scales poorly as history grows.
- Frequent visual updates such as reactions, banners, and composer toggles are not isolated with repaint boundaries.

This design defines a new chat rendering kernel whose job is to keep the viewport stable, keep the composer independent, and move expensive work out of the UI thread hot path.

## 2. Goals

- Keep chat scrolling at a commercial-quality baseline on Android and iOS.
- Ensure typing, panel toggles, and draft changes do not rebuild the message viewport.
- Ensure new messages, reactions, and message refreshes update only affected items.
- Remove scroll-path JSON decoding and repeated preview derivation from widget build methods.
- Eliminate `build`-time side effects from the main chat screen.
- Establish a reusable pattern that later modules can adopt.

## 3. Non-Goals

- This phase does not redesign message visuals.
- This phase does not replace the entire IM SDK data layer.
- This phase does not yet optimize non-chat modules beyond extracting shared primitives when needed.

## 4. Current Hotspots

### 4.1 Main Page Coupling

[chat_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) currently owns:

- title and subtitle resolution
- reminder banner state
- message viewport rendering
- reply state restore
- read synchronization scheduling
- draft throttling and persistence
- panel visibility
- attachment workflows
- search and detail popup flows

This makes message scrolling sensitive to unrelated transient UI state.

### 4.2 Build-Time Side Effects

`build` currently performs or triggers:

- message key cleanup
- reply restoration from draft
- read-sync signature checks and post-frame read marking

This makes rendering impure and increases the chance of repeated work during frame churn.

### 4.3 Scroll Hot Path Decode

[message_bubble.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart) may call `jsonDecode` from `_decodeStructuredPayload()` during widget build. For long chat histories and fast fling, this directly competes with layout and paint time.

### 4.4 List-Level Recompute

[conversation_provider.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\providers\conversation_provider.dart) merges and refreshes messages by recreating large list snapshots. This is acceptable for small lists but is not a good kernel for long-lived IM conversations.

## 5. Target Architecture

The chat screen will be split into four layers with narrow responsibilities.

### 5.1 `ChatPageShell`

Responsibilities:

- route parameters
- navigation lifecycle
- app bar and page scaffold
- wiring controller providers together

Rules:

- no message parsing
- no viewport-specific state
- no draft side effects

### 5.2 `ChatViewportController`

Responsibilities:

- stable ordered message identity list
- incremental message insertion and refresh
- pagination state
- viewport-visible read candidate tracking
- locating a target message by identity

Rules:

- own message-list side effects, not widget `build`
- expose immutable view models for rendering
- never decode structured payload in widget build

### 5.3 `ChatComposerController`

Responsibilities:

- input text
- reply target
- face/function panel visibility
- draft restore and throttled persistence

Rules:

- composer updates must not rebuild the message list
- draft save scheduling must live in controller logic, not page `build`

### 5.4 `ChatTransientUiState`

Responsibilities:

- local loading flags
- context menus
- modal search state
- ephemeral dialog state

Rules:

- short-lived UI states remain local and isolated
- transient state must not own message list data

## 6. Rendering Strategy

### 6.1 Viewport Isolation

The message viewport becomes its own widget subtree:

- `ChatMessageViewport`
- `ChatMessageList`
- `ChatMessageListItem`

The subtree will sit behind a `RepaintBoundary` so composer animation and panel toggles do not invalidate the message region.

### 6.2 Composer Isolation

The composer subtree becomes:

- `ChatComposer`
- `ChatReplyPreview`
- `ChatPanelSwitcher`

The composer also gets its own `RepaintBoundary`, because text editing and panel transitions are frequent.

### 6.3 Banner Isolation

Reminder banners and similar frequently changing chips will be isolated above the viewport. They must not sit in the same repaint region as the message list.

### 6.4 Stable Item Identity

Each rendered message item will use one stable identity derived from:

1. `messageID`
2. fallback `clientMsgNO`
3. fallback deterministic order-seq identity

The viewport controller will maintain an identity-to-index map so targeted refresh and `findChildIndexCallback`-style recovery become possible when the implementation moves to a sliver delegate.

## 7. Data Transformation Strategy

### 7.1 Introduce Message View Models

Widgets will stop consuming raw `WKMsg` directly where presentation requires derived data. A new immutable chat item view model will precompute:

- effective content type
- parsed structured payload
- preview text
- sender display info
- status info
- reaction summary
- reply summary

### 7.2 Decode Outside Build

Structured payload decoding currently done in [message_bubble.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart) will move into a mapper layer. The mapper will:

- parse once per message version
- cache by message identity plus mutation marker
- return a lightweight immutable render object

If payload parsing becomes measurably heavy for some content classes, those transforms will move to `compute` or `Isolate.run`.

### 7.3 Incremental Merge Model

The provider layer will stop rebuilding the full rendered message list for single-item updates. The new merge strategy will support:

- prepend new messages
- patch one existing message
- remove one hidden or deleted message
- append historical page

without full list normalization on every event.

## 8. State and Side-Effect Rules

### 8.1 No Side Effects in `build`

The following must leave widget build methods:

- draft reply restoration
- read-sync scheduling
- message identity cleanup
- first-load title sync work

Instead:

- controller `init` handles restoration
- listeners handle message stream updates
- post-frame work is triggered from controller state transitions only

### 8.2 Read Synchronization

Read marking will be driven by visible message state, not every parent rebuild. The controller will:

- track unread readable message identities
- debounce read submission
- skip re-submission when signature is unchanged

### 8.3 Draft Persistence

Draft persistence will move fully into the composer controller. The page only binds the controller. Draft saves will be:

- throttled
- cancelable
- content-signature aware

This avoids redundant local and remote draft writes while typing.

## 9. Widget-Level Optimization Rules

### 9.1 Required `const`

All static widget trees introduced during the refactor must be `const` where possible. New helper widgets should be split specifically to unlock const-construction and reduce rebuild scope.

### 9.2 Required `RepaintBoundary`

Must be added around:

- message viewport root
- composer root
- animated reaction cluster if kept stateful
- waveform / typing / similar continuously animating widgets

### 9.3 Long List Rules

The message list implementation must support:

- lazy building only
- stable item keys
- predictable pagination trigger
- no repeated full-list scans during build

If we remain on `ListView.builder` in phase A, the controller must still expose index lookup and stable identity maps so migration to slivers is trivial.

## 10. File-Level Design

### New Files

- `lib/modules/chat/chat_page_shell.dart`
- `lib/modules/chat/chat_viewport_controller.dart`
- `lib/modules/chat/chat_composer_controller.dart`
- `lib/modules/chat/chat_message_view_model.dart`
- `lib/modules/chat/chat_message_mapper.dart`
- `lib/modules/chat/widgets/chat_message_viewport.dart`
- `lib/modules/chat/widgets/chat_message_list_item.dart`
- `lib/modules/chat/widgets/chat_composer.dart`
- `lib/modules/chat/widgets/chat_reply_preview.dart`

### Existing Files to Refactor

- [chat_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart)
- [conversation_provider.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\providers\conversation_provider.dart)
- [message_bubble.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart)
- [draft_manager.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\draft_manager.dart)

## 11. Testing Strategy

### 11.1 Unit Tests

- message identity derivation
- incremental merge behavior
- message mapper decode and cache behavior
- draft throttle and reply restore behavior
- read-sync debounce and signature behavior

### 11.2 Widget Tests

- typing only rebuilds composer subtree
- reaction updates only rebuild affected message item
- new message insertion preserves scroll behavior
- reminder banner changes do not rebuild viewport subtree

### 11.3 Manual Profiling Targets

On Android profile mode:

- rapid input in an active chat
- long downward and upward fling on large history
- receive burst of inbound messages
- toggle emoji/function panels repeatedly

Success means no visible jank spikes attributable to scroll-path decode or whole-page rebuild coupling.

## 12. Risks and Mitigations

### Risk: behavior regressions while splitting a large page

Mitigation:

- preserve external route contract
- add narrow tests around reply, draft, and reminder flows before moving code

### Risk: message identity mismatches break targeted refresh

Mitigation:

- formalize one identity policy with tests
- never let widget keys invent fallback logic independently

### Risk: controller explosion

Mitigation:

- keep only four state domains
- transient UI state stays local if it does not affect shared rendering

## 13. Acceptance Criteria

The design is considered implemented for phase A when:

- chat typing does not rebuild the message viewport
- message viewport renders from precomputed view models
- structured payload decode no longer happens in widget build
- chat screen `build` no longer schedules read-sync or reply restoration side effects
- message list updates are incremental for insert and patch cases
- viewport, composer, and animated hotspots are repaint-isolated

## 14. Out of Scope Follow-Up

After this design lands, the next specs should target:

- conversation list refresh kernel
- contacts presence refresh kernel
- IM sync and concurrency hardening
- memory lifecycle audit across media-heavy screens
