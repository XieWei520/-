# Phase 4 Chat Mainline Rearchitecture Design

**Date:** 2026-04-04
**Scope:** Android-first chat mainline rebuild for the active conversation screen and its adjacent subflows
**Primary KPI:** Establish a high-performance Flutter chat kernel that can later be driven to strict TangSengDaoDao Android parity on Android
**Strategy:** User-approved strategy `3` - rebuild the chat module around a stronger kernel instead of continuing patch-style feature additions
**Acceptance Order:** User-approved order `2` - land the stronger kernel first, then compress behavior and interaction toward Android-reference parity
**Git Status Note:** This working copy does not currently expose `.git` metadata, so the spec can be written locally but cannot be committed from this checkout yet

## 1. Problem Statement

The Flutter app already contains substantial chat-related code, but the active chat path is still not organized around one authoritative conversation-scene architecture.

Current evidence from the Flutter codebase shows a split state:

- the active path at [chat_page.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_page.dart) is still responsible for too many concerns and still carries compatibility placeholders for adjacent flows
- message rendering groundwork exists at [message_bubble.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/widgets/message_bubble.dart), which means the project is not starting from zero
- an earlier rendering-focused design already exists at [2026-04-01-chat-rendering-kernel-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-01-chat-rendering-kernel-design.md), but it is narrower than the now-approved chat-mainline scope

By contrast, the Android reference at [ChatActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java) is not just a message screen. It is the main orchestration surface for:

- message timeline ownership
- composer and panel switching
- long-press actions
- reply and edit state
- search entry
- multi-select and forward initiation
- recall and reaction flows
- group-chat-specific decision points

The parity gap is therefore not merely "missing buttons." The gap is that Flutter still lacks one strong chat scene kernel that can own the same mainline orchestration depth.

## 2. User-Approved Direction

The user approved the following direction for this phase:

- do not continue growing the current chat path through piecemeal feature patches
- rebuild the chat mainline around a stronger, more modern, more scalable kernel
- allow short-term behavior differences from Android while the new kernel is taking over
- after the kernel is stable, push the product surface to strict Android-reference parity on Android
- once parity is achieved, continue iterating on performance and experience so Flutter clearly exceeds the Android reference in runtime quality

This is intentionally more ambitious than a direct gap-fill because the current codebase has already crossed the threshold where more patching would multiply future rework.

## 3. Phase Goals

- Establish one authoritative chat mainline architecture for the active conversation scene.
- Rebuild the conversation screen around explicit state orchestration instead of page-local scattered state.
- Bring the active conversation page and its adjacent subflows onto a high-performance timeline and composer kernel.
- Preserve the Android-reference surface semantics so later parity work can be compressed onto one stable architecture.
- Reduce rebuild scope, scroll instability, keyboard jitter, and transient-state loss under real IM usage.
- Make reply, forward, multi-select, favorites, mentions, recall, reactions, and in-chat search first-class scene capabilities rather than isolated button handlers.

## 4. Non-Goals

- This phase does not rebuild the conversation list page.
- This phase does not rebuild group-detail pages, pinned-messages pages, or voice/video call flows.
- This phase does not introduce new product concepts that do not already serve Android-reference parity or the approved kernel upgrade.
- This phase does not require immediate visual redesign away from the Android reference.
- This phase does not treat Flutter-only experiments as scope items unless they directly improve the approved chat kernel or verified Android-parity flows.

## 5. Scope Boundary

### 5.1 In Scope

This phase covers the active conversation page and the adjacent subflows directly coupled to it:

- message timeline rendering and pagination
- composer, keyboard, and bottom-panel orchestration
- reply state
- forward initiation and forward-preparation flow
- multi-select mode
- favorites entry flow
- `@member` insertion and candidate flow in group chat
- recall
- message reactions
- in-chat search
- state transitions between normal, reply, select, search, and action-menu-driven operations

### 5.2 Out of Scope

