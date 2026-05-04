# Phase 6 Search Convergence Design

**Date:** 2026-04-05
**Scope:** Converge the remaining Flutter search subsystem work so Android runtime behavior matches the TangSengDaoDao Android reference for chat-scoped search, date search, media and member search integration, and global search result navigation
**Reference Priority:** Android behavior on Android is the product contract; Flutter may improve architecture, performance, and observability internally as long as visible behavior stays Android-faithful
**Git Status Note:** This workspace still does not contain `.git` metadata, so this spec can be written locally but cannot be committed from this copy

## 1. Problem Statement

The Flutter app already has a real search kernel under `lib/modules/search/**`, and the recent image-search and member-search parity work closed part of the old gap. The remaining problem is no longer "search is missing." The remaining problem is that search is still not one converged Android-faithful subsystem.

At the start of Phase 6:

- chat search entry, scoped search pages, and global search still do not share one authoritative navigation and message-location protocol
- date search is still the largest product-semantic gap versus Android
- completed image and member search work exists, but is not yet fully described as part of one final search architecture
- global search still risks drifting away from chat-scoped search because result shaping and result navigation are not yet fully unified

This means the next search phase should not be another patch series. It should be a mother spec that defines one final search subsystem and then executes it through smaller child plans.

## 2. Product Mandate

This Phase 6 search work inherits the approved program mandate:

- Flutter on Android must strictly align with the TangSengDaoDao Android reference in feature behavior and interaction meaning
- Flutter architecture is expected to exceed the Android original in modularity, reliability, performance, and debuggability
- direct remote verification through `ssh root@103.207.68.33` is an approved part of the workflow whenever deployed behavior diverges from local evidence

For search specifically, the mandate is:

- preserve the current `lib/modules/search/**` mainline as the only authoritative search path
- do not introduce a third parallel search implementation
- finish the remaining Android search parity gaps and converge every search result tap into one stable chat-location pipeline

## 3. Scope Boundary

This mother spec defines the final Phase 6 search target and the child-plan split required to implement it safely.

In scope:

- chat search entry behavior inside a conversation
- keyword search results inside a conversation
- date search rebuild with Android-style month and day browsing
- convergence of image, file, link, and member scoped search into the unified search architecture
- global search aggregation and unified message-result navigation
- one shared message-location protocol for all search surfaces
- search-focused regression, compile, and deployed-runtime verification

Explicitly out of scope:

- group-detail parity outside what search result navigation touches
- scan, push, call, and non-search Phase 6 domains
- backend contract rewrites unless verified deployed behavior proves a real server-side blocker
- reopening Phase 5 chat action or engagement architecture beyond the search entry points it already exposes

## 4. Current State At The Start Of Phase 6

### 4.1 Existing Flutter Search Assets

Relevant current Flutter assets include:

- `lib/modules/chat/chat_search_mode_controller.dart`
- `lib/modules/chat/widgets/chat_search_mode_bar.dart`
- `lib/modules/search/application/chat_keyword_search_controller.dart`
- `lib/modules/search/application/chat_media_search_controller.dart`
- `lib/modules/search/application/chat_member_search_controller.dart`
- `lib/modules/search/application/global_search_controller.dart`
- `lib/modules/search/data/search_api_gateway.dart`
- `lib/modules/search/data/search_local_timeline_data_source.dart`
- `lib/modules/search/data/search_remote_data_source.dart`
- `lib/modules/search/data/search_repository_impl.dart`
- `lib/modules/search/presentation/chat_search_entry_page.dart`
- `lib/modules/search/presentation/chat_search_results_page.dart`
- `lib/modules/search/presentation/chat_search_date_page.dart`
- `lib/modules/search/presentation/chat_search_collection_page.dart`
- `lib/modules/search/presentation/chat_search_member_page.dart`
- `lib/modules/search/presentation/global_search_page.dart`
- `lib/modules/search/search_with_date_page.dart`
- `lib/modules/search/search_with_img_page.dart`
- `lib/modules/search/search_with_member_page.dart`

