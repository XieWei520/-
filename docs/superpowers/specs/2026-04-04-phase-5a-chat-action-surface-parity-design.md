# Phase 5A Chat Action Surface Parity Compression Design

**Date:** 2026-04-04
**Scope:** Android-first parity compression for the active chat action surface, forward surface, and multi-select batch surface
**Primary KPI:** Make Flutter chat long-press actions, forward flow, and batch-selection behavior match TangSengDaoDao Android semantics on Android without destabilizing the Phase 4 scene kernel
**Strategy:** User-approved sequence `1` - action surface first, then search parity, then reply/composer interaction parity
**Acceptance Order:** Preserve the Phase 4 architecture and compress behavior toward Android instead of rebuilding the action path a second time
**Git Status Note:** This working copy still does not expose `.git` metadata, so the spec can be written locally but cannot be committed from this checkout yet

## 1. Problem Statement

Phase 4 established a real scene-owned chat mainline, but the most visible action surfaces are still only functionally complete rather than Android-faithful.

Current Flutter evidence shows that the new kernel is in place but the action semantics remain generic:

- [chat_message_action_sheet.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/widgets/chat_message_action_sheet.dart) currently exposes a fixed English action list with no Android-style ordering or availability policy
- [chat_selection_toolbar.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/widgets/chat_selection_toolbar.dart) currently renders a very thin batch bar instead of an Android-aligned selection surface
- [forward_message_page.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/forward_message_page.dart) currently provides a usable forward picker, but it still behaves like a generic Flutter utility page rather than the Android reference chooser flow
- [chat_page_shell.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_page_shell.dart) already routes long-press, multi-select, and forward through the scene kernel, which means the remaining gap is now mostly parity compression rather than structural rescue

By contrast, the Android reference owns these same flows as highly opinionated action surfaces:

- [ChatActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java) controls message reply entry, forward entry, reply clearing, and post-action exits in one authoritative chat scene
- [ChooseContactsActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/contacts/ChooseContactsActivity.java) defines forward-target search, selection, confirm-button state, and single-vs-multi choose behavior

The remaining gap is therefore not “missing capability.” The gap is that Flutter still presents a simplified action surface that does not yet feel or behave like the Android original.

## 2. User-Approved Direction

The user approved the following direction for this sub-phase:

- keep the stronger Phase 4 scene architecture intact
- do not restart the chat action path with a second architecture rewrite
- compress the visible action surface toward strict Android behavior on Android
- prioritize long-press actions, forwarding, and multi-select before search-mode parity and before composer/keyboard parity
- preserve room to later exceed Android performance and smoothness, but only after Android parity semantics are protected

This makes Phase 5A an interaction-compression phase, not a kernel phase.

## 3. Phase Goals

- Align the long-press action sheet to Android semantics for order, labels, and visibility rules.
- Align single-message forward and multi-select forward to the Android target-selection flow.
- Align multi-select batch mode entry, toolbar behavior, and exit rules to Android chat behavior.
- Preserve the Phase 4 scene controller as the only owner of primary chat mode transitions.
- Keep Flutter compatibility wrappers thin so old entry points cannot drift away from the new mainline.

## 4. Non-Goals

- This phase does not rebuild in-chat search mode.
- This phase does not tune keyboard, emoji panel, more-panel, or send-feedback interactions beyond what is required for action-surface stability.
- This phase does not introduce Flutter-only action options that are absent from the Android reference.
- This phase does not redesign chat visuals away from the Android reference visual language.
- This phase does not modify call entry, group-detail, pinned-message pages, or conversation-list behavior.

## 5. Scope Boundary

### 5.1 In Scope

- long-press message action ordering
- long-press action visibility rules by message capability
- action labels and Android-first wording
- single-message forward entry
- multi-select entry and seed behavior
- batch toolbar copy, layout, and exit rules
- forward target picker search and selection semantics
- forward confirm-button state and completion exits
- compatibility alignment for old long-press wrappers

### 5.2 Out Of Scope

- search result page parity
- search jump-and-return parity
- reply-preview rendering refinements outside action-trigger semantics
- keyboard/panel choreography and send-failure UI
- server contract changes for forward, recall, or favorite APIs

## 6. Comparative Findings

### 6.1 Flutter Now Has The Right Ownership Layer

This is the most important enabling fact for Phase 5A.

The Flutter code already owns reply, forward, selection, and action dispatch through the Phase 4 scene path at [chat_page_shell.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/modules/chat/chat_page_shell.dart). That means parity work can remain surface-focused:

- no second state machine is needed
- no new public chat entry point is needed
- no duplicate long-press menu should exist

