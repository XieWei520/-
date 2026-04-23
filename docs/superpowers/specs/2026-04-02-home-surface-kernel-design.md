# Home Surface Kernel Design

**Date:** 2026-04-02
**Scope:** Homepage surface kernelization for conversation list, main shell, and contacts skeleton
**Refactor Radius:** Aggressive kernel refactor allowed
**Public Contract Flexibility:** External contracts may be reshaped when needed to unlock performance and reliability goals
**Primary KPI:** Homepage smoothness, deterministic refresh scope, and commercial-grade recovery behavior under reconnect and high-frequency updates

## 1. Problem Statement

The current homepage implementation spreads cross-surface concerns across [main_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\main_page.dart), [conversation_list_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart), and [contacts_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart).

This creates several commercial-risk patterns:

- The main shell performs IM bootstrap, tab switching, badge aggregation, and page composition in one widget.
- Conversation and contacts surfaces do not yet share one homepage-level lifecycle contract.
- Badge updates, connection-state updates, presence updates, and list-level refresh signals can still travel farther than necessary.
- Contacts logic is concentrated in one large page that mixes presence sync, grouping, section index behavior, menu actions, refresh, and row derivation.
- The homepage does not yet have one unified recovery and observability contract for reconnects, stale snapshots, or remote debugging.

This design defines a reusable `HomeSurfaceKernel` that keeps the homepage alive, precise, and observable while limiting the blast radius of updates.

## 2. Goals

- Isolate homepage shell logic from heavy surface data derivation.
- Keep conversation and contacts surfaces mounted without letting hidden tabs consume full runtime cost.
- Ensure badge updates, connection changes, and row-level refreshes do not trigger whole-page rebuilds.
- Standardize surface lifecycle, invalidation, recovery behavior, and observability.
- Establish a reusable homepage kernel that later surfaces can plug into without cloning main-shell logic.
- Preserve a direct remote debugging workflow, including `ssh root@103.207.68.33`, as part of the execution and acceptance contract.

## 3. Non-Goals

- This phase does not redesign homepage visuals.
- This phase does not replace the entire Riverpod graph or the entire IM SDK layer.
- This phase does not yet optimize every module in the app; it focuses on the homepage surface kernel and the highest-frequency homepage flows.
- This phase does not require a complete contacts business rewrite beyond extracting a reusable skeleton and control layers.

## 4. Current Hotspots

### 4.1 Main Shell Coupling

[main_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\main_page.dart) currently owns:

- tab index state
- IM initialization flags and retry state
- tab page assembly
- unread conversation badge aggregation
- friend request badge aggregation

This makes the homepage shell sensitive to data churn that should stay within one surface.

### 4.2 Conversation Surface Progress, But No Homepage Kernel Yet

[conversation_list_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart) already contains important optimizations:

- preferred info providers
- targeted header refresh behavior
- a refresh controller
- list-item loader dedupe and providerization

However, these gains currently stop at the conversation surface boundary and are not promoted into a homepage-level contract reusable by other surfaces.

### 4.3 Contacts Surface Is Still a Large Stateful Controller

[contacts_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart) currently mixes:

- header menu composition
- friend-request badge display
- contact presence synchronization
- refresh listener registration
- contact grouping and section derivation
- sidebar alphabet state
- row rendering and navigation behavior

This is a strong signal that the page needs decomposition into cacheable and independently testable units.

## 5. Approved Architecture Direction

The approved direction for this subproject is `homepage surface kernelization`.

Phase 1 covers:

- conversation list surface
- homepage shell container
- contacts list skeleton

The implementation will introduce a reusable homepage kernel rather than applying isolated hotspot patches only to one screen.

## 6. Target Architecture

The homepage will be reorganized into three layers.

### 6.1 `HomeSurfaceKernel`

Responsibilities:

- bootstrap state management
- tab lifecycle coordination
- badge snapshot aggregation
- cross-surface invalidation routing
- prefetch scheduling
- recovery and observability hooks

Rules:

