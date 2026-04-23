# WuKongIM Flutter Search Parity Rebuild Design

**Date:** 2026-04-03
**Scope:** Rebuild the Flutter search subsystem so that Android runtime behavior matches the TangSengDaoDao Android reference for in-chat search, scoped chat search, and global search while exceeding the reference in architecture quality, stability, and performance
**Reference Priority:** Android reference behavior on Android is the product contract; Flutter architecture is allowed to improve internally as long as that contract is preserved
**Git Status Note:** This workspace is not currently a Git repository, so this spec can be written locally but cannot be committed yet

## 1. Problem Statement

The current Flutter search implementation is not a single subsystem. It is a fragmented mix of:

- partially rebuilt API logic
- incomplete page stubs
- UI code that owns its own data loading and navigation
- hidden duplication between `lib/modules/search/**` and `lib/wukong_uikit/search/**`

This is not merely an implementation gap. It is a product-parity and architecture-boundary problem.

The Android reference provides a coherent chat-search system with:

- in-chat search entry and live keyword search
- scoped search pages for date, image, and member
- global search aggregation
- message-to-chat navigation using message anchoring

The Flutter app currently does not deliver the same subsystem shape. Some pieces exist, but the mainline behavior is incomplete or structurally wrong. The clearest example is the date search page, which currently behaves as a date-range picker flow instead of the Android reference's calendar-like month and day browser.

The search subsystem therefore requires a deliberate rebuild, not incremental patching.

## 2. Product Mandate

This search rebuild inherits the user-approved program mandate:

- Android runtime behavior must strictly align with the TangSengDaoDao Android reference
- internal Flutter architecture should be stronger than the reference in modularity, testability, and runtime smoothness
- implementation may use server-assisted and SSH-assisted joint debugging where backend evidence is needed

For search specifically, the approved migration direction is:

- rebuild the Flutter search mainline to match the Android search subsystem
- do not continue patching the current incomplete search pages
- preserve Android search semantics first, then improve architecture and runtime behavior underneath

## 3. Search Scope

This spec covers the Flutter Android search subsystem surfaces corresponding to the Android reference:

- `MessageRecordActivity`
- `SearchMessageAdapter`
- `SearchWithDateActivity`
- `SearchWithImgActivity`
- `SearchWithMemberActivity`
- global search entry and result navigation surfaces

In Flutter terms, the scope includes:

- chat-level search entry
- keyword search result list inside a conversation
- date-scoped chat search
- image-scoped chat search
- file-scoped and link-scoped search where the backend contract already supports them
- member-scoped chat search
- global search aggregation result handling
- search result navigation into a chat anchor

## 4. Non-Goals

- This spec does not redesign the backend search contract unless a verified blocker is found.
- This spec does not redefine product semantics differently from Android in the name of Flutter-native experimentation.
- This spec does not attempt to solve every app-wide extension-system concern. It only defines the minimum search-specific dependencies on the broader architecture program.
- This spec does not require iOS or multi-platform parity as part of its acceptance bar. Android parity is the current target.

## 5. Current State Audit

### 5.1 Flutter Surfaces

Relevant current Flutter files include:

- `lib/service/api/search_api.dart`
- `lib/modules/search/search_with_date_page.dart`
- `lib/modules/search/search_with_img_page.dart`
- `lib/modules/search/search_exports.dart`
- `lib/wukong_uikit/search/global_search_page.dart`

### 5.2 Confirmed Current-State Findings

- The search API layer has already been realigned to the real parity backend endpoint, `/v1/search/global`.
- The current Flutter search pages are not Android-parity pages and should not be treated as near-finished equivalents.
- `search_with_date_page.dart` is fundamentally incorrect because it implements a date-range picker flow instead of Android's local date calendar search.
- `search_with_img_page.dart` contains usable intent but should still be rebuilt into the new architecture instead of being preserved as-is.
- `global_search_page.dart` mixes view rendering, model shaping, default data loading, and navigation concerns in one file.
- A missing `message_item_widget.dart` is not the real problem. The real problem is that search UI composition has not been given clear feature boundaries.

### 5.3 SDK Constraint

The Flutter SDK provides message search and message location helpers such as:

- `search(...)`
- `searchWithChannel(...)`
- `searchMsgWithChannelAndContentTypes(...)`
- `getMessageOrderSeq(...)`

However, the Flutter SDK does not currently expose an Android-equivalent `getMessageGroupByDateWithChannel(...)`.

This is the decisive architecture fact for date search:

- keyword search and content-type search can rely on remote search
- date search must introduce a Flutter-side local date aggregation layer

## 6. Approved Design Direction

The approved search design direction is:

- build the search subsystem as a dedicated feature with explicit domain, data, application, and presentation boundaries
- use remote `/v1/search/global` for keyword, media, file, link, member, and global aggregated search flows
- use a local date aggregation layer for the Android-style date-search page
- normalize all result clicks through one chat-location protocol so every search surface navigates into chat consistently

This preserves Android product semantics while creating a cleaner and more maintainable Flutter system.

## 7. Product Parity Requirements

### 7.1 Chat Search Entry

The in-chat search entry must behave like Android:

- entering the page focuses the search field
- when the keyword is empty, the page shows search-type entries rather than result items
- when the keyword becomes non-empty, the search-type entries are hidden and a message result list is shown
- selecting a search-type entry opens the corresponding scoped search page

### 7.2 Keyword Search Result Page

The keyword result page must:

- search within the current conversation
- show message items, not just conversation summaries
- paginate as the user loads more
- navigate to the matching message anchor inside chat when an item is tapped

### 7.3 Date Search Page

The date page must align with Android:

- it is not a date-range picker
- it opens into a month-by-month calendar-style layout
- each day cell can show message count
- the page scrolls toward the newest month and selects today by default
- tapping a day with messages opens the corresponding chat anchor

### 7.4 Image Search Page

The image page must:

- load image messages for the current conversation
- display them in an Android-like grouped grid
- group by year-month sections
- support load-more pagination
- support preview, forward, and show-in-chat actions

### 7.5 Member Search Page

The member page must preserve Android semantics:

- present members as the search scope selector for a conversation
- allow entry into a member-filtered message result list
- keep navigation consistent with the main search result page

### 7.6 Global Search Result Handling

Global search may remain a separate entry surface, but its message-result navigation must converge with the same internal location system used by chat-scoped search.

## 8. Target Search Domain Model

The search subsystem should stop passing loosely shaped maps between pages. It should expose shared search-domain entities.

### 8.1 Core Domain Entities

- `SearchMenuEntry`
- `SearchMessageHit`
- `SearchMediaItem`
- `SearchMemberHit`
- `SearchDateMonthSection`
- `SearchDateCell`
- `ChatLocateIntent`

### 8.2 Model Responsibilities

`SearchMenuEntry` represents one in-chat scoped search action such as date, image, file, link, or member.

`SearchMessageHit` is the normalized representation of a matched message and must minimally include:

- `channelId`
- `channelType`
- `messageSeq`
- `contentType`
- `timestamp`
- `fromUid`
- `fromName`
- `previewText`

`SearchMediaItem` extends message-hit semantics for media and document results and should include:

- `mediaUrl`
- `fileName`
- `linkUrl`
- `sectionKey`

`SearchDateMonthSection` and `SearchDateCell` exist specifically for the Android-style date search surface and must carry:

- month identity
- day identity
- placeholder-day markers for calendar alignment
- message count
- `anchorOrderSeq`
- today-selection metadata

`ChatLocateIntent` is the cross-surface navigation contract and must include:

- `channelId`
- `channelType`
- `messageSeq`
- `orderSeq`
- `highlightKeyword`
- `source`

## 9. Data Sources and Repository Structure

Search data must be split into three capabilities rather than leaving each page to assemble its own queries.

### 9.1 `SearchRemoteDataSource`

Responsibilities:

- call `/v1/search/global`
- support `only_message=1` keyword search within a conversation
- support content-type-scoped search for image, file, and link surfaces
- support member-filtered search using `from_uid`
- support global aggregate search

This data source is the authoritative remote path for all non-date search flows.

### 9.2 `SearchLocalTimelineDataSource`

Responsibilities:

- inspect locally available message history
- build date-grouped search material for a single conversation
- produce month sections and day cells
- resolve per-day anchor order sequences