### 4.2 Existing Search Baseline That Must Be Preserved

Recent image-search and member-search parity work already established a meaningful baseline:

- image search section grouping, pagination, and local-media preference were tightened toward Android expectations
- member search now has a stable wrapper path and incremental-load behavior closer to Android
- search pages already use a dedicated `lib/modules/search/**` kernel and should remain there

This work is not to be redone. It is Phase 6 input, not Phase 6 debt.

### 4.3 Remaining Gaps

The largest remaining gaps are:

- date search still needs a real Android-style calendar flow
- search result navigation is not yet fully normalized through one locate protocol
- chat-scoped search entry and keyword result behavior still need final convergence checks
- global search needs stricter result shaping and message-result navigation convergence
- already completed scoped pages need to be absorbed into one final architecture and one final regression story

## 5. Android Reference Anchors

The Phase 6 target is pinned to the Android reference surfaces below:

- `MessageRecordActivity`
  - chat search entry, empty-keyword menu behavior, keyword-result switching
- `SearchWithDateActivity`
  - month-based calendar layout, day selection, anchored message location
- `SearchWithImgActivity`
  - year-month grouping, preview, forward, favorite or show-in-chat semantics, pagination
- `SearchWithMemberActivity`
  - member selection, member-filtered message results, anchored show-in-chat behavior
- Android global search message-result behavior
  - message hits must navigate through a stable message-location path rather than open a conversation naively

Flutter is allowed to exceed Android internally, but the visible entry positions, switching order, result types, and navigation meaning must remain Android-faithful.

## 6. Final Design Decision

The final Phase 6 search design is:

`Keep one authoritative Flutter search kernel in lib/modules/search, drive non-date search through the repaired remote search path, drive date search through a dedicated local timeline aggregation path, and converge every search result click through one shared chat-location protocol so the entire search subsystem behaves like Android while remaining architecturally stronger than the reference.`

## 7. Core Architecture

### 7.1 One Main Search Kernel

All search work continues inside `lib/modules/search/**`. No new parallel UIKit search path is introduced.

This keeps ownership explicit:

- chat owns search entry mounting and search-mode transitions
- search owns search data, search state, search pages, and search result rendering
- chat-location infrastructure is shared, but the search feature is the caller

### 7.2 Two Data Channels

Search uses two data channels, each with one clear responsibility:

- remote search channel
  - keyword search in a conversation
  - image, file, and link scoped search
  - member-filtered search
  - global search aggregation
- local timeline channel
  - date search month sections
  - date cells
  - per-day message count
  - per-day anchor identity

The local channel exists because Android-style date search is a product behavior, not an optional fallback, and the Flutter SDK still does not provide the same Android helper used by the reference implementation.

### 7.3 Unified Chat Location Protocol

Every message-bearing search surface must converge through one locate pipeline:

1. page or controller produces a normalized search-domain hit
2. `SearchLocateResolver` turns that hit into a `ChatLocateIntent`
3. `ChatLocateCoordinator` opens the chat and attempts anchored navigation
4. if full anchor location fails, the system may degrade to opening the conversation, but only as an explicit fallback

No search page should continue to own its own ad hoc chat-opening logic.

## 8. Module And File Responsibilities

The final search subsystem should remain split into four layers.

### 8.1 `domain/`

Contains shared search entities and intent models:

- `SearchMenuEntry`
- `SearchMessageHit`
- `SearchMediaItem`
- `SearchMemberHit`
- `SearchDateMonthSection`
- `SearchDateCell`
- `GlobalSearchSnapshot`
- `ChatLocateIntent`

### 8.2 `data/`

Contains:

- `SearchRemoteDataSource`
- `SearchLocalTimelineDataSource`
- `SearchLocateResolver`
- `SearchRepositoryImpl`