- no business-specific row rendering
- no direct large-list traversal in widget build
- no surface-specific data derivation beyond shared contracts

### 6.2 `HomeShell`

Responsibilities:

- lightweight tab shell rendering
- initialization loading and retry UI
- surface mounting
- tab tap forwarding

Rules:

- do not directly aggregate heavy surface data
- do not recreate surface pages on normal badge or connection-state changes
- consume snapshot-level providers only

### 6.3 `Surface Plugins`

Phase 1 surfaces plug into the kernel as:

- `ConversationSurface`
- `ContactsSurface`
- existing user page as a lightweight non-critical surface

Each surface exposes only its kernel contract:

- badge snapshot
- prefetch hints
- visibility hooks
- invalidation entrypoints
- recovery behavior

## 7. Module Boundaries and Data Flow

### 7.1 New Shared Contracts

The kernel introduces these shared concepts:

- `HomeSurfaceBootstrapState`
- `HomeTabCoordinator`
- `HomeBadgeSnapshot`
- `HomeSurfaceInvalidationBus`
- `HomeSurfacePrefetchHint`
- `HomeSurfaceVisibilityController`
- `SurfaceReliabilityState`

### 7.2 Surface-Specific Controllers

Conversation surface keeps its own kernelized data path and extends it with homepage contracts.

Contacts surface will be decomposed into focused layers:

- `ContactsSurfacePage`
- `ContactsDirectoryController`
- `ContactsPresenceController`
- `ContactsListViewport`
- `ContactsAlphabetIndex`

### 7.3 Data Flow Rules

Forward data flow:

`IM bootstrap -> HomeSurfaceKernel -> TabCoordinator -> Surface Controller -> List/Section Provider -> Row Widget`

Return event flow:

`SDK callback / DB change / API result -> InvalidationBus -> Targeted provider invalidation -> Surface-local refresh`

The homepage shell must not read surface internals to decide how a surface refreshes itself.

### 7.4 Explicit Anti-Goal

This design must not produce one giant homepage controller. The kernel coordinates shared mechanics only. Business-specific computation remains inside each surface controller.

## 8. Cache and Invalidation Strategy

The homepage kernel will use three cache levels.

### 8.1 `Snapshot Cache`

Purpose:

- shell-level synchronous snapshot reads
- minimal badge and status reads

Examples:

- conversation unread badge
- friend request badge
- connection-state label

Rules:

- cheap to read
- safe for tab bar and shell usage
- never requires heavy recomputation in build

### 8.2 `Surface View Cache`

Purpose:

- cache list-level view models
- keep expensive mapping out of build

Examples:

- `ConversationListItemData`
- sectioned contacts directory data
- merged presence display state

### 8.3 `Ephemeral UI Cache`

Purpose:

- short-lived interaction state

Examples:

- sidebar letter highlight
- surface scroll anchor
- transient overlay state

This cache is intentionally local and must not contaminate global business state.

### 8.4 Invalidation Types

The kernel recognizes four invalidation classes:

1. `StructuralInvalidation`
2. `DecorativeInvalidation`
3. `ViewportTriggeredInvalidation`
4. `SessionInvalidation`

Rules:

- structural changes may rebuild view caches
- decorative changes must stay row, badge, or header scoped
- viewport-triggered work only starts from visibility and viewport signals
- session invalidation may clear large scopes but must follow deterministic cache-clear order

### 8.5 Precision Requirements

The final implementation must satisfy these constraints:

- connection-state changes must not trigger full conversation-tile rebuild storms
- one contact presence change must not force full contacts regrouping
- friend-request badge changes must not rebuild the contacts list body
- one conversation title or avatar completion must not rebuild unrelated tiles
- homepage badge refresh must not recreate page instances inside the shell

## 9. Lifecycle, KeepAlive, and Prefetch Strategy

Each surface will move through four lifecycle states:

1. `cold`
2. `warm`
3. `visible`
4. `background-alive`

### 9.1 KeepAlive Policy

Phase 1 policy:

- conversation surface: keep alive
- contacts surface: keep alive
- user surface: lazy mount with lightweight keep alive