The following items are intentionally deferred:

- pinned-message standalone page
- full group-management rebuild
- call entry and call signaling
- broader conversation-list redesign
- unrelated feature experiments that change the Android-reference surface contract

## 6. Current Comparative Findings

### 6.1 Flutter Already Has Usable Pieces

The current Flutter app is not missing all chat functionality. It already has:

- message render primitives
- forwarding-related groundwork
- reply-related groundwork
- draft and message utility layers
- chat-oriented tests and supporting providers

This means the correct move is not a greenfield rewrite detached from the existing codebase. The correct move is to reorganize and harden the strongest existing pieces under one scene kernel.

### 6.2 The Android Reference Is Scene-Oriented

The Android reference chat implementation centralizes orchestration across timeline, panel, actions, and scene transitions. That is the correct behavioral target for parity work. Flutter must therefore stop treating reply, search, action menus, and multi-select as loosely connected page extras.

### 6.3 The Existing Chat Rendering Design Is Necessary But Not Sufficient

The earlier chat-rendering design correctly identified rebuild coupling and rendering hot-path issues. This Phase 4 design adopts that direction, but expands it from a rendering optimization effort into a full conversation-scene rearchitecture.

## 7. Target Architecture

The new chat mainline will be organized around one scene shell, one scene controller, and several narrowly bounded controllers that cooperate through explicit intents and immutable scene state.

### 7.1 `ChatSceneShell`

Responsibilities:

- route parameters
- page lifecycle
- Android back behavior
- keyboard visibility wiring
- page scaffold composition

Rules:

- no message merge logic
- no feature-specific business branching
- no direct ownership of scene modes

### 7.2 `ChatSceneController`

Responsibilities:

- act as the single source of truth for conversation-scene state
- receive user intents and system events
- coordinate mode transitions
- aggregate sub-controller outputs into one immutable scene model

Rules:

- all primary mode transitions must pass through this controller
- UI widgets may read state slices, but must not mutate cross-scene state directly

### 7.3 `TimelineEngine`

Responsibilities:

- own ordered message identity and viewport-facing timeline state
- merge new messages, history pages, recall updates, reaction updates, and message refreshes
- maintain stable item identity and position recovery

Rules:

- incremental updates must not force full-list rebuilds
- timeline merges must be deterministic and idempotent

### 7.4 `ComposerController`

Responsibilities:

- text input
- draft persistence
- reply target
- `@member` composition context
- panel toggles
- send preflight validation

Rules:

- composer changes must not rebuild the timeline subtree
- draft and reply restore must never depend on widget `build`

### 7.5 `MessageActionController`

Responsibilities:

- long-press action resolution
- reply initiation
- recall execution
- favorites action dispatch
- reaction action dispatch
- forward initiation

Rules:

- action availability must be computed from message state, user role, and channel context
- failure paths must always resolve back to a stable scene state

### 7.6 `SelectionController`

Responsibilities:

- enter and exit multi-select mode
- maintain the selected-message set
- expose batch-action availability

Rules:

- selection state must stay internally consistent while the timeline changes
- multi-select mode disables conflicting normal-mode interactions

### 7.7 `SearchController`

Responsibilities:

- own in-chat search mode
- manage query state and result state
- jump from search results into the timeline while preserving return context

Rules:

- search mode may take over top-level UI affordances, but must not destroy the active timeline context

### 7.8 `ChatGateway`

Responsibilities:

- unify IM SDK events, local persistence, and HTTP-backed feature actions behind a stable boundary
- translate external contracts into scene-oriented domain models

Rules:

- the UI layer must not directly depend on raw mixed backend and SDK semantics
- gateway contracts must remain stable even if low-level SDK usage evolves later

## 8. Scene State Model And Transition Rules

### 8.1 Primary Modes

The scene owns one primary mode at a time:

- `normal`
- `replying`
- `selecting`
- `searching`

