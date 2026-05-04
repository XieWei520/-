# Phase 5B Chat Engagement Parity Design

**Date:** 2026-04-04
**Scope:** Android-first parity compression for chat-mainline message engagement, limited to reaction interaction depth and favorite consistency inside the active conversation scene
**Primary KPI:** Make Flutter chat reactions and message favorite behavior feel Android-faithful on Android while preserving the Phase 4 scene kernel and the Phase 5A action surface contracts
**Strategy:** User-approved sequence `1` - continue the chat mainline instead of switching to environment/device or group/user side projects
**Implementation Direction:** User-approved option `1` - keep the work on the existing scene mainline path instead of creating a second subsystem or a compatibility-only patch path
**Interaction Depth:** User-approved reaction scope `3` - expanded common-reaction picker, with user-approved detail scope `1` - no "who reacted" detail sheet in this round
**Favorite Boundary:** User-approved favorite scope `1` - close the chat-mainline favorite loop only, without adding a favorites page or new favorites entry surface
**Git Status Note:** This working copy still does not expose `.git` metadata, so the spec can be written locally but cannot be committed from this checkout yet

## 1. Problem Statement

Phase 5A aligned the action entry surface, but the engagement layer behind that surface is still only partially aligned with the Android original.

Current Flutter evidence shows that the main chat path now exposes the right entry points but still lacks stronger engagement semantics:

- [chat_message_action_controller.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_message_action_controller.dart) currently handles `favorite` and `toggleReaction`, but both flows still behave like thin action delegates rather than scene-aware engagement operations
- [chat_scene_gateway.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_scene_gateway.dart) already exposes `addFavorite()` and `toggleReaction()`, which means the backend bridge exists and this phase should not invent a second gateway
- [message_bubble.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/widgets/message_bubble.dart) already exposes `onAddReaction` and `onReactionTap`, so the message surface is ready for deeper reaction interaction
- [wk_message_reaction.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_base/msg/widget/wk_message_reaction.dart) already contains `WKMessageReactions` and `WKReactionPicker`, including a reusable `commonEmojis` set
- [reaction_manager.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_base/msg/reaction_manager.dart) already contains message-local reaction cache, toggle semantics, sorting, and update streaming, which is strong groundwork that should be integrated instead of replaced
- [collection_api.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/service/api/collection_api.dart) already supports add, list, search, and delete, but the chat scene still lacks a reliable favorite-consistency layer on top of that API

The remaining gap is therefore not "missing endpoints." The gap is that Flutter still treats message engagement as isolated button calls instead of one Android-style engagement flow with stable local state, clear feedback, and chat-mainline continuity.

## 2. User-Approved Direction

The user approved the following direction for this sub-phase:

- continue on the chat-mainline parity track after Phase 5A instead of switching to Phase 3-style side tracks
- keep all work on the existing scene mainline rather than opening a second engagement subsystem
- close two concrete gaps first: expanded reaction interaction and favorite consistency
- align strictly to Android behavior on Android before broadening into Flutter-only enhancements
- preserve the stronger Flutter architecture and runtime headroom, but do not let architecture ambition break Android semantics

This makes Phase 5B an engagement-compression phase, not a new architecture phase.

## 3. Phase Goals

- Align reaction entry, picker depth, toggle semantics, and bubble rendering with the Android chat experience on Android.
- Align message favorite behavior so the chat mainline has stable success, failure, deduplication, and refresh/re-entry consistency.
- Reuse the existing scene shell, action controller, gateway, message bubble, and reaction manager instead of introducing parallel ownership.
- Keep reaction and favorite updates local and incremental so the message list stays smooth.
- Preserve room for later upgrades such as reaction-detail sheets, richer favorite surfaces, and stronger analytics once Android-faithful mainline behavior is stable.

## 4. Non-Goals

- This phase does not add a favorites page, favorites tab, or new global collection entry.
- This phase does not add a "who reacted" detail sheet or reaction-member roster surface.
- This phase does not take on `@member`, typing indicators, or broader in-chat search parity.
- This phase does not change backend contracts unless implementation proves that a verified backend mismatch must be corrected.
- This phase does not redesign the message bubble away from the Android reference interaction model.

## 5. Scope Boundary