This is exactly the right moment to compress semantics instead of expanding architecture.

### 6.2 Flutter Surface Contracts Are Still Too Generic

The current Flutter surfaces are intentionally lightweight:

- the action sheet uses a fixed list
- the selection toolbar is a simple `close + count + forward` row
- the forward page behaves like a basic list picker with a submit button

Those are acceptable Phase 4 landing forms, but they do not yet capture the Android reference’s affordance density or exit behavior.

### 6.3 Android Treats These Flows As One Continuous Action Surface

The Android reference does not treat long-press, selection, and forward as separate unrelated widgets. They are one continuous chat action system:

- a message action can switch the chat into a transient action state
- selection state changes the visible batch controls
- forward target choice resolves the action and returns to a stable chat state

Flutter should preserve the same continuity, even if the implementation details stay more modular.

## 7. Target Design

Phase 5A keeps the Phase 4 kernel and adds a thin parity-compression layer around three surfaces.

### 7.1 Action Availability Policy

Introduce one authoritative policy that derives the visible action list from message state and chat context.

Responsibilities:

- decide action order
- decide whether `reply`, `forward`, `favorite`, `select`, `recall`, and `reaction` are visible
- keep compatibility callers and scene callers on the same policy

Rules:

- no widget may hardcode its own action ordering
- compatibility wrappers must consume the same action contract as the main chat surface
- unsupported actions must disappear explicitly rather than fail after tap

### 7.2 Batch Surface Contract

The selection toolbar becomes a scene-owned batch surface instead of a simple local row.

Responsibilities:

- display selected-count feedback in Android-style wording
- expose cancel and forward behavior consistent with Android
- resolve cleanly back to normal mode after cancel or successful forward

Rules:

- selection toolbar behavior must be identical whether selection started from long-press or any future compatibility caller
- batch-mode exit must clear both scene mode and selected identities
- batch forward must use the same forward target page as single-message forward

### 7.3 Forward Surface Contract

The forward page remains a dedicated page, but it must behave like Android’s chooser rather than a generic picker.

Responsibilities:

- show searchable target list
- keep single and multi forward flows on the same page contract
- reflect selection state clearly
- gate submit until at least one target is selected
- return deterministic success and cancellation results

Rules:

- the page must remain reusable from both chat and compatibility surfaces
- search is local target filtering in this phase, not a new server-backed feature
- completion must return control to the chat scene in a stable state

## 8. Android Reference Anchors

The Phase 5A implementation is pinned to these Android references:

- [ChatActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java)
  - reply entry and reply clearing around lines 462, 1957, 1986, and 2009
  - reply attachment during send around lines 1848-1874
  - forward chooser launch around line 2086
- [ChooseContactsActivity.java](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/contacts/ChooseContactsActivity.java)
  - forward payload handling around lines 107-114 and 191-197
  - single-vs-multi choose behavior around lines 277-311
  - search filtering and confirm-button behavior around lines 139-144, 422, and 462

Flutter does not need to mimic Android class structure. It does need to mimic Android behavior.

## 9. Parity Contracts

### 9.1 Long-Press Action Sheet

Requirements:

- action ordering must be policy-driven and Android-first
- labels must stop using placeholder English copy on Android builds
- recall visibility must remain tied to self-message recall eligibility
- unsupported actions must be omitted, not merely disabled after tap
- action selection must always close the sheet before mutating the scene

### 9.2 Multi-Select Entry And Exit

Requirements:

- entering selection from a message action seeds the selected set with that message
- selected-count feedback updates immediately
- cancel returns the scene to normal and clears selection state
- successful batch forward returns the scene to normal and clears selection state
- batch mode must not leak stale state if forward is canceled or yields no targets

### 9.3 Forward Page

Requirements:

- support both single-message and multi-message payloads through one page
- keep target search responsive and local
- reflect chosen targets clearly
- disable submit when nothing is selected
- expose deterministic loading, empty, failure, and submitting states
- keep the resulting navigation flow stable when returning to chat

### 9.4 Compatibility Wrapper Behavior

Requirements:

- [message_long_press_menu.dart](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/lib/wukong_uikit/chat/message_long_press_menu.dart) must remain a thin wrapper only
- old callers must land on the same action ordering and labels as the main chat path
- compatibility code must not reintroduce a second menu model or second action enum

## 10. UI And Interaction Rules

### 10.1 Action Sheet Rules

- use Android-style concise text labels
- action order must match Android intent, not convenience order
- destructive actions such as recall must remain visually distinguishable if Android does so in the local visual language
- the sheet should feel like a chat action surface, not a generic settings list