Tab switches must not recreate conversation or contacts page instances.

### 9.2 Visibility Controller Rules

When a surface becomes visible:

- resume active subscriptions needed for correctness
- enable viewport-driven refresh work
- prioritize consistency checks for the visible surface only

When a surface becomes hidden:

- pause non-essential high-frequency work
- keep caches, anchors, and base snapshots
- avoid background rebuild churn

### 9.3 Prefetch Tiers

The kernel supports three prefetch tiers:

- `criticalPrefetch`
- `adjacentPrefetch`
- `idlePrefetch`

Rules:

- critical prefetch is limited to current-tab first-frame needs
- adjacent prefetch warms lightweight neighbor-tab metadata only
- idle prefetch is cancelable, segmented, and never allowed to monopolize the UI isolate

### 9.4 Resume Strategy

On app resume:

1. refresh connection snapshot
2. refresh badge snapshot
3. revalidate only the visible surface immediately
4. defer non-visible surface repair to idle time

This prevents all homepage surfaces from stampeding at once after resume.

## 10. Reliability and Race-Control Contract

Every surface must obey the same reliability states:

- `healthy`
- `stale`
- `degraded`
- `failed`

### 10.1 Error Boundaries

The kernel uses three error layers:

- shell-level boundary for bootstrap and global availability failures
- surface-level boundary for one-tab failures
- row or fragment boundary for one-item degradation

This ensures local failures stay local whenever possible.

### 10.2 Race-Control Rules

The kernel follows `single-writer plus idempotent merge` rules:

- one surface controller owns structural writes for that surface
- same-key concurrent requests must dedupe or ignore outdated results
- stale async completions must not overwrite newer state
- the UI layer must not coordinate multiple async writers for the same state branch

Examples:

- badge updates carry ordering guarantees
- contacts presence sync keeps generation gating
- conversation item completion preserves in-flight dedupe
- surface refresh results are cancelable or safely ignorable when outdated

### 10.3 Observability Events

The homepage kernel will emit focused diagnostics rather than noisy raw logs:

- `home_bootstrap_start`
- `home_bootstrap_ready`
- `surface_visible`
- `surface_hidden`
- `badge_snapshot_refresh`
- `surface_refresh_begin`
- `surface_refresh_end`
- `surface_degraded`
- `surface_recovered`

These events support local profiling and remote environment correlation.

## 11. Remote Debugging and Server Correlation

Remote debugging is part of the operating contract for this refactor.

### 11.1 Required Login Entry

- `ssh root@103.207.68.33`

### 11.2 Expected Server-Side Checks

- `docker ps`
- `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`
- `docker logs --tail 200 fullstack-tangsengdaodaoserver-1`

### 11.3 Correlation Targets

Client and server timelines must be alignable for:

- bootstrap start and ready
- IM connection-state changes
- badge refresh completion
- visible surface activation
- resume recovery

This requirement exists so homepage regressions can be diagnosed across client, SDK, and backend layers without guesswork.

## 12. File-Level Design

### 12.1 New Files

Planned new files in phase 1:

- `lib/modules/home/home_surface_kernel.dart`
- `lib/modules/home/home_tab_coordinator.dart`
- `lib/modules/home/home_badge_snapshot.dart`
- `lib/modules/home/home_surface_invalidation_bus.dart`
- `lib/modules/home/home_surface_visibility_controller.dart`
- `lib/modules/home/home_surface_contract.dart`
- `lib/modules/contacts/contacts_directory_controller.dart`
- `lib/modules/contacts/contacts_presence_controller.dart`
- `lib/modules/contacts/widgets/contacts_list_viewport.dart`
- `lib/modules/contacts/widgets/contacts_alphabet_index.dart`

### 12.2 Existing Files to Refactor

- [main_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\main_page.dart)
- [conversation_list_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart)
- [conversation_list_refresh_controller.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_refresh_controller.dart)
- [conversation_list_item_loader.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_item_loader.dart)
- [conversation_activity_registry.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_activity_registry.dart)
- [contacts_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart)