### 5.1 In Scope

- long-press Android reaction action continuity from Phase 5A
- message-bubble reaction `+` entry
- expanded common-reaction picker using the approved common emoji set
- same-emoji cancel behavior
- different-emoji switch behavior
- reaction-chip tap behavior from the bubble surface
- reaction-chip ordering and self-highlight rules
- single-message busy guards for reaction/favorite operations
- optimistic local engagement projection followed by convergence from manager/server data
- message favorite deduplication and stable feedback inside the active chat scene
- refresh/re-entry restoration of known favorite state within the chat mainline

### 5.2 Out Of Scope

- favorites page entry and list interaction
- collection delete or un-favorite UX from the chat timeline
- reaction-detail members panel
- channel-level favorite browsing
- non-chat surfaces that also use collection APIs

## 6. Comparative Findings

### 6.1 Flutter Already Has The Correct Structural Anchors

This is the key reason not to start a new subsystem.

The current Flutter code already exposes the right ownership chain:

- [chat_page_shell.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_page_shell.dart) owns the active conversation surface
- [chat_message_action_controller.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_message_action_controller.dart) already owns message-action dispatch
- [chat_scene_gateway.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_scene_gateway.dart) is already the gateway boundary for scene-triggered backend work
- [message_bubble.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/widgets/message_bubble.dart) already exposes reaction chips and add-reaction hooks

That means the structural problem has already been solved in Phase 4 and Phase 5A. Phase 5B should remain a behavior-compression effort.

### 6.2 Reactions Have Better Groundwork Than Favorites

Flutter already has meaningful reaction foundations:

- a reusable reaction picker
- a cached reaction manager
- local reaction sorting logic
- a reaction update stream

By contrast, favorites currently stop at "send add request and show success feedback." The favorite gap is therefore mainly a state-consistency and recovery gap, not a UI-entry gap.

### 6.3 Android Treats Engagement As Inline Chat Continuity

The Android reference does not treat reactions as a detached page. It treats them as a lightweight inline interaction tied to a specific message and updated directly in the chat timeline.

Reference anchors in [ChatActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java) show this continuity:

- reaction refresh comparison logic around line `1620`
- reaction merge and item refresh behavior around lines `2583-2607`

Flutter does not need to mimic the Android class structure, but it should mimic this inline, message-scoped continuity.

## 7. Target Design

Phase 5B keeps the Phase 4 scene kernel and the Phase 5A action-surface policy, then adds one thin engagement layer across reaction and favorite behavior.

### 7.1 Engagement Ownership Model

Keep ownership on the existing mainline path:

- `ChatPageShell` remains assembly and scene wiring only
- `ChatMessageActionController` becomes the main engagement action coordinator
- `ChatSceneGateway` remains the only backend bridge
- `MessageBubble` remains the display surface for reaction chips and add-reaction entry
- message-level engagement projection stays close to the chat view model and timeline rather than becoming a new global subsystem

Rules:

- do not introduce a second scene controller
- do not introduce a second reaction cache if `ReactionManager` already owns that concern
- only add a thin scene-facing engagement projection file if the existing view model cannot represent the needed local state clearly

### 7.2 Reaction Interaction Model

Reactions should be available from two entry points:

- long-press reaction action
- bubble reaction-row `+`

Both entries must open the same lightweight reaction picker contract.

Rules:

- the picker should appear near the target message when feasible, not as a heavy full-screen detour
- picking the same emoji again cancels the existing reaction
- picking a different emoji switches the user reaction for that message
- tapping an existing reaction chip uses the same toggle/switch semantics
- the UI may optimistically reflect the action, but final truth must converge from the manager/server-backed reaction state

### 7.3 Favorite Consistency Model

Favorites remain a long-press action only in this phase.

The required consistency contract is:

- success feedback must be explicit
- failure feedback must be explicit
- duplicate in-flight favorite requests for the same message must be suppressed
- refresh or re-entry must restore the best known favorite state for that message inside the chat mainline
- failure must never leave a fake "already favorited" local state behind

This does not require a visible permanent favorite icon in the bubble. It does require deterministic local scene behavior.

## 8. Android Reference Anchors

The Phase 5B implementation is pinned to these Android references:

- [ChatActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java)
  - reaction imports and chat wiring around line `119`
  - reaction refresh comparison around lines `1620-1629`
  - reaction merge and partial refresh behavior around lines `2583-2607`

Flutter may use different files and widgets, but the accepted target is the Android behavior:

- reactions behave as a direct message-level inline interaction
- reaction updates resolve on the affected message rather than by resetting the whole page
- engagement actions return the user to a stable chat state immediately

## 9. Parity Contracts

### 9.1 Reaction Entry And Picker

Requirements:

- long-press reaction action and bubble `+` must open the same picker contract
- the picker must expose the approved expanded common reaction set
- the currently selected user reaction must be visually distinguishable in the picker
- the picker must feel lightweight and message-scoped, not like a detached tool page

### 9.2 Reaction Toggle And Bubble Rendering

Requirements:

- tapping the same emoji removes the current user reaction
- tapping a different emoji switches the user reaction
- reaction chips must render in count-descending order
- the current user's reaction chip must be visually highlighted
- tapping a rendered chip must follow the same toggle/switch semantics as the picker
- reaction changes must update the affected message without causing a list-wide rebuild

### 9.3 Favorite Consistency

Requirements:

- the chat long-press favorite action must still be the only favorite entry in this round
- repeated favorite taps during an in-flight request for the same message must not issue duplicate dirty requests
- success and failure feedback must be user-visible and testable
- if the chat scene refreshes or the user re-enters the conversation, known favorite state must be recoverable for the message
- a failed request must not permanently mutate the message into an already-favorited local state

### 9.4 Busy And Recovery Rules

Requirements:

- reaction/favorite busy state must be message-scoped, not page-scoped
- one busy message must not block engagement on unrelated messages
- all failed engagement flows must return the scene to a stable state
- no partial local state may survive if backend confirmation fails

## 10. UI And Interaction Rules

### 10.1 Reaction Picker Rules

- prefer a small anchored or proximity-based surface near the tapped/long-pressed message when feasible
- reuse [WKReactionPicker](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_base/msg/widget/wk_message_reaction.dart) rather than inventing a second emoji vocabulary
- highlight the current user selection clearly enough that a same-emoji tap reads as a cancel action
- preserve Android-first interaction feel on Android even if the internal Flutter widget tree differs

### 10.2 Reaction Chip Rules

- chips should remain close to the message bubble, not separated into a detached footer region
- chip count ordering must remain stable and deterministic
- chip taps should feel immediate
- add-reaction entry should stay visually subordinate to existing reactions, matching the Android inline-engagement feel

### 10.3 Favorite Feedback Rules

- favorite success feedback should be explicit, brief, and non-blocking
- failure should clearly communicate that the action did not complete
- duplicate taps during busy state should not create duplicate feedback spam
- this round should not expose a permanent star or badge just to simulate consistency

## 11. Data And State Design

Phase 5B should stay intentionally narrow and should reuse existing engagement primitives wherever possible.

### 11.1 Reaction Source Of Truth

Use [reaction_manager.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_base/msg/reaction_manager.dart) as the low-level reaction source of truth for:

- preparing message reactions from message payloads
- applying local toggle semantics
- streaming reaction updates
- keeping reaction ordering stable

The scene layer may project this data for UI convenience, but it should not fork reaction truth into a second independent cache.

### 11.2 Favorite Registry Projection

Introduce only a thin favorite projection keyed by stable message identity, such as `messageId` with `clientMsgNo` fallback.

It should be able to represent:

- known favorited
- unknown or not yet resolved
- in-flight favorite request
- last-operation failure reset

It should not:

- become a second collection page model
- take ownership of collection browsing
- imply un-favorite support that this phase does not ship

### 11.3 Message-Level Engagement State

If implementation needs extra UI state, keep it message-scoped and lightweight, for example:

- reaction busy
- favorite busy
- favorite known state
- picker visibility/target identity if the scene needs it

This should live close to the chat scene/view model path and should not spread across unrelated modules.

## 12. Risks And Mitigations

### 12.1 Replacing Existing Reaction Logic Instead Of Reusing It

Risk:

- Phase 5B could accidentally duplicate `ReactionManager` behavior and create split reaction truth

