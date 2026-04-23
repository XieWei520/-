# WuKongIM Flutter Complete Feature Alignment Design

**Date:** 2026-04-03
**Scope:** Rebuild the Flutter client so that its Android runtime strictly matches the TangSengDaoDao Android reference in feature coverage and interaction behavior while surpassing it in architecture quality, performance, reliability, and maintainability
**Refactor Radius:** Aggressive architectural realignment is allowed; duplicate or obsolete Flutter paths may be retired once replacement paths are stable
**Public Contract Flexibility:** Internal Flutter contracts may be redesigned when needed to achieve strict parity and a stronger long-term architecture
**Primary KPI:** Android-reference parity at the product surface, next-generation Flutter runtime quality under real-world IM load
**Git Status Note:** This workspace is not currently backed by a Git repository, so this spec can be written locally but cannot be committed yet

## 1. Problem Statement

The current Flutter app at `C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app` is no longer a blank port. It already contains substantial chat, conversation, contacts, group, scan, push, and call foundations. However, the project is not organized around the same module boundaries, assembly model, or interaction depth as the TangSengDaoDao Android reference at `C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoAndroid-master`.

The result is a dangerous middle state:

- real production-capable building blocks exist
- many Android-reference behaviors are still missing or only partially connected
- multiple duplicate Flutter implementations coexist
- some stronger implementations are hidden outside the active app flow
- endpoint-style extensibility, which is central to the Android reference, is barely active in Flutter

This means the project cannot reach true parity by adding isolated pages. It requires a deliberate rebuild of the Flutter app's main architecture so that Android-reference features can be attached to one clear, modern, high-performance client core.

## 2. Product Mandate

The user-approved mandate is:

- externally, the Flutter app running on Android must strictly align with the TangSengDaoDao Android client in features and interaction behavior
- internally, the Flutter app must use more advanced architecture and engineering practices so that it clearly exceeds the reference app in performance, stability, observability, and maintainability
- when required for joint debugging, integration validation, or backend-assisted issue isolation, direct remote access to the deployed environment through `ssh root@103.207.68.33` is an approved and expected execution path

This is a dual-goal program, not a pure UI port and not a greenfield redesign detached from the Android reference.

## 3. Goals

- Achieve strict Android-reference parity for all core Android-user-facing IM flows.
- Rebuild the Flutter app around stable module boundaries closer to the Android reference.
- Replace the current multi-track Flutter structure with one authoritative production path.
- Promote endpoint-driven extensibility from a dormant utility into a first-class assembly system.
- Rebuild chat, group, login, scan, push, and call flows on top of modern Flutter state, routing, storage, and event orchestration patterns.
- Deliver better runtime behavior than the Android reference in large-list smoothness, weak-network recovery, failure handling, and operational visibility.
- Produce an execution-ready architecture that can be implemented through phased sub-project plans rather than one giant ad hoc rewrite.

## 4. Non-Goals

- This program does not treat Flutter-only extension features as parity blockers if the Android reference does not contain them.
- This program does not require immediate iOS, web, desktop, or multi-platform parity. The approved target is Android behavior parity first.
- This program does not preserve every existing Flutter file or module. Redundant or obsolete code may be retired after migration.
- This program does not prioritize visual experimentation over product fidelity. Visual polish is welcome, but strict Android-reference behavior is the baseline.
- This program does not attempt to redesign backend contracts as a first move. It assumes the current deployed backend remains the serving contract unless a later subproject proves a server-side gap.

## 5. Confirmed Project Context

The analysis behind this design covered both codebases and the deployed backend environment.

### 5.1 Flutter Codebase Snapshot

- `398` Dart files
- `144` test files
- roughly `70` TODO hits inside `lib`
- at least `14` duplicate hotspot implementations across config, API, WebSocket, login, settings, and chat-input surfaces

Important active Flutter paths include:

- `lib/main.dart`
- `lib/modules/home/home_shell_page.dart`
- `lib/modules/conversation/conversation_list_page.dart`
- `lib/modules/contacts/contacts_page.dart`
- `lib/modules/user/user_page.dart`
- `lib/modules/chat/chat_page_shell.dart`
- `lib/wukong_uikit/group/group_detail_page.dart`
- `lib/service/im/im_service.dart`