### 10.2 Batch Toolbar Rules

- selected count must remain visible at all times in batch mode
- the close affordance must be immediate and obvious
- the forward action must stay discoverable without exposing unrelated batch features in this phase
- batch mode should visually read as a mode switch, not a tiny inline hint

### 10.3 Forward Page Rules

- top-level title, search field, list density, and confirm area should feel like a chooser page
- targets should expose enough information to distinguish same-name chats
- selection changes should be obvious even during long lists
- the submit label should communicate the current action clearly

## 11. Data And State Design

Phase 5A should avoid broad new infrastructure. The state design should stay intentionally thin.

### 11.1 Action Descriptor Model

Use a small descriptor model for rendered actions.

It should carry:

- stable action identity
- display label
- visibility decision
- ordering rank

It should not:

- own scene state
- duplicate gateway logic
- become a second controller

### 11.2 Forward Page View State

The page should explicitly represent:

- `loading`
- `ready`
- `empty`
- `submitting`
- `failure`

This can remain page-local state because the forward page is modal and self-contained.

### 11.3 Selection Resolution Rules

Batch forward resolution should follow this order:

1. read selected identities from the selection controller
2. resolve them against the viewport
3. build forward payloads
4. open the forward page
5. on success, clear selection and restore normal mode
6. on cancellation, keep selection only if Android semantics require it

For Phase 5A, the recommended rule is:

- successful forward exits batch mode
- canceled forward preserves batch mode only if that matches the Android reference after direct verification during implementation

This specific point must be verified against Android during implementation rather than assumed.

## 12. Risks And Mitigations

### 12.1 Overfitting Surface Copy Without Matching Exit Behavior

Risk:

- Flutter may look closer to Android but still exit modes differently

Mitigation:

- test the full flow, not only text labels
- include selection-cancel, selection-forward-success, and forward-cancel cases in widget tests

### 12.2 Compatibility Drift

Risk:

- old long-press entry points can slowly diverge from the scene-owned action surface

Mitigation:

- keep one action enum
- keep one action policy
- keep wrappers render-only and stateless

### 12.3 Action Availability Regressions

Risk:

- changing menu rules could accidentally remove needed actions on some messages

Mitigation:

- write policy-focused tests by message capability
- keep the policy in one small unit rather than spreading `if` logic across widgets

### 12.4 Forward Flow Ambiguity

Risk:

- batch forward success, cancel, and empty-target cases can leave the chat scene in inconsistent state

Mitigation:

- make navigation results explicit
- let the chat shell own post-forward cleanup decisions
- verify exact exit rules against Android before broadening behavior

## 13. Test Strategy

### 13.1 Unit Tests

- action policy returns the correct ordered actions for representative message cases
- selection cleanup behavior resolves correctly after forward success or cancellation
- forward page filtering logic preserves visible ordering and selected-state stability

### 13.2 Widget Tests

- long-press on a self message shows the Android-aligned action set
- long-press on a non-recallable or foreign message hides recall appropriately
- selection toolbar shows Android-aligned count text and forward affordance
- forward page disables submit when nothing is selected and enables it after selection

### 13.3 Flow Tests

- long-press `forward` opens the real forward page
- `select -> forward -> success` clears selection and returns to normal mode
- `single forward -> cancel` returns to chat stably
- compatibility wrapper opens the same action sheet semantics as the main chat path

### 13.4 Android Manual Regression

- compare long-press menus for text messages, self messages, and foreign messages
- compare multi-select entry and exit behavior
- compare forward chooser search feel and confirm flow
- compare completion and back navigation behavior on Android devices

## 14. Remote Debugging Guidance

This sub-phase is primarily local UI and scene wiring work. Remote debugging through `ssh root@103.207.68.33` is not expected to be the critical path.

Remote inspection is still allowed when:

- forward succeeds locally but target conversations do not receive the payload
- favorites or recall side effects unexpectedly interact with action availability
- scene cleanup appears correct locally but backend side effects imply otherwise

## 15. Exit Criteria For Phase 5A

This sub-phase is complete only when all of the following are true:

- long-press chat actions in Flutter follow Android-oriented ordering, labels, and visibility rules on Android
- single-message forward and multi-select forward land on the same real chooser flow
- batch selection mode exits cleanly and predictably after cancel and successful forward
- compatibility wrappers no longer maintain separate action-surface behavior
- the codebase is ready to move into Phase 5B search parity without another action-surface rewrite

Phase 5A is intentionally narrow. Its success condition is not “more features.” Its success condition is that the existing Phase 4 action path stops feeling provisional and starts behaving like the Android original.