Mitigation:

- treat `ReactionManager` as foundational infrastructure
- add only scene-facing projection and orchestration where needed

### 12.2 Fake Favorite Consistency

Risk:

- a local flag could say "favorited" even after request failure or app refresh

Mitigation:

- treat failure as authoritative rollback
- keep favorite state keyed by stable message identity
- verify refresh and re-entry recovery explicitly in tests

### 12.3 Whole-Page Rebuild Regressions

Risk:

- reaction or favorite updates could regress the chat page back into broad rebuild behavior

Mitigation:

- keep busy state message-scoped
- route UI updates through the affected message projection only
- add focused tests for partial message updates and stable chat flow

### 12.4 Android-Semantic Drift

Risk:

- Flutter could expose deeper reaction UI but still miss the Android interaction feel

Mitigation:

- lock entry points, chip behavior, ordering, and feedback into parity tests
- keep this round intentionally narrow by excluding reaction-member details and favorites-page work

## 13. Test Strategy And Acceptance

### 13.1 Controller And State Tests

- extend [chat_message_action_controller_test.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/chat/chat_message_action_controller_test.dart) or add a focused engagement controller test file if state complexity grows
- verify same-message favorite deduplication
- verify failure rollback for favorites
- verify same-emoji cancel and different-emoji switch semantics at the controller/orchestration boundary when needed
- verify message-scoped busy guards do not block unrelated messages

### 13.2 Widget And Flow Tests

- extend [chat_page_scene_flow_test.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/chat/chat_page_scene_flow_test.dart) for `long press -> reaction picker -> chip render -> chip tap -> toggle/cancel`
- verify bubble `+` and long-press reaction entry both reach the same picker behavior
- verify chips render in count-desc order and highlight the current user's reaction
- verify favorite success/failure feedback is visible and stable in the chat mainline

### 13.3 Android Parity Tests

- extend [chat_page_android_parity_test.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/chat/chat_page_android_parity_test.dart)
- lock the Android-facing labels, entry positions, and interaction sequence for the favorite and reaction actions
- verify the Flutter Android path preserves the same interaction meaning as the Android original even if the visual implementation remains Flutter-native

### 13.4 Existing Experience And Regression Tests

- preserve [message_bubble_experience_test.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/test/modules/chat/message_bubble_experience_test.dart) coverage for the real emoji set
- ensure all Phase 5A chat-mainline tests remain green
- treat any failure in long-press ordering, forward flow, or selection cleanup as a regression outside this phase's allowed scope

### 13.5 Done Definition

Phase 5B is complete only when all of the following are true:

- users can complete a full reaction loop from both the long-press reaction entry and bubble `+`
- reactions support expanded common emoji selection, cancel, switch, and chip retap behavior
- reaction chips render in stable count-desc order and highlight the current user's reaction
- the chat-mainline favorite action has explicit success/failure feedback, no duplicate dirty submits, and recoverable known state after refresh or re-entry
- the implementation does not reintroduce page-wide instability or regress Phase 5A action-surface parity

## 14. Remote Debugging Guidance

This sub-phase is expected to be mostly local scene, widget, and controller work.

Remote debugging through `ssh root@103.207.68.33` is approved and should be used when local behavior and deployed behavior disagree, especially for:

- reaction toggle responses that do not match local assumptions
- reaction sync or convergence issues after local optimistic updates
- favorite API responses that make recovery state ambiguous
- message refresh behavior that appears correct locally but diverges against the deployed backend

Remote inspection is allowed support work, not the primary design center of this phase.

## 15. Exit Criteria For Phase 5B

This sub-phase is complete only when:

- reaction interaction on Android feels like a direct continuation of the Android chat mainline
- favorite behavior inside the active chat scene is consistent and recoverable instead of "fire request and hope"
- the work remains on the existing scene mainline path without creating a second engagement subsystem
- the codebase is ready to move into the next approved chat-mainline parity slice without having to revisit reaction or favorite foundations again

Phase 5B is intentionally focused. Its success condition is not "more engagement features." Its success condition is that the approved chat-mainline engagement slice stops feeling provisional and starts behaving like the Android original, while preserving the stronger Flutter architecture for later upgrades.