### 5.2 Android Reference Snapshot

- `571` Java/Kotlin files
- `11` test files
- deeply used `wkbase`, `wkuikit`, `wklogin`, `wkpush`, and `wkscan` modules
- endpoint-driven assembly is heavily embedded in homepage, contacts, group detail, chat, and settings behaviors

### 5.3 Backend Runtime Context

The deployed backend on `103.207.68.33` was confirmed reachable, and the relevant IM-related services and infrastructure ports were running during analysis. This design therefore treats backend reachability as sufficient for client migration planning.

## 6. Core Findings From the Comparative Audit

### 6.1 The Flutter App Is More Mature Than Old Analysis Documents Claimed

The current active app already has real:

- authentication flow
- conversation list flow
- contacts flow
- user/profile flow
- IM initialization and runtime coordination
- group-management surfaces
- scan routing
- 1v1 call groundwork

Old gap documents in the workspace understate the current implementation quality and should not be treated as the source of truth for migration planning.

### 6.2 The Primary Gap Is Structural, Not Merely Visual

The most serious problem is not that the Flutter app has no code. The most serious problem is that it does not yet have one Android-aligned assembly model.

The current Flutter tree contains parallel structures such as:

- `lib/core/**` and `lib/wukong_base/**`
- `lib/modules/**` and `lib/wukong_uikit/**`
- `lib/modules/auth/**` and `lib/wukong_login/**`
- `lib/endpoint/**` and `lib/wukong_base/endpoint/**`

This causes:

- hidden implementation drift
- uncertain ownership
- multiple candidate implementations for the same feature
- stronger components not being connected to the active path
- higher regression risk during any direct feature port

### 6.3 Endpoint Extensibility Is the Largest Architecture Parity Gap

Flutter already has an endpoint manager implementation, but effective usage is minimal. Android, by contrast, uses endpoint-driven assembly broadly across multiple core surfaces.

This means the Flutter project currently lacks the same client-side extension spine that the Android reference relies on to compose menus, sections, tabs, actions, and settings modules.

### 6.4 Chat Is the Highest-Value Functional Gap

The Flutter app contains many chat primitives, including message rendering support, forward-related utilities, and a rich long-press action definition. But the active chat path still lacks the full Android-reference interaction surface:

- fully wired long-press actions
- strong search and favorites flow
- complete reply, edit, recall, multi-select, and forward orchestration
- stronger group-chat special behaviors
- richer call and extra-action integration

This is not a lack of raw code. It is a lack of mainline assembly.

## 7. Approved Strategy Direction

The user approved strategy `3`:

`Re-center the Flutter client around Android-reference module boundaries and rebuild the main UIKit, extension, and feature assembly model. Reuse existing Flutter assets where they are strong, but migrate them into a new authoritative architecture rather than continuing to grow the current dual-track structure.`

This strategy is intentionally more ambitious than a quick gap-fill approach because the current codebase has already crossed the threshold where superficial patching would increase long-term cost.

## 8. Parity Scope and Acceptance Model

Strict parity is defined through four acceptance layers.

### 8.1 Functional Parity

If the Android reference client can complete a core user flow on Android, the Flutter Android client must also complete it.

In scope:

- login and registration flows
- area code and verification flows
- conversation list
- contacts
- group management
- chat and message operations
- scan and QR routing
- PC and Web login confirmation
- device management
- push
- call entry and core call flow
- settings-related parity surfaces

### 8.2 Interaction Parity

The Flutter Android client must not merely expose equivalent endpoints. It must align with the Android reference in:

- entry positions
- action sequences
- menu layering
- long-press behavior
- group-detail composition
- status feedback
- tab behavior
- scan-result routing

### 8.3 Architecture Parity

The Flutter client must no longer rely on fragmented parallel structures. It must be reorganized into stable modules that correspond more closely to the reference system's durable responsibilities:

- foundation/base
- IM core
- endpoint assembly
- UI kit
- login
- scan
- push
- call
- app shell

### 8.4 Maintainability Parity

The final state is not acceptable if parity exists only through hidden legacy branches.

The migration is only complete when:

- the main production flow is unique and authoritative
- deprecated implementations are retired or isolated from production routing
- feature coverage is traceable
- critical flows are testable and observable

## 9. Current Parity Matrix

This matrix uses four statuses:

- `Aligned`
- `Partially aligned`
- `Code exists but is not wired into the main flow`
- `Clearly missing`

### 9.1 App Shell and Home Tabs

Status: `Partially aligned`

The Flutter app already has a real main shell and real conversation, contacts, and user surfaces. However, the homepage still behaves more like a static container than the endpoint-driven, behavior-rich tab surface used by the Android reference.

### 9.2 Authentication and Account Entry

Status: `Partially aligned`, with several flows in `Code exists but is not wired into the main flow`

Flutter includes active login and registration flows plus bridge APIs for device/web login. However, Android has a much richer login surface including area-code selection, verification-code entry, password reset, PC login, Web login confirmation, profile completion, and third-party login as a cohesive module. Flutter has parts of this, but not one unified product path.

### 9.3 Conversation List

Status: `Partially aligned`

Flutter already supports meaningful conversation operations such as pin, mute, delete, multi-select, and search entry. The remaining gap is not basic list existence; it is Android-style assembly, richer behavioral hooks, and stronger system-state integration.

### 9.4 Contacts

Status: `Partially aligned`

Flutter contacts already support new-friend, saved-group, scan, create-group, alphabetical navigation, and basic actions. The main remaining gap is the Android reference's dynamic, endpoint-backed composition model for headers, menus, and organization-related injectables.

### 9.5 Chat Surface and Message Operations

Status: `Clearly missing` at the product-complete level, even though significant `Code exists but is not wired into the main flow`

The Flutter app has a real chat shell and strong message-rendering primitives. It also contains a rich message long-press action definition. But the active flow still lacks Android-reference completeness in search, favorites, forwarding, recall, editing, multi-select orchestration, richer group-specific behaviors, and complete action wiring.

### 9.6 Group Management

Status: `Partially aligned`

Flutter group detail and related pages are more mature than many earlier notes suggested. The largest remaining gap is that the Android reference composes group-detail sections through extensible modules, while Flutter still centers the flow in a large, more static detail surface.

### 9.7 Scan and QR Routing

Status: `Partially aligned`

Flutter scan support is real and useful, including internal QR parsing, URL/text handling, Web login confirmation, and user/group routing. The remaining gap is Android-level polish, camera-flow behavior, and full integration consistency.

### 9.8 PC and Web Login Management

Status: `Partially aligned`, with some `Code exists but is not wired into the main flow`

Flutter has bridge APIs and management screens, but the device-login experience is still fragmented. Android offers a more cohesive and clearly integrated module.

### 9.9 Push

Status: `Clearly missing`

The Android reference supports multiple Android push vendors. The current Flutter path is still centered on FCM-like handling and does not yet cover the same domestic Android device ecosystem needed for production-grade parity.

### 9.10 Audio and Video Call

Status: `Partially aligned`

Flutter has real 1v1 WebRTC groundwork and call coordination foundations. The main missing parity items are richer group-call selection, deeper chat integration, and more complete Android-runtime flow handling.

### 9.11 Search

Status: `Clearly missing`

Flutter already has a global search entry, but Android-reference-grade chat search, group search, scoped filters, and complete result-navigation depth are still incomplete.

### 9.12 Endpoint and Plugin Assembly

Status: `Clearly missing`

This is the single most important architecture gap. Flutter's endpoint infrastructure exists as a primitive, but it does not yet control the main composition of the app the way the Android reference does.

### 9.13 Extra Flutter-Only Modules

The Flutter `moments` implementation may remain as a product extension, but it is not part of the strict Android-reference parity acceptance criteria because the Android reference does not provide an equivalent built-in module.

## 10. Target Architecture Blueprint