This data source exists because Flutter does not currently have the Android helper used by the reference implementation.

### 9.3 `SearchLocateResolver`

Responsibilities:

- convert message hits and day-cell anchors into stable chat navigation targets
- use `WKIM.shared.messageManager.getMessageOrderSeq(...)` when necessary
- encapsulate fallback behavior if order-sequence resolution fails

### 9.4 Repository Layer

The feature should expose one search repository interface that composes the three data sources above. The repository is responsible for:

- translating remote or local raw data into domain models
- enforcing consistent sort order and section shaping
- keeping location resolution logic out of pages

## 10. Module Layout and File Boundaries

The search feature should be rebuilt under one authoritative module:

- `lib/modules/search/domain/`
- `lib/modules/search/data/`
- `lib/modules/search/application/`
- `lib/modules/search/presentation/`

### 10.1 `domain/`

Contains:

- search entities
- query objects
- navigation intent objects
- search-specific error and state enums where needed

### 10.2 `data/`

Contains:

- remote data source
- local timeline data source
- DTO mapping
- repository implementation

### 10.3 `application/`

Contains feature coordinators and controllers such as:

- `ChatKeywordSearchController`
- `ChatDateCalendarController`
- `ChatMediaSearchController`
- `ChatMemberSearchController`
- `GlobalSearchController`
- `ChatLocateCoordinator`

### 10.4 `presentation/`

Contains pages and pure UI widgets such as:

- `chat_search_entry_page.dart`
- `chat_search_results_page.dart`
- `chat_search_date_page.dart`
- `chat_search_media_page.dart`
- `chat_search_member_page.dart`
- `global_search_page.dart`
- `widgets/search_message_tile.dart`
- `widgets/search_media_grid.dart`
- `widgets/search_date_calendar.dart`

### 10.5 Existing File Disposition

- `search_with_date_page.dart`: replace
- `search_with_img_page.dart`: rebuild using only limited logic as reference
- `global_search_page.dart`: split and migrate
- `search_exports.dart`: convert into a clean public export surface after the rebuild

## 11. State Management and Navigation Rules

### 11.1 State Management

Riverpod should be the main orchestration mechanism for this feature.

Rules:

- pages should render state, not own request orchestration
- search inputs, pagination, debounce, cancellation, retry, and empty states belong in controllers
- keyword-search families should be parameterized by conversation identity and search scope
- date search should use a dedicated calendar state model rather than trying to share a generic keyword-search state

### 11.2 Navigation

Pages should not directly push `ChatPage` as a naive fallback for every result tap.

Instead:

- all search surfaces resolve a `ChatLocateIntent`
- `ChatLocateCoordinator` owns message-anchor navigation
- if anchor resolution fails, the system may degrade to opening the target conversation, but that is a fallback path rather than the default behavior

This keeps search navigation consistent across:

- chat keyword search
- date search
- image search
- member search
- global search message hits

## 12. Interaction Design Rules

### 12.1 Chat Search Entry Page

- focus search immediately on entry
- show search-type entries when keyword is empty
- switch to message results when keyword is non-empty
- keep Android-style interaction sequencing rather than inventing a new flow

### 12.2 Date Search Page

- render month headers and calendar day grids
- auto-scroll toward the newest month
- visually select today by default
- preserve day placeholders for weekday alignment
- only navigable days should trigger chat location

### 12.3 Media Search Page

- render sectioned month groups
- use grid layout
- support load more
- open preview from thumbnail taps
- expose forward, show-in-chat, and favorite-equivalent actions

### 12.4 Member Search Page

- display selectable members for the current conversation
- transition into filtered message results after selection
- share result-item rendering and navigation behavior with the main message result page where possible

### 12.5 Global Search Page

- preserve contacts, groups, and message-group sections at the product surface
- route any message-based result through the same location system as the chat-scoped search feature

## 13. Loading, Pagination, and Error Strategy

### 13.1 Keyword Search

- use immediate search-on-input behavior with light debounce
- cancel or invalidate stale requests
- replace results on page 1
- append results on later pages
- allow only one load-more request in flight at a time

### 13.2 Media and Member Result Pages

Use one consistent paged-state model:

- `items`
- `page`
- `hasMore`
- `initialLoading`
- `loadingMore`
- `error`

### 13.3 Date Search

- no remote pagination
- compute the date model asynchronously
- avoid blocking first-frame rendering when the local store is large

### 13.4 Error Handling

Remote search failure rules:

- if there is no previous data, show page-level error state with retry
- if there is already visible data, preserve it and show incremental-load failure feedback

Navigation failure rules:

- log anchor-resolution failure
- degrade to opening the conversation if needed
- do not fail silently

Media failure rules:

- show stable broken-image placeholders
- do not let one bad media item collapse the grid

All meaningful failures should emit structured logs suitable for later joint debugging.

## 14. Search-Specific Dependencies on the Broader Architecture Program

This search project is not the same as the full app-wide Phase 2 endpoint and UIKit rebuild.

However, it does depend on a minimal shared-architecture slice:

- a stable search entry mounting point inside chat
- a unified chat-location coordinator
- reusable surface-level presentation primitives for search result lists and grouped sections

Therefore, implementation planning should treat search as:

- a dedicated business subproject
- with a small required infrastructure slice drawn from the larger architecture program

Search should not wait for the entire global Phase 2 program to finish before work begins. It should consume only the minimum prerequisites needed for a clean implementation.

## 15. Testing and Acceptance Strategy

### 15.1 Unit Tests

- remote DTO to domain-model mapping
- date aggregation and month-grid generation
- `messageSeq` to `orderSeq` to `ChatLocateIntent` resolution
- pagination state transitions
- request cancellation and error recovery behavior

### 15.2 Widget Tests

- empty keyword shows scoped search-type entries
- non-empty keyword shows message results
- date page renders month sections and calendar cells
- media page renders sectioned grids

### 15.3 Integration Tests

- enter chat search and load keyword results
- tap a result and land near the correct message anchor
- tap a date cell and open the corresponding history location
- browse image search results, preview an image, and show it in chat
- select a member and load member-filtered results

### 15.4 Acceptance Evidence

Search parity is only accepted when the Flutter Android runtime is validated against the Android reference for:

- entry placement
- screen switching behavior
- list or grid shape
- pagination behavior
- navigation path
- empty and error states

Acceptance must explicitly compare Flutter behavior against:

- `MessageRecordActivity`
- `SearchWithDateActivity`
- `SearchWithImgActivity`
- `SearchWithMemberActivity`

## 16. Risks and Mitigations

### 16.1 Risk: Patching the Wrong Pages

If implementation continues to patch the current Flutter search pages, the product may appear to move forward while the architecture gets worse.

Mitigation:

- replace or rebuild the current main search pages rather than layering more fixes into them

### 16.2 Risk: Date Search Is Forced Through Remote Search

If date search is forced into the remote-search path, the product will drift away from Android semantics and become slower or less reliable than necessary.

Mitigation:

- implement a local date aggregation layer as a first-class data capability

### 16.3 Risk: Navigation Divergence Across Search Surfaces

If each page owns its own chat-opening logic, message navigation will remain inconsistent and hard to debug.

Mitigation:

- centralize all result navigation through `ChatLocateIntent` and `ChatLocateCoordinator`

### 16.4 Risk: Search Depends on the Entire Global Architecture Program

If search is blocked until the whole endpoint and UIKit rebuild is complete, one of the most visible product gaps will remain open too long.

Mitigation:

- define and implement only the minimum infrastructure slice that search actually needs

## 17. Final Design Decision

The approved design for the search subsystem is:

`Rebuild Flutter search as a dedicated feature with shared domain models, split remote/local data capabilities, Riverpod-based application controllers, and one unified chat-location protocol, while preserving Android-reference search behavior on Android for keyword, date, image, member, and global-search flows.`

This is the only design direction that satisfies both approved goals:

- strict Android product parity
- stronger-than-reference Flutter architecture and runtime quality

## 18. Immediate Next Step

After user review of this written spec, the next step is to invoke `superpowers:writing-plans` and produce an implementation plan for the search rebuild.

That plan should explicitly separate:

- search-specific infrastructure prerequisites
- chat-search entry and keyword-results rebuild
- date search rebuild
- media and member search rebuild
- global search convergence and final verification