The repository is responsible for returning stable domain models, not raw backend maps.

### 8.3 `application/`

Contains Riverpod controllers and coordinators:

- `ChatKeywordSearchController`
- `ChatDateCalendarController`
- `ChatMediaSearchController`
- `ChatMemberSearchController`
- `GlobalSearchController`
- `ChatLocateCoordinator`

Controllers own querying, pagination, cancellation, retries, and state transitions. Pages render state and forward user intent.

### 8.4 `presentation/`

Contains search pages and pure widgets:

- chat search entry page
- keyword results page
- date page
- collection pages for image, file, and link
- member page
- global search page
- result tiles, grouped sections, and calendar widgets

## 9. Domain Model Rules

The search subsystem should stop passing loosely shaped maps or page-local transport objects across feature boundaries.

Minimum model responsibilities:

- `SearchMessageHit`
  - normalized message match payload for keyword, member, and global message results
- `SearchMediaItem`
  - scoped collection result with `sectionKey` and media metadata
- `SearchMemberHit`
  - one selectable member scope inside the current conversation
- `SearchDateMonthSection`
  - month header plus ordered day cells for Android-style date browsing
- `SearchDateCell`
  - day alignment, count, and anchor metadata
- `GlobalSearchSnapshot`
  - structured aggregate result sections for global search
- `ChatLocateIntent`
  - channel identity, message identity, optional order sequence, optional highlight keyword, and source marker

## 10. Product-Surface Parity Rules

### 10.1 Chat Search Entry

The chat search entry must behave like Android:

- entering search immediately gives a usable search field
- empty keyword shows Android-style scoped search menu entries
- non-empty keyword hides the menu and shows current-conversation message hits
- selecting a scoped search menu opens the matching scoped page

### 10.2 Keyword Results

Keyword search results must:

- represent message hits, not conversation summaries
- paginate correctly
- navigate to a message anchor, not merely open the conversation root

### 10.3 Date Search

Date search must be rebuilt to Android semantics:

- not a date-range picker
- month and day grid layout
- recent months visible by default
- today can be expressed in the UI state
- only dates with hits are actionable
- tapping a hit-bearing day opens the anchored chat history position

### 10.4 Image, File, And Link Search

Collection search must preserve Android meaning:

- image search grouped by year-month
- grid or collection behavior that matches Android expectations
- paginated load-more behavior
- preview and show-in-chat semantics
- file and link search reuse the collection infrastructure without diverging from locate behavior

### 10.5 Member Search

Member search must remain a two-step Android-style flow:

- select member
- inspect that member's message results in the current conversation
- click any result and use the same locate pipeline as keyword results

### 10.6 Global Search

Global search may remain a separate page, but:

- section shaping must stay deterministic
- message hits must use the same locate protocol as chat-scoped search
- empty and error behavior must remain consistent with the rest of the search subsystem

## 11. State, Pagination, And Error Rules

### 11.1 State Ownership

All request orchestration belongs in controllers, not pages.

Controllers should own:

- first-load state
- load-more state
- stale-request invalidation
- retry
- empty-state transitions
- page counters
- final domain-model ordering

### 11.2 Incremental Failure Policy

For all paged search surfaces:

- if page 1 fails and there is no visible data, show a page-level error with retry
- if later pages fail and visible data already exists, keep the visible data and show incremental failure feedback plus retry

This applies to:

- keyword results
- image, file, and link collection pages
- member-filtered results
- global-search message result lists where pagination exists

### 11.3 Date Search Loading Policy

Date search uses local aggregation rather than remote pagination:

- compute asynchronously
- preserve a stable first frame
- avoid blocking the UI while large local stores are scanned

### 11.4 Navigation Failure Policy

If location resolution cannot produce a full anchored jump:

- log the failure in structured form
- degrade to opening the target conversation if appropriate
- never fail silently

## 12. Child Plan Split