The target state is a modular Flutter monorepo-oriented app architecture that aligns with Android-reference responsibilities while using more advanced Flutter implementation patterns.

### 10.1 Top-Level Module Layout

The durable module layout should converge toward:

- `app_shell`
- `wk_foundation`
- `wk_im_core`
- `wk_endpoint`
- `wk_uikit`
- `wk_login`
- `wk_scan`
- `wk_push`
- `wk_call`
- `feature_*` modules where appropriate after the foundation is stable

This does not require immediate extraction into dozens of packages on day one. It does require one stable direction of ownership and one authoritative production path.

### 10.2 Layering Model

Each major module should separate responsibilities into:

- `presentation`
- `application`
- `domain`
- `data`

The intent is not framework theater. The intent is to keep chat, contacts, groups, and login flows independently understandable, testable, and replaceable.

### 10.3 State Management

`Riverpod` becomes the primary state and dependency orchestration mechanism.

Rules:

- use `Notifier` or `AsyncNotifier` for main business state
- keep `setState` only for small local ephemeral widget concerns
- gradually remove `get_it` from core business coordination
- express cross-feature dependencies through providers rather than hidden singleton reach-through

### 10.4 Routing

The current direct `Navigator`-heavy approach should evolve into a stronger routed shell system, ideally based on `go_router` with shell-based app layers:

- auth shell
- main-tab shell
- chat shell
- scan and bridge shell
- call shell

This is required to handle push opens, scan results, login-state transitions, device-login confirmations, and incoming-call flows with less fragmentation.

### 10.5 Data and Event Core

The existing IM SDK remains the low-level IM capability source, but the Flutter app should wrap it through a more explicit event and projection pipeline:

- SDK callbacks
- normalized event frames
- reducers or state transitions
- repository projections
- UI-facing view models

This allows incremental updates instead of broad UI refresh behavior and creates a predictable system for send-state, retry, edit, recall, and sync behaviors.

### 10.6 Local Storage Strategy

The storage model should converge toward:

- SDK-managed message and conversation storage remains the low-level IM fact source
- application-owned structured data moves toward a single stronger local data model
- `shared_preferences` stays limited to small preferences
- `hive` is gradually reduced
- `Drift + SQLite` is the preferred long-term target for application-owned structured data

This creates a clearer line between SDK facts and app-owned derived or operational data.

### 10.7 Strongly Typed Endpoint Assembly

The Flutter endpoint system should be redesigned as a typed slot-based assembly model rather than remaining a loosely used string-invocation utility.

Core slot families should include:

- `HomeTabSlot`
- `ConversationMenuSlot`
- `ContactsHeaderSlot`
- `ChatToolbarSlot`
- `MessageLongPressSlot`
- `GroupDetailSectionSlot`
- `ProfileActionSlot`
- `SettingsSectionSlot`

Each slot should support:

- priority
- conditional display
- context filtering
- safe registration and deregistration
- deterministic default and override behavior

This is the central mechanism that allows the Flutter app to both match the Android reference and become easier to extend than the reference.

### 10.8 Coordinator Pattern for Cross-Cutting Flows

The app should formalize coordinator-style orchestration for:

- push
- scan
- device login
- calls
- possibly media pick and attachment flows later

These flows cross feature boundaries and should not remain embedded ad hoc inside individual pages.

## 11. Technical Decisions Required to Exceed the Android Reference

Strict parity alone is not the final bar. The Flutter implementation must also become a stronger client.

### 11.1 Performance Objectives

The Flutter client should outperform the current state and aim to outperform the Android reference in:

- conversation-list smoothness under high unread churn
- chat-list scrolling under large history volumes
- historical pagination without viewport jumps
- media-message rendering stability
- group member list responsiveness
- minimized full-surface rebuilds

### 11.2 Reliability Objectives

The Flutter client should have stronger failure and recovery handling than the reference in:

- weak-network reconnect
- offline send-state transitions
- scan and bridge failures
- push-token re-registration
- device-session invalidation
- pending-call recovery

### 11.3 Observability Objectives

The target implementation should include:

- structured logs
- critical flow tracing
- network request observability
- IM connection state metrics
- push registration metrics
- call establishment and failure metrics
- clearer runtime diagnostics for production support

### 11.4 User Experience Objectives

The Flutter client should surpass the reference through:

- better loading and empty states
- clearer sending and failure feedback
- improved retry affordances
- more stable list motion
- more coherent action-sheet behavior
- more consistent interaction feedback across modules

## 12. Migration Program

This program is too large for one monolithic implementation plan. It must be executed as a mother design with multiple sub-specs and sub-plans.

### 12.1 Phase 0: Baseline Freeze and Asset Ledger

Purpose:

- lock the source-of-truth parity matrix
- map Android pages to Flutter status
- classify every duplicate hotspot as keep, migrate, or retire
- identify hidden but reusable Flutter assets

Outputs:

- parity ledger
- file-to-file mapping ledger
- duplicate hotspot retirement ledger
- validated production-flow map

Acceptance:

- every Android core surface is mapped
- every Flutter duplicate hotspot has a disposition
- all active and hidden entry paths are documented

### 12.2 Phase 1: New Mainline Architecture

Purpose:

- establish the new authoritative shell and module skeleton
- create the dependency, routing, error, and logging backbone
- bridge old implementations into the new shell only where needed

Outputs:

- new app shell
- foundation package or module skeleton
- unified dependency graph
- unified routing shell
- unified network and error model

Acceptance:

- the app starts under the new shell
- login-state transitions, push opens, scan opens, and chat-entry routing flow through one mainline
- no new feature work is added to obsolete branches

### 12.3 Phase 2: Endpoint and UIKit Rebuild

Purpose:

- rebuild app composition around typed slot-driven assembly
- convert key surfaces from hardcoded composition to module assembly

Outputs:

- typed endpoint or slot contracts
- reusable section and action registries
- new UIKit ownership model

Acceptance:

- homepage, contacts, chat-toolbar, group-detail, and settings extension points are live
- existing dormant capabilities can be attached through the new assembly model

### 12.4 Phase 3: Authentication and Device Login Alignment

Purpose:

- turn account entry into a complete Android-reference-grade subsystem

Outputs:

- unified login, registration, verification, area-code, reset-password, third-party-login, Web-confirmation, and device-management flows

Acceptance:

- all Android-reference account-entry flows are covered on Android
- login completion, IM bootstrap, push registration, and device identity bind into one coherent transaction

### 12.5 Phase 4: Home, Conversation, and Contacts Alignment

Purpose:

- align the three most frequently used outer surfaces with Android behavior

Outputs:

- rebuilt main tab shell
- aligned conversation behaviors
- aligned contacts structure and actions

Acceptance:

- critical tab flows behave like the Android reference
- home surfaces are driven by the new assembly model
- large datasets remain responsive

### 12.6 Phase 5: Chat Core Alignment

Purpose:

- rebuild the most important IM surface to true product completeness

Outputs:

- new chat shell
- incremental message projection pipeline
- fully wired long-press and action flow
- reply, edit, recall, forward, multi-select, favorites, search, and group-specific interaction support

Acceptance:

- Android-reference chat flows close end-to-end
- action-state changes are reflected correctly in the UI
- send, retry, edit, recall, and pagination behavior are stable under test

### 12.7 Phase 6: Group, Search, Scan, Call, and Push Completion

Purpose:

- complete the high-complexity surrounding systems that make the IM product production-ready

Outputs:

- modular group-detail parity
- scoped search parity
- finalized scan routing
- richer call system
- multi-vendor Android push support

Acceptance:

- group detail is module-assembled rather than a monolith
- search depth matches Android expectations
- domestic Android push coverage reaches parity
- call flows support the required group and recovery behaviors

### 12.8 Phase 7: Performance, Stability, and Experience Superiority

Purpose:

- ensure the Flutter client does not merely match the reference but beats it in runtime quality

Outputs:

- performance instrumentation
- stability hardening
- error-recovery improvements
- loading, failure, and retry polish
- observability dashboards or structured logs suitable for support