## 13. Testing Strategy

### 13.1 Unit Tests

- badge snapshot aggregation
- tab lifecycle transitions
- invalidation routing
- contacts directory grouping
- contacts presence generation gating
- visibility state transitions

### 13.2 Widget and Component Tests

- shell badge refresh does not recreate surface pages
- contacts header badge changes do not rebuild contacts body
- connection-state changes do not trigger full conversation tile churn
- one conversation item completion only refreshes its target key

### 13.3 Integration Tests

- homepage bootstrap
- tab keep-alive behavior
- app resume recovery
- reconnect recovery
- conversation and contacts surface coexistence under rapid switching

### 13.4 Profiling Verification

The implementation must be validated with:

- Flutter DevTools rebuild tracking
- frame timeline review
- memory allocation review
- isolate task review when background mapping is introduced
- remote-environment correlation against backend logs

## 14. Acceptance Criteria

### 14.1 Architecture Acceptance

- the shell no longer aggregates heavy surface data in build
- homepage surfaces use a shared kernel contract
- contacts logic is decomposed into focused controllers and widgets
- shell dependencies are contract-based rather than surface-internal

### 14.2 Performance Acceptance

- homepage first interaction is not blocked by badge or contacts regrouping work
- tab switching preserves page instances for conversation and contacts
- row-level and badge-level changes stay locally scoped
- scrolling surfaces avoid expensive synchronous rebuild-side work

### 14.3 Stability Acceptance

- bootstrap failures can recover through retry
- reconnect does not reorder stale and fresh homepage state
- rapid tab switching does not let stale requests overwrite visible state
- resume does not trigger all surfaces to recompute at once
- local degradation remains local instead of collapsing the whole homepage

### 14.4 Remote Debug Acceptance

The implementation is not considered complete unless the team can:

1. log in with `ssh root@103.207.68.33`
2. inspect the running containers
3. inspect WuKongIM and TangSeng logs
4. correlate homepage kernel events with backend timing

## 15. Directly Executable Task Checklist

This checklist is intentionally execution-oriented and includes the required remote-debug entry.

1. Extract `HomeShell` from [main_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\main_page.dart) and move bootstrap plus badge snapshot reads behind dedicated providers.
2. Introduce the homepage shared contracts and the `HomeSurfaceKernel`.
3. Wire conversation surface into the shared kernel without regressing the existing targeted refresh work.
4. Split [contacts_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart) into directory, presence, viewport, and alphabet-index layers.
5. Add snapshot cache, surface view cache, and surface invalidation routing.
6. Add visibility-aware keep-alive and prefetch behavior.
7. Add reliability-state handling and stale-result suppression.
8. Add focused homepage observability events.
9. Run local verification for analysis, tests, and rebuild scope.
10. Log into the cloud server with `ssh root@103.207.68.33` for remote debugging and environment correlation.
11. Run `docker ps` to confirm the expected containers are healthy.
12. Inspect `/data/fullstack/wukongimdata/logs/error.log` and the TangSeng container logs for timing correlation and backend anomalies.
13. Validate that homepage events and backend logs align during bootstrap, reconnect, badge refresh, and tab recovery flows.

## 16. Risks and Mitigations

### Risk: kernel abstraction grows into a new god object

Mitigation:

- keep shared contracts narrow
- leave business mapping inside surfaces
- reject convenience APIs that expose surface internals to the shell

### Risk: keep-alive pages quietly continue expensive background work

Mitigation:

- require explicit visibility transitions
- pause non-essential listeners and refresh tasks on hidden surfaces
- verify hidden-tab rebuild behavior during profiling

### Risk: contact decomposition causes behavior regressions

Mitigation:

- preserve existing contacts visual output during phase 1
- move one responsibility at a time behind tests
- keep navigation behavior and menu semantics stable unless the implementation phase explicitly approves a change

### Risk: remote diagnosis remains ambiguous

Mitigation:

- standardize homepage observability events
- make the remote debugging command path part of the acceptance criteria
- correlate client timings with backend logs during verification