This mother spec is intentionally large, but implementation should be split into smaller child plans.

### 12.1 Child Plan A: Date Search And Shared Locate Foundation

Build:

- `ChatLocateIntent`
- `SearchLocateResolver`
- `ChatLocateCoordinator`
- Android-style date search month and day flow

Why first:

- date search is the largest remaining Android semantic gap
- the locate protocol is foundational for every other search surface

### 12.2 Child Plan B: Chat-Scoped Search Mainline Convergence

Build:

- final chat search entry behavior
- keyword result convergence
- final unification of image, file, link, and member scoped surfaces around the shared locate path

Why second:

- it delivers the most visible Android-faithful search behavior inside chat
- it reuses the locate foundation from Child Plan A

### 12.3 Child Plan C: Global Search Convergence And Final Regression

Build:

- global search result shaping cleanup
- unified message-result location from global search
- final search regression coverage
- Android comparison passes and remote verification hooks

Why third:

- it touches the broadest search surface
- it is safest after the chat-scoped locate path is already stable

## 13. Testing Strategy

### 13.1 Unit Tests

Cover:

- DTO to domain-model mapping
- date aggregation and month-grid generation
- `messageSeq` and `orderSeq` resolution into `ChatLocateIntent`
- controller state transitions for pagination, retry, and cancellation

### 13.2 Widget Tests

Cover:

- chat search entry empty-keyword and non-empty-keyword switching
- date calendar month and day rendering
- collection-page incremental failure behavior
- member search member-selection and result behavior
- global search section rendering and message-result tap handling

### 13.3 Integration Or Compile Regression

Cover:

- search entry to chat locate path
- date-cell tap to anchored history location
- global message result to locate path
- search compile and regression suites alongside existing chat coverage

### 13.4 Remote Verification

Remote verification is part of the normal workflow when local and deployed behavior diverge. Use `ssh root@103.207.68.33` when:

- local tests pass but real search results are empty
- member filtering returns the wrong sender
- date or keyword result taps do not land on the correct conversation or history area
- global-search behavior differs from the deployed backend contract

Minimum remote checks should inspect:

- search API output
- relevant application logs
- message-index or sequence data when locate behavior appears inconsistent

## 14. Acceptance Criteria

Phase 6 search convergence is accepted only when all three categories below are true.

### 14.1 Functional Acceptance

- chat search entry closes end-to-end
- keyword search closes end-to-end
- date search closes end-to-end
- image, file, link, and member search close end-to-end
- global search message navigation closes end-to-end

### 14.2 Interaction Acceptance

On Android, Flutter matches the Android reference in:

- entry positions
- search-mode switching order
- result surface type
- section and grouping behavior
- pagination semantics
- click result meaning and final landing point

### 14.3 Engineering Acceptance

- all search message results use the shared locate protocol
- no search page owns a separate direct-chat navigation path
- image and member search parity work remains preserved and absorbed into the unified architecture
- search regression coverage exists for the mainline behaviors above

## 15. Risks And Mitigations

### 15.1 Risk: Reopening Completed Scoped Search Work

Risk:

- image and member search could be destabilized if Phase 6 treats them as greenfield work

Mitigation:

- treat them as completed baseline assets
- only touch them where locate-path convergence, entry integration, or final regression requires it

### 15.2 Risk: Date Search Gets Forced Back Into Remote Semantics

Risk:

- date search drifts away from Android again if implemented as a remote query wrapper

Mitigation:

- keep date search explicitly local-timeline-backed

### 15.3 Risk: Global Search Diverges From Chat Search

Risk:

- global message results remain a special case with custom navigation

Mitigation:

- force global message hits through the same locate protocol and acceptance bar

## 16. Immediate Next Step

After user review of this written spec, the next step is to invoke `superpowers:writing-plans` and create the first child implementation plan:

- `Child Plan A: Date Search And Shared Locate Foundation`

That plan should be the next execution entry point for Phase 6.