Acceptance:

- critical performance targets are defined and met
- weak-network and recovery flows are measured
- regressions are caught by automated checks

### 12.9 Phase 8: Legacy Retirement and Final Convergence

Purpose:

- remove the structural debt that would otherwise silently reintroduce fragmentation

Outputs:

- retired obsolete modules
- cleaned duplicate infrastructure
- final architecture and feature documentation

Acceptance:

- the production path is unique
- duplicate core implementations are removed or permanently isolated
- architecture ownership is explicit

## 13. Execution Model

This design should not transition directly into one giant implementation plan.

The correct execution model is:

1. write this mother design
2. decompose it into subproject specs
3. write one implementation plan per approved subproject
4. implement each plan against the new mainline architecture

Remote execution and debugging rule:

- when a client issue depends on deployed backend behavior, runtime state, service logs, container state, push registration state, media routing, or production-like integration evidence, the implementation workflow is expected to use `ssh root@103.207.68.33`
- remote login is not treated as an exceptional fallback; it is part of the normal joint-debugging toolchain for this project
- subplans should explicitly call out the points where server inspection or server-assisted verification is required

Expected first-wave sub-specs include:

- architecture and module realignment
- endpoint and UIKit assembly rebuild
- authentication and device login completion
- home and contacts alignment
- chat core alignment
- group, search, scan, push, and call completion

## 14. Risks and Mitigations

### 14.1 Risk: Feature Porting Without Mainline Convergence

If the team ports features directly into the current fragmented tree, the app will accumulate even more duplicate and hidden behavior.

Mitigation:

- freeze new feature additions on obsolete branches
- land all new work only on the new mainline architecture

### 14.2 Risk: Mistaking Existing Hidden Code for Completed Product Flow

Several Flutter capabilities already exist, but not all are actually production-wired.

Mitigation:

- acceptance must require mainline accessibility and end-to-end interaction tests

### 14.3 Risk: Over-Abstracting the Endpoint System

A theoretical plugin system detached from actual Android-reference use cases would slow delivery.

Mitigation:

- define slots only around proven reference extension points
- validate each slot family against an actual page or behavior

### 14.4 Risk: Platform Work Being Underestimated

Push and call parity require Android-platform-side attention, not just Dart work.

Mitigation:

- treat Android plugin and native integration tasks as first-class workstreams in the relevant subplans

## 15. Validation and Testing Strategy

The end state must be proven, not inferred.

### 15.1 Test Layers

- unit tests for reducers, repositories, coordinators, and state machines
- widget tests for key pages and interaction components
- golden tests for critical visual surfaces where interaction parity matters
- integration tests for login, chat, scan, device login, push-open routing, and call invitation flows

### 15.2 Acceptance Evidence

Each subproject should produce:

- parity checklist evidence
- before and after architecture ownership map
- test results
- performance notes for high-frequency surfaces

### 15.3 Operational Verification

The deployed backend and remote debugging path remain part of the delivery contract. Runtime verification must continue to support backend-assisted validation against the currently deployed environment.

Operational rule:

- if local code inspection cannot fully explain a defect, parity gap, synchronization issue, push failure, scan-login failure, or call-flow problem, the workflow should proceed to direct server-side verification through `ssh root@103.207.68.33`
- acceptance for backend-coupled features should include both client-side evidence and server-assisted verification evidence where relevant

## 16. Final Design Decision

The approved design direction is:

`Build a new authoritative Flutter Android client mainline that mirrors the TangSengDaoDao Android client at the product surface, but is internally rebuilt on stronger modular boundaries, typed extension assembly, modern state orchestration, stronger routing, clearer storage ownership, and production-grade performance and observability.`

This is the only design direction that satisfies both user-approved goals:

- strict Android-reference parity on Android
- a Flutter implementation that significantly surpasses the reference in engineering quality and runtime experience

## 17. Immediate Next Step

The next step after user review of this spec is not direct implementation. The next step is to invoke `superpowers:writing-plans` and create detailed implementation plans for the first approved subproject, starting with architecture and module realignment.