Long-press action presentation is treated as an ephemeral overlay state, not a second primary mode.

### 8.2 Transition Rules

- `normal -> replying`: enter from a valid reply action on a message
- `replying -> normal`: exit when the reply is canceled or the send action completes successfully
- `normal -> selecting`: enter from a multi-select action
- `selecting -> normal`: exit on cancel or after a completed batch action
- `normal -> searching`: enter from the in-chat search entry
- `searching -> normal`: exit while restoring prior viewport anchor and composer context

### 8.3 Mutual-Exclusion Rules

- `replying`, `selecting`, and `searching` are mutually exclusive
- entering one primary mode must cleanly resolve the previous one
- multi-select disables normal composer actions and second-level long-press menus
- search takes control of search-specific UI, but does not discard the timeline session state

### 8.4 Failure Rules

- every failed action must return the page to a stable state
- no failed batch or async operation may leave half-entered UI modes behind
- backend uncertainty must surface as actionable feedback, not hidden state drift

## 9. Capability Parity Contracts For This Phase

This phase does not consider a feature complete unless the trigger path, visible feedback, and exit behavior all align with the intended Android semantics.

### 9.1 Reply

Requirements:

- enter from a message action
- show a reply-preview strip in the composer
- allow explicit cancel
- clear reply state on successful send
- render reply context in the sent message bubble
- support jumping from rendered reply preview toward the original message target when available

### 9.2 Forward

Requirements:

- support single-message forward initiation
- support multi-select forward initiation
- keep message selection and forward-preparation steps consistent
- provide deterministic success and failure feedback

### 9.3 Multi-Select

Requirements:

- enter from a message action
- switch top and bottom action affordances into batch mode
- preserve selection consistency during scroll and incremental timeline updates
- exit cleanly without leaking batch UI state into normal mode

### 9.4 Favorites

Requirements:

- allow message-level favorite action from the action menu
- provide immediate success and failure feedback
- handle unsupported content types explicitly rather than silently failing

### 9.5 `@Member`

Requirements:

- activate candidate lookup in group chat from composer input
- support insertion, deletion-aware tracking, and final outgoing mention semantics
- keep candidate filtering responsive under large member sets

### 9.6 Recall

Requirements:

- compute visibility from message ownership, permissions, and time-window rules
- update the timeline immediately after success
- resolve failures without leaving stale optimistic UI behind

### 9.7 Reactions

Requirements:

- allow quick reaction entry from the message action surface
- merge reaction changes incrementally into the message item
- render reaction state without list-wide refresh

### 9.8 In-Chat Search

Requirements:

- enter a distinct search mode
- maintain query, result list, and jump behavior
- return to the prior conversation position and composer context on exit

## 10. Performance And Experience Requirements

The stronger kernel must materially improve runtime quality even before full Android parity is complete.

### 10.1 Timeline Merge Rules

- new messages, history pages, recall updates, and reaction updates must flow through one incremental merge pipeline
- the merge pipeline must support targeted patching instead of list-wide regeneration

### 10.2 Viewport Stability

- history pagination must preserve a stable viewport anchor
- local scene changes such as composer toggles must not cause visible timeline jumps

### 10.3 Render Isolation

- the timeline subtree and the composer subtree must rebuild independently
- frequently changing overlays and toolbars must be isolated from the scroll hot path

### 10.4 Draft And Context Recovery

- text drafts must survive scene churn
- reply context and relevant composer context must be restorable
- search exit must restore the prior timeline anchor and input context

### 10.5 Weak-Network Resilience

- sending, recall, reaction, and favorites flows must present durable pending, success, failure, and retry outcomes
- the scene must never get stuck in an indeterminate mode because a network call partially failed

### 10.6 Scalable Group Behavior

- `@member` filtering and large-member lookup must not block the render path
- heavy transformations may move off the UI hot path when measurement proves that necessary

## 11. Migration Strategy

This phase will not do a one-shot replacement. It will use a controlled takeover model.

### 11.1 Step 1: Kernel Skeleton

Introduce the new scene shell, scene controller, timeline engine, and composer controller while preserving a minimal production-safe conversation flow.

### 11.2 Step 2: Mainline Takeover

Route the active conversation page through the new scene kernel so it becomes the authoritative path for normal chat use.

### 11.3 Step 3: Adjacent Subflow Compression

Port adjacent flows onto the new kernel one capability at a time:

- reply
- recall
- reactions
- multi-select
- forward
- favorites
- `@member`
- in-chat search

### 11.4 Step 4: Android-Parity Compression

Once the kernel is stable, compare each active behavior against the Android reference and correct trigger positions, mode exits, menu ordering, and feedback details until Android behavior is aligned on Android.

### 11.5 Step 5: Legacy Path Reduction

After the new path is stable, degrade old chat compatibility entry points into wrappers or retire them from the main product route.

## 12. Risks And Mitigations

### 12.1 State Pollution Between Old And New Paths

Risk:

- old page-local chat state and new scene-kernel state can interfere during migration

Mitigation:

- define one authoritative route owner early
- isolate legacy compatibility code behind thin wrappers instead of dual active ownership

### 12.2 Timeline Inconsistency During Incremental Merge

Risk:

- duplicate messages, stale recall state, or reaction drift can appear if merge rules are not deterministic

Mitigation:

- enforce stable message identity
- verify deterministic merge behavior with focused tests before enabling wider feature takeovers

### 12.3 Mode-Collision Regressions

Risk:

- reply, search, and multi-select can overlap in broken ways if the scene controller does not own transitions strictly

Mitigation:

- keep one explicit primary-mode model
- test transitions and failure exits directly at the controller level

### 12.4 Backend Contract Drift

Risk:

- reaction, recall, favorites, mentions, or search semantics may differ between Flutter assumptions and the deployed backend behavior

Mitigation:

- validate uncertain contracts against the deployed environment through approved SSH access when needed
- treat backend-observed behavior as the final truth for feature wiring, not stale assumptions

## 13. Test Strategy

The implementation plan derived from this spec must include four layers of verification.

### 13.1 Unit Tests

- scene-mode transitions
- timeline merge behavior
- selection-set behavior
- composer draft and reply restore
- search state restoration

### 13.2 Widget And Component Tests

- composer reply strip
- long-press action menu behavior
- multi-select toolbar behavior
- `@member` candidate UI behavior
- search-mode entry and exit behavior

### 13.3 Flow Tests

- normal chat send path on the new kernel
- reply flow
- multi-select to forward flow
- recall flow
- reaction flow
- search jump and return flow

### 13.4 Android Manual Regression

- long-list scroll stability
- keyboard and panel switching
- weak-network send and retry behavior
- mode switching smoothness
- group-chat `@member` responsiveness

## 14. Remote Debugging Guidance

Direct server inspection through `ssh root@103.207.68.33` is approved for this phase and should be used when backend behavior is uncertain.

Remote validation is especially appropriate when:

- reaction behavior does not match the client assumption
- recall visibility or response semantics are unclear
- search results or member lookup behavior appear inconsistent with the Android reference
- timeline mutations seem correct locally but the backend or IM event stream suggests different truth

## 15. Exit Criteria For Phase 4

This phase is complete only when all of the following are true:

- the active conversation screen uses the new scene kernel as its authoritative path
- reply, forward, multi-select, favorites, `@member`, recall, reactions, and in-chat search all execute through the new kernel
- no primary-mode collisions remain between normal, reply, select, and search states
- timeline updates no longer depend on broad page rebuilds
- the architecture is ready for strict Android-parity compression without another kernel rewrite

This phase does not require every Android-reference detail to be perfect before the kernel lands. It does require the kernel takeover to be real, stable, and strong enough that the next step can focus on parity compression instead of structural rescue.
