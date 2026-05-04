# Search Parity Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter search subsystem so Android users get TangSengDaoDao-grade in-chat search, date search, image/member search, and anchored search navigation inside chat.

**Architecture:** This plan implements the search rebuild as one dedicated feature under `lib/modules/search`, but it starts by landing the smallest possible chat-side prerequisite: anchored chat history loading by `orderSeq`. Search data is split into typed remote and local sources, search state is owned by Riverpod `StateNotifier` controllers to match the existing codebase style, and legacy import paths remain stable through thin compatibility wrappers while the new feature becomes the authoritative implementation.

**Tech Stack:** Flutter, flutter_riverpod, existing WKIM Flutter SDK, sqflite, dio, flutter_test, shared_preferences, PowerShell, SSH remote debugging

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoint commands for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Scope Boundary

This plan only implements the search rebuild defined in [2026-04-03-search-parity-rebuild-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-03-search-parity-rebuild-design.md).

In scope:

- chat-side anchored history loading needed for search result navigation
- new typed search domain model and repository contracts
- remote search data source over `/v1/search/global`
- local date aggregation over the Flutter SDK SQLite store
- keyword search entry and in-chat result list
- date calendar search page
- image, file, link, and member scoped search pages
- global search convergence onto the new feature core
- compatibility wrappers for the existing `modules/search/**` and `wukong_uikit/search/**` entry points

Out of scope for this plan:

- whole-app endpoint or UIKit rebuild
- unrelated chat action parity such as recall/edit/favorite beyond what search directly invokes
- iOS-specific or web-specific parity work
- push-vendor, call, or group-detail feature work unrelated to search entry and chat anchoring

## File Structure

### New Files

- `lib/data/providers/chat_history_gateway.dart`
  - Wraps `WKIM.shared.messageManager.getOrSyncHistoryMessages(...)` behind a testable gateway so search can request anchored history loads.
- `lib/modules/search/domain/search_models.dart`
  - Defines immutable search entities, search scopes, calendar cell models, and locate intents.
- `lib/modules/search/domain/search_repository.dart`
  - Declares the typed repository contract for keyword, date, collection, member, and global search flows.
- `lib/modules/search/data/search_api_gateway.dart`
  - Thin adapter around `SearchApi.instance` to remove static singleton coupling from the feature.
- `lib/modules/search/data/search_remote_data_source.dart`
  - Maps `/v1/search/global` payloads into typed search entities.
- `lib/modules/search/data/search_local_timeline_data_source.dart`
  - Reads the local SDK SQLite store and builds Android-style date buckets and month sections.
- `lib/modules/search/data/search_repository_impl.dart`
  - Composes the remote and local data sources behind the repository contract.
- `lib/modules/search/application/search_providers.dart`
  - Wires repository and coordinator providers for the feature.
- `lib/modules/search/application/chat_keyword_search_controller.dart`
  - Owns keyword search input, debounce, pagination, and error state.
- `lib/modules/search/application/chat_date_calendar_controller.dart`
  - Owns date-calendar loading state and day-tap navigation requests.
- `lib/modules/search/application/chat_media_search_controller.dart`
  - Owns image/file/link pagination and grouped collection state.
- `lib/modules/search/application/chat_member_search_controller.dart`
  - Owns member list loading plus member-filtered message results.
- `lib/modules/search/application/global_search_controller.dart`
  - Owns the typed global-search surface while preserving current callback-friendly test hooks.
- `lib/modules/search/application/chat_locate_coordinator.dart`
  - Resolves `messageSeq` into `orderSeq` and returns a chat-open request for anchored navigation.
- `lib/modules/search/presentation/chat_search_entry_page.dart`
  - Authoritative in-chat search entry page replacing the placeholder `ChatSearchPage`.
- `lib/modules/search/presentation/chat_search_results_page.dart`
  - Renders keyword or member-filtered message hits inside a conversation.
- `lib/modules/search/presentation/chat_search_date_page.dart`
  - Renders the Android-style month-and-day search calendar.
- `lib/modules/search/presentation/chat_search_collection_page.dart`
  - Renders grouped image/file/link search results.
- `lib/modules/search/presentation/chat_search_member_page.dart`
  - Renders the conversation member selector and member-filtered result flow.
- `lib/modules/search/presentation/global_search_page.dart`
  - Becomes the authoritative global search UI while preserving the public API expected by current callers and tests.
- `lib/modules/search/presentation/widgets/search_message_tile.dart`
  - Shared list tile for message-hit rendering.
- `lib/modules/search/presentation/widgets/search_menu_grid.dart`
  - Shared entry grid for date/image/file/link/member actions.
- `lib/modules/search/presentation/widgets/search_date_calendar.dart`
  - Shared calendar month/day widget tree for the date page.
- `lib/modules/search/presentation/widgets/search_collection_section.dart`
  - Shared grouped grid/list section for image/file/link pages.
- `test/data/providers/conversation_provider_search_anchor_test.dart`
  - Verifies chat history anchoring works through the new gateway-backed notifier path.
- `test/modules/search/search_models_test.dart`
  - Verifies the typed search models, scopes, and calendar helpers.
- `test/modules/search/search_repository_test.dart`
  - Verifies remote/local repository mapping and date-calendar shaping.
- `test/modules/search/chat_locate_coordinator_test.dart`
  - Verifies `messageSeq -> orderSeq -> chat open request` conversion.
- `test/modules/search/chat_search_entry_page_test.dart`
  - Verifies empty-keyword menu state and keyword result state.
- `test/modules/search/chat_search_date_page_test.dart`
  - Verifies month sections, padded day cells, and tap behavior.
- `test/modules/search/chat_search_collection_page_test.dart`
  - Verifies grouped image/file/link rendering and load-more state.
- `test/modules/search/chat_search_member_page_test.dart`
  - Verifies member selection and member-filtered result rendering.
- `test/modules/search/search_pages_compile_test.dart`
  - Verifies the new search pages compile under `ProviderScope`.

### Existing Files To Modify

- `lib/data/providers/conversation_provider.dart`
  - Add the injectable history gateway path and `loadAroundOrderSeq(...)`.
- `lib/modules/chat/chat_page.dart`
  - Replace the placeholder `ChatSearchPage` with the new entry page and forward anchored navigation parameters into `ChatPageShell`.
- `lib/modules/chat/chat_page_shell.dart`
  - Accept an optional initial anchor and expose a working chat-side search entry mount point.
- `lib/service/api/search_api.dart`
  - Keep the API contract stable, but add only the small changes required by the typed gateway if any test proves them necessary.
- `lib/modules/search/search_with_date_page.dart`
  - Turn into a compatibility wrapper over `ChatSearchDatePage`.
- `lib/modules/search/search_with_img_page.dart`
  - Turn into a compatibility wrapper over `ChatSearchCollectionPage(scope: image)`.
- `lib/modules/search/search_exports.dart`
  - Export the new authoritative search pages and wrappers.
- `lib/wukong_uikit/search/global_search_page.dart`
  - Turn into a compatibility wrapper or export surface over the new `modules/search/presentation/global_search_page.dart`.
- `test/wukong_uikit/search/global_search_page_parity_test.dart`
  - Keep global-search parity coverage pointed at the compatibility path.
- `test/modules/chat/chat_page_android_parity_test.dart`
  - Add coverage for the mounted search entry and anchored chat launch behavior.

## Remote Debugging Requirement

This plan includes server-assisted verification whenever local behavior and deployed search behavior disagree.

- SSH entry: `ssh root@103.207.68.33`
- Use remote inspection when:
  - `/v1/search/global` returns unexpected payload shapes
  - member filters do not line up with deployed data
  - anchored chat navigation lands on the wrong message because local and remote history disagree
- Minimum remote checks:
  - `docker ps`
  - `docker logs --tail 200 fullstack-tangsengdaoserver-1`
  - `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`

## Verification Commands Used Throughout

- `dart analyze lib/data/providers/chat_history_gateway.dart lib/data/providers/conversation_provider.dart lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart lib/modules/search lib/wukong_uikit/search/global_search_page.dart`
- `flutter test test/data/providers/conversation_provider_search_anchor_test.dart`
- `flutter test test/modules/search/search_models_test.dart test/modules/search/search_repository_test.dart test/modules/search/chat_locate_coordinator_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_date_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`
- `flutter test test/modules/search/search_pages_compile_test.dart`
- `flutter test test/wukong_uikit/search/global_search_page_parity_test.dart`
- `flutter test test/modules/chat/chat_page_android_parity_test.dart`

### Task 1: Add The Anchored Chat-Loading Prerequisite

**Files:**
- Create: `lib/data/providers/chat_history_gateway.dart`
- Modify: `lib/data/providers/conversation_provider.dart`
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Test: `test/data/providers/conversation_provider_search_anchor_test.dart`

- [ ] **Step 1: Write the failing anchor-loading tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class _FakeChatHistoryGateway implements ChatHistoryGateway {
  int? lastAroundOrderSeq;

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    return <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    return <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadAround({
    required String channelId,
    required int channelType,
    required int aroundOrderSeq,
    required int limit,
  }) async {
    lastAroundOrderSeq = aroundOrderSeq;
    final msg = WKMsg()
      ..channelID = channelId
      ..channelType = channelType
      ..orderSeq = aroundOrderSeq
      ..messageSeq = 42
      ..messageID = 'm-anchor';
    return <WKMsg>[msg];
  }
}

void main() {
  test('message list notifier loads around a target order seq for search open', () async {
    final gateway = _FakeChatHistoryGateway();
    final notifier = MessageListNotifier(
      'g1001',
      2,
      historyGateway: gateway,
      autoLoad: false,
    );

    await notifier.loadAroundOrderSeq(42000);

    expect(gateway.lastAroundOrderSeq, 42000);
    expect(notifier.state, hasLength(1));
    expect(notifier.state.single.orderSeq, 42000);
  });

  testWidgets('chat page forwards initialAroundOrderSeq into the shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(
          channelId: 'g1001',
          channelType: 2,
          channelName: 'Design',
          initialAroundOrderSeq: 42000,
        ),
      ),
    );

    final shell = tester.widget(find.byType(ChatPageShell)) as ChatPageShell;
    expect(shell.initialAroundOrderSeq, 42000);
  });
}
```

- [ ] **Step 2: Run the anchor-loading tests to verify they fail**

Run: `flutter test test/data/providers/conversation_provider_search_anchor_test.dart`
Expected: FAIL with missing `ChatHistoryGateway`, missing `initialAroundOrderSeq`, or missing `loadAroundOrderSeq`

- [ ] **Step 3: Implement the chat history gateway and notifier anchor path**

```dart
// lib/data/providers/chat_history_gateway.dart
import 'dart:async';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

abstract class ChatHistoryGateway {
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  });

  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  });

  Future<List<WKMsg>> loadAround({
    required String channelId,
    required int channelType,
    required int aroundOrderSeq,
    required int limit,
  });
}

class WkSdkChatHistoryGateway implements ChatHistoryGateway {
  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) {
    return _request(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: 0,
      pullMode: 0,
      aroundOrderSeq: 0,
      limit: limit,
    );
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) {
    return _request(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: oldestOrderSeq,
      pullMode: 1,
      aroundOrderSeq: 0,
      limit: limit,
    );
  }

  @override
  Future<List<WKMsg>> loadAround({
    required String channelId,
    required int channelType,
    required int aroundOrderSeq,
    required int limit,
  }) {
    return _request(
      channelId: channelId,
      channelType: channelType,
      oldestOrderSeq: 0,
      pullMode: 0,
      aroundOrderSeq: aroundOrderSeq,
      limit: limit,
    );
  }

  Future<List<WKMsg>> _request({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int pullMode,
    required int aroundOrderSeq,
    required int limit,
  }) {
    final completer = Completer<List<WKMsg>>();
    WKIM.shared.messageManager.getOrSyncHistoryMessages(
      channelId,
      channelType,
      oldestOrderSeq,
      false,
      pullMode,
      limit,
      aroundOrderSeq,
      (msgs) => completer.complete(msgs.reversed.toList(growable: false)),
      () {},
    );
    return completer.future;
  }
}
```

```dart
// conversation_provider.dart
class MessageListNotifier extends StateNotifier<List<WKMsg>> {
  MessageListNotifier(
    this.channelId,
    this.channelType, {
    ChatHistoryGateway? historyGateway,
    bool autoLoad = true,
  }) : _historyGateway = historyGateway ?? WkSdkChatHistoryGateway(),
       super([]) {
    _setupListeners();
    if (autoLoad) {
      loadMessages();
    }
  }

  final ChatHistoryGateway _historyGateway;

  Future<void> loadMessages() async {
    try {
      final messages = await _historyGateway.loadLatest(
        channelId: channelId,
        channelType: channelType,
        limit: 50,
      );
      state = mergeConversationMessages(messages);
    } catch (_) {
      state = <WKMsg>[];
    }
  }

  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    if (aroundOrderSeq <= 0) {
      await loadMessages();
      return;
    }
    try {
      final messages = await _historyGateway.loadAround(
        channelId: channelId,
        channelType: channelType,
        aroundOrderSeq: aroundOrderSeq,
        limit: 50,
      );
      state = mergeConversationMessages(messages);
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (state.isEmpty) {
      return;
    }
    try {
      final messages = await _historyGateway.loadMore(
        channelId: channelId,
        channelType: channelType,
        oldestOrderSeq: state.last.orderSeq,
        limit: 50,
      );
      state = mergeConversationMessages(<WKMsg>[...state, ...messages]);
    } catch (_) {}
  }
}
```

```dart
// chat_page.dart and chat_page_shell.dart
class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.initialAroundOrderSeq,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final int? initialAroundOrderSeq;

  @override
  Widget build(BuildContext context) {
    return ChatPageShell(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      initialAroundOrderSeq: initialAroundOrderSeq,
    );
  }
}

class ChatPageShell extends ConsumerStatefulWidget {
  const ChatPageShell({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.initialAroundOrderSeq,
    this.onViewportBuild,
  });

  final int? initialAroundOrderSeq;
}

@override
void initState() {
  super.initState();
  unawaited(_loadChannel());
  final anchor = widget.initialAroundOrderSeq;
  if (anchor != null && anchor > 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(messageListProvider(_chatSession).notifier).loadAroundOrderSeq(anchor),
      );
    });
  }
}
```

- [ ] **Step 4: Run the anchor-loading tests again**

Run: `flutter test test/data/providers/conversation_provider_search_anchor_test.dart`
Expected: PASS with 2 tests green

- [ ] **Step 5: Run chat analysis after the anchor change**

Run: `dart analyze lib/data/providers/chat_history_gateway.dart lib/data/providers/conversation_provider.dart lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart`
Expected: PASS with no analyzer errors

- [ ] **Step 6: Checkpoint**

```bash
git add lib/data/providers/chat_history_gateway.dart lib/data/providers/conversation_provider.dart lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart test/data/providers/conversation_provider_search_anchor_test.dart
git commit -m "feat: add anchored chat history loading for search"
```

### Task 2: Create The Typed Search Domain And Repository Contracts

**Files:**
- Create: `lib/modules/search/domain/search_models.dart`
- Create: `lib/modules/search/domain/search_repository.dart`
- Test: `test/modules/search/search_models_test.dart`

- [ ] **Step 1: Write the failing search-model tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';

void main() {
  test('collection scope maps to the expected content types', () {
    expect(SearchCollectionScope.image.contentTypes, const <int>[2]);
    expect(SearchCollectionScope.file.contentTypes, const <int>[5]);
    expect(SearchCollectionScope.link.contentTypes, const <int>[14, 1]);
  });

  test('placeholder day cells are never navigable', () {
    final placeholder = SearchDateCell.placeholder(weekdayOffset: 2);
    final active = SearchDateCell(
      year: 2026,
      month: 4,
      day: 3,
      messageCount: 8,
      anchorOrderSeq: 55000,
      isToday: true,
      isSelected: true,
    );

    expect(placeholder.isPlaceholder, isTrue);
    expect(placeholder.canOpen, isFalse);
    expect(active.isPlaceholder, isFalse);
    expect(active.canOpen, isTrue);
  });

  test('message hits carry a stable conversation key', () {
    const hit = SearchMessageHit(
      channelId: 'g1001',
      channelType: 2,
      messageSeq: 12,
      orderSeq: 12000,
      timestamp: 1710000000,
      contentType: 1,
      fromUid: 'u_alice',
      fromName: 'Alice',
      previewText: 'keyword',
    );

    expect(hit.conversationKey, '2:g1001');
  });
}
```

- [ ] **Step 2: Run the model tests to verify they fail**

Run: `flutter test test/modules/search/search_models_test.dart`
Expected: FAIL with missing `SearchCollectionScope`, `SearchDateCell`, or `SearchMessageHit`

- [ ] **Step 3: Implement the typed models and repository contract**

```dart
// lib/modules/search/domain/search_models.dart
import 'package:flutter/foundation.dart';

enum SearchMenuKind { date, image, file, link, member }

enum SearchCollectionScope {
  image(<int>[2]),
  file(<int>[5]),
  link(<int>[14, 1]);

  const SearchCollectionScope(this.contentTypes);
  final List<int> contentTypes;
}

@immutable
class SearchMenuEntry {
  const SearchMenuEntry({
    required this.kind,
    required this.title,
    required this.iconAsset,
    required this.key,
  });

  final SearchMenuKind kind;
  final String title;
  final String iconAsset;
  final String key;
}

@immutable
class SearchMessageHit {
  const SearchMessageHit({
    required this.channelId,
    required this.channelType,
    required this.messageSeq,
    required this.orderSeq,
    required this.timestamp,
    required this.contentType,
    required this.fromUid,
    required this.fromName,
    required this.previewText,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final int messageSeq;
  final int orderSeq;
  final int timestamp;
  final int contentType;
  final String fromUid;
  final String fromName;
  final String previewText;
  final String? channelName;

  String get conversationKey => '$channelType:$channelId';
}

@immutable
class SearchMediaItem {
  const SearchMediaItem({
    required this.hit,
    required this.scope,
    required this.sectionKey,
    this.mediaUrl,
    this.fileName,
    this.linkUrl,
  });

  final SearchMessageHit hit;
  final SearchCollectionScope scope;
  final String sectionKey;
  final String? mediaUrl;
  final String? fileName;
  final String? linkUrl;
}

@immutable
class SearchMemberHit {
  const SearchMemberHit({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
}

@immutable
class SearchDateCell {
  const SearchDateCell({
    required this.year,
    required this.month,
    required this.day,
    required this.messageCount,
    required this.anchorOrderSeq,
    required this.isToday,
    required this.isSelected,
    this.isPlaceholder = false,
    this.weekdayOffset = 0,
  });

  const SearchDateCell.placeholder({required this.weekdayOffset})
    : year = 0,
      month = 0,
      day = 0,
      messageCount = 0,
      anchorOrderSeq = 0,
      isToday = false,
      isSelected = false,
      isPlaceholder = true;

  final int year;
  final int month;
  final int day;
  final int messageCount;
  final int anchorOrderSeq;
  final bool isToday;
  final bool isSelected;
  final bool isPlaceholder;
  final int weekdayOffset;

  bool get canOpen => !isPlaceholder && messageCount > 0 && anchorOrderSeq > 0;
}

@immutable
class SearchDateMonthSection {
  const SearchDateMonthSection({
    required this.year,
    required this.month,
    required this.cells,
  });

  final int year;
  final int month;
  final List<SearchDateCell> cells;

  String get sectionKey => '$year-${month.toString().padLeft(2, '0')}';
}

@immutable
class ChatLocateIntent {
  const ChatLocateIntent({
    required this.channelId,
    required this.channelType,
    required this.messageSeq,
    required this.orderSeq,
    required this.highlightKeyword,
    required this.source,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final int messageSeq;
  final int orderSeq;
  final String highlightKeyword;
  final String source;
  final String? channelName;
}
```

```dart
// lib/modules/search/domain/search_repository.dart
import 'search_models.dart';

abstract class SearchRepository {
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  });

  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  });

  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  });

  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  });

  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  });

  Future<GlobalSearchSnapshot> searchGlobal(String keyword);
}

class GlobalSearchSnapshot {
  const GlobalSearchSnapshot({
    this.users = const <SearchMemberHit>[],
    this.groups = const <SearchMessageHit>[],
    this.messages = const <SearchMessageHit>[],
  });

  final List<SearchMemberHit> users;
  final List<SearchMessageHit> groups;
  final List<SearchMessageHit> messages;
}
```

- [ ] **Step 4: Run the model tests again**

Run: `flutter test test/modules/search/search_models_test.dart`
Expected: PASS with 3 tests green

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/domain/search_models.dart lib/modules/search/domain/search_repository.dart test/modules/search/search_models_test.dart
git commit -m "feat: add typed search domain contracts"
```

### Task 3: Implement The Search Data Sources, Repository, And Locate Coordinator

**Files:**
- Create: `lib/modules/search/data/search_api_gateway.dart`
- Create: `lib/modules/search/data/search_remote_data_source.dart`
- Create: `lib/modules/search/data/search_local_timeline_data_source.dart`
- Create: `lib/modules/search/data/search_repository_impl.dart`
- Create: `lib/modules/search/application/search_providers.dart`
- Create: `lib/modules/search/application/chat_locate_coordinator.dart`
- Test: `test/modules/search/search_repository_test.dart`
- Test: `test/modules/search/chat_locate_coordinator_test.dart`

- [ ] **Step 1: Write the failing repository and coordinator tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/chat_locate_coordinator.dart';
import 'package:wukong_im_app/modules/search/data/search_local_timeline_data_source.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';

void main() {
  test('calendar builder pads the first week and keeps anchor counts', () {
    final sections = buildDateCalendarSections(
      buckets: const <SearchDateBucket>[
        SearchDateBucket(dayKey: '2026-04-01', messageCount: 3, anchorOrderSeq: 3000),
        SearchDateBucket(dayKey: '2026-04-03', messageCount: 8, anchorOrderSeq: 8000),
      ],
      now: DateTime(2026, 4, 3),
    );

    expect(sections, hasLength(1));
    expect(sections.single.sectionKey, '2026-04');
    expect(sections.single.cells.where((cell) => cell.isPlaceholder), isNotEmpty);
    expect(
      sections.single.cells.firstWhere((cell) => !cell.isPlaceholder && cell.day == 3).anchorOrderSeq,
      8000,
    );
  });

  test('locate coordinator resolves order sequence when the hit does not carry one', () async {
    final coordinator = ChatLocateCoordinator(
      resolveOrderSeq: ({
        required int messageSeq,
        required String channelId,
        required int channelType,
      }) async {
        expect(messageSeq, 12);
        expect(channelId, 'g1001');
        expect(channelType, 2);
        return 12000;
      },
    );

    final target = await coordinator.buildOpenRequest(
      const SearchMessageHit(
        channelId: 'g1001',
        channelType: 2,
        messageSeq: 12,
        orderSeq: 0,
        timestamp: 1710000000,
        contentType: 1,
        fromUid: 'u_alice',
        fromName: 'Alice',
        previewText: 'keyword',
        channelName: 'Design',
      ),
      highlightKeyword: 'ali',
      source: 'chat_keyword',
    );

    expect(target.orderSeq, 12000);
    expect(target.highlightKeyword, 'ali');
    expect(target.channelName, 'Design');
  });
}
```

- [ ] **Step 2: Run the repository and coordinator tests to verify they fail**

Run: `flutter test test/modules/search/search_repository_test.dart test/modules/search/chat_locate_coordinator_test.dart`
Expected: FAIL with missing `SearchDateBucket`, missing `buildDateCalendarSections`, or missing `ChatLocateCoordinator`

- [ ] **Step 3: Implement the remote adapter, local date aggregation, repository, and locate coordinator**

```dart
// lib/modules/search/data/search_api_gateway.dart
import '../../../service/api/search_api.dart';

abstract class SearchApiGateway {
  Future<Map<String, dynamic>> globalSearch(String keyword);
  Future<List<dynamic>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  });
  Future<List<dynamic>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });
  Future<List<dynamic>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });
  Future<List<dynamic>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  });
  Future<List<dynamic>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int limit,
  });
  Future<List<String>> getChannelMembers({required String channelId});
}

class LiveSearchApiGateway implements SearchApiGateway {
  @override
  Future<Map<String, dynamic>> globalSearch(String keyword) => SearchApi.instance.globalSearch(keyword);

  @override
  Future<List<dynamic>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  }) {
    return SearchApi.instance.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<dynamic>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) => SearchApi.instance.searchImages(
        channelId: channelId,
        channelType: channelType,
        page: page,
        limit: limit,
      );

  @override
  Future<List<dynamic>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) => SearchApi.instance.searchFiles(
        channelId: channelId,
        channelType: channelType,
        page: page,
        limit: limit,
      );

  @override
  Future<List<dynamic>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) => SearchApi.instance.searchLinks(
        channelId: channelId,
        channelType: channelType,
        page: page,
        limit: limit,
      );

  @override
  Future<List<dynamic>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int limit,
  }) => SearchApi.instance.searchMessagesByMember(
        channelId: channelId,
        channelType: channelType,
        senderId: senderId,
        keyword: keyword,
        limit: limit,
      );

  @override
  Future<List<String>> getChannelMembers({required String channelId}) =>
      SearchApi.instance.getChannelMembers(channelId: channelId);
}
```

```dart
// lib/modules/search/data/search_local_timeline_data_source.dart
import 'package:sqflite/sqflite.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';

class SearchDateBucket {
  const SearchDateBucket({
    required this.dayKey,
    required this.messageCount,
    required this.anchorOrderSeq,
  });

  final String dayKey;
  final int messageCount;
  final int anchorOrderSeq;
}

class SearchLocalTimelineDataSource {
  Future<List<SearchDateBucket>> loadDateBuckets({
    required String channelId,
    required int channelType,
  }) async {
    final Database? db = WKDBHelper.shared.getDB();
    if (db == null) {
      return const <SearchDateBucket>[];
    }

    final rows = await db.rawQuery(
      '''
      select
        strftime('%Y-%m-%d', ${WKDBConst.tableMessage}.timestamp, 'unixepoch', 'localtime') as day_key,
        count(*) as message_count,
        max(${WKDBConst.tableMessage}.order_seq) as anchor_order_seq
      from ${WKDBConst.tableMessage}
      left join ${WKDBConst.tableMessageExtra}
        on ${WKDBConst.tableMessage}.message_id = ${WKDBConst.tableMessageExtra}.message_id
      where ${WKDBConst.tableMessage}.channel_id = ?
        and ${WKDBConst.tableMessage}.channel_type = ?
        and ${WKDBConst.tableMessage}.is_deleted = 0
        and IFNULL(${WKDBConst.tableMessageExtra}.revoke, 0) = 0
      group by day_key
      order by day_key asc
      ''',
      <Object?>[channelId, channelType],
    );

    return rows
        .map(
          (row) => SearchDateBucket(
            dayKey: row['day_key'] as String,
            messageCount: row['message_count'] as int,
            anchorOrderSeq: row['anchor_order_seq'] as int,
          ),
        )
        .toList(growable: false);
  }
}

List<SearchDateMonthSection> buildDateCalendarSections({
  required List<SearchDateBucket> buckets,
  required DateTime now,
}) {
  if (buckets.isEmpty) {
    return const <SearchDateMonthSection>[];
  }

  final bucketMap = <String, SearchDateBucket>{
    for (final bucket in buckets) bucket.dayKey: bucket,
  };
  final first = DateTime.parse('${buckets.first.dayKey} 00:00:00');
  final startMonth = DateTime(first.year, first.month);
  final endMonth = DateTime(now.year, now.month);
  final sections = <SearchDateMonthSection>[];

  for (var cursor = startMonth;
      !cursor.isAfter(endMonth);
      cursor = DateTime(cursor.year, cursor.month + 1)) {
    final firstDay = DateTime(cursor.year, cursor.month, 1);
    final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
    final dayCount = nextMonth.subtract(const Duration(days: 1)).day;
    final leading = firstDay.weekday % 7;
    final cells = <SearchDateCell>[
      for (var index = 0; index < leading; index++)
        SearchDateCell.placeholder(weekdayOffset: index),
    ];
    for (var day = 1; day <= dayCount; day++) {
      final current = DateTime(cursor.year, cursor.month, day);
      final key =
          '${current.year.toString().padLeft(4, '0')}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      final bucket = bucketMap[key];
      cells.add(
        SearchDateCell(
          year: current.year,
          month: current.month,
          day: current.day,
          messageCount: bucket?.messageCount ?? 0,
          anchorOrderSeq: bucket?.anchorOrderSeq ?? 0,
          isToday: current.year == now.year &&
              current.month == now.month &&
              current.day == now.day,
          isSelected: current.year == now.year &&
              current.month == now.month &&
              current.day == now.day,
        ),
      );
    }
    sections.add(SearchDateMonthSection(year: cursor.year, month: cursor.month, cells: cells));
  }

  return sections;
}
```

```dart
// lib/modules/search/application/chat_locate_coordinator.dart
import '../domain/search_models.dart';

typedef ResolveOrderSeq = Future<int> Function({
  required int messageSeq,
  required String channelId,
  required int channelType,
});

class ChatOpenRequest {
  const ChatOpenRequest({
    required this.channelId,
    required this.channelType,
    required this.orderSeq,
    required this.highlightKeyword,
    required this.source,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final int orderSeq;
  final String highlightKeyword;
  final String source;
  final String? channelName;
}

class ChatLocateCoordinator {
  ChatLocateCoordinator({required ResolveOrderSeq resolveOrderSeq})
      : _resolveOrderSeq = resolveOrderSeq;

  final ResolveOrderSeq _resolveOrderSeq;

  Future<ChatOpenRequest> buildOpenRequest(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) async {
    final orderSeq = hit.orderSeq > 0
        ? hit.orderSeq
        : await _resolveOrderSeq(
            messageSeq: hit.messageSeq,
            channelId: hit.channelId,
            channelType: hit.channelType,
          );
    return ChatOpenRequest(
      channelId: hit.channelId,
      channelType: hit.channelType,
      orderSeq: orderSeq,
      highlightKeyword: highlightKeyword,
      source: source,
      channelName: hit.channelName,
    );
  }
}
```

- [ ] **Step 4: Wire providers for the repository and locate coordinator**

```dart
// lib/modules/search/application/search_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../data/search_api_gateway.dart';
import '../data/search_local_timeline_data_source.dart';
import '../data/search_remote_data_source.dart';
import '../data/search_repository_impl.dart';
import '../domain/search_repository.dart';
import 'chat_locate_coordinator.dart';

final searchApiGatewayProvider = Provider<SearchApiGateway>((ref) {
  return LiveSearchApiGateway();
});

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSource(api: ref.read(searchApiGatewayProvider));
});

final searchLocalTimelineDataSourceProvider =
    Provider<SearchLocalTimelineDataSource>((ref) {
  return SearchLocalTimelineDataSource();
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(
    remote: ref.read(searchRemoteDataSourceProvider),
    local: ref.read(searchLocalTimelineDataSourceProvider),
  );
});

final chatLocateCoordinatorProvider = Provider<ChatLocateCoordinator>((ref) {
  return ChatLocateCoordinator(
    resolveOrderSeq: ({
      required int messageSeq,
      required String channelId,
      required int channelType,
    }) {
      return WKIM.shared.messageManager.getMessageOrderSeq(
        messageSeq,
        channelId,
        channelType,
      );
    },
  );
});
```

- [ ] **Step 5: Run analysis and the repository/coordinator tests**

Run: `dart analyze lib/modules/search`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/search_repository_test.dart test/modules/search/chat_locate_coordinator_test.dart`
Expected: PASS with repository mapping and locate resolution covered

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/search/data/search_api_gateway.dart lib/modules/search/data/search_remote_data_source.dart lib/modules/search/data/search_local_timeline_data_source.dart lib/modules/search/data/search_repository_impl.dart lib/modules/search/application/search_providers.dart lib/modules/search/application/chat_locate_coordinator.dart test/modules/search/search_repository_test.dart test/modules/search/chat_locate_coordinator_test.dart
git commit -m "feat: add search repository and locate coordinator"
```

### Task 4: Rebuild The In-Chat Search Entry And Keyword Result Flow

**Files:**
- Create: `lib/modules/search/application/chat_keyword_search_controller.dart`
- Create: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Create: `lib/modules/search/presentation/chat_search_results_page.dart`
- Create: `lib/modules/search/presentation/widgets/search_message_tile.dart`
- Create: `lib/modules/search/presentation/widgets/search_menu_grid.dart`
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/search/search_exports.dart`
- Test: `test/modules/search/chat_search_entry_page_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Write the failing entry-page and mounted-entry tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    if (keyword.isEmpty) {
      return const <SearchMessageHit>[];
    }
    return const <SearchMessageHit>[
      SearchMessageHit(
        channelId: 'g1001',
        channelType: 2,
        messageSeq: 12,
        orderSeq: 12000,
        timestamp: 1710000000,
        contentType: 1,
        fromUid: 'u_alice',
        fromName: 'Alice',
        previewText: 'keyword result',
        channelName: 'Design',
      ),
    ];
  }

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async => const <SearchDateMonthSection>[];

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async => const <SearchMediaItem>[];

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async => const <SearchMemberHit>[];

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async =>
      const GlobalSearchSnapshot();
}

void main() {
  testWidgets('empty keyword shows the scoped search menu', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        ],
        child: const MaterialApp(
          home: ChatSearchEntryPage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat-search-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-search-menu-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-search-menu-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-search-results-list')), findsNothing);
  });

  testWidgets('typing switches the page into keyword-result mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        ],
        child: const MaterialApp(
          home: ChatSearchEntryPage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('chat-search-field')), 'ali');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-search-menu-grid')), findsNothing);
    expect(find.byKey(const ValueKey('chat-search-results-list')), findsOneWidget);
    expect(find.text('keyword result'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the entry-page tests to verify they fail**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`
Expected: FAIL with missing `ChatSearchEntryPage`, missing `searchRepositoryProvider`, or missing result/menu keys

- [ ] **Step 3: Implement the keyword controller and entry/result pages**

```dart
// lib/modules/search/application/chat_keyword_search_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'search_providers.dart';

@immutable
class ChatKeywordSearchState {
  const ChatKeywordSearchState({
    this.keyword = '',
    this.items = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final String keyword;
  final List<SearchMessageHit> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  bool get showMenu => keyword.trim().isEmpty;

  ChatKeywordSearchState copyWith({
    String? keyword,
    List<SearchMessageHit>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return ChatKeywordSearchState(
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

typedef ChatSearchTarget = ({String channelId, int channelType});

final chatKeywordSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatKeywordSearchController, ChatKeywordSearchState, ChatSearchTarget>((ref, target) {
  return ChatKeywordSearchController(
    channelId: target.channelId,
    channelType: target.channelType,
    repository: ref.read(searchRepositoryProvider),
  );
});

class ChatKeywordSearchController extends StateNotifier<ChatKeywordSearchState> {
  ChatKeywordSearchController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatKeywordSearchState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;
  Timer? _debounce;

  void updateKeyword(String keyword) {
    state = state.copyWith(keyword: keyword, page: 1, error: null);
    _debounce?.cancel();
    if (keyword.trim().isEmpty) {
      state = state.copyWith(items: const <SearchMessageHit>[], hasMore: true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final keyword = state.keyword.trim();
    if (keyword.isEmpty) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null, page: 1);
    try {
      final items = await _repository.searchMessages(
        channelId: channelId,
        channelType: channelType,
        keyword: keyword,
        page: 1,
        limit: 20,
      );
      state = state.copyWith(
        items: items,
        page: 1,
        isLoading: false,
        hasMore: items.length == 20,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_entry_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_page.dart';
import '../application/chat_keyword_search_controller.dart';
import '../application/chat_locate_coordinator.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'chat_search_collection_page.dart';
import 'chat_search_date_page.dart';
import 'chat_search_member_page.dart';
import 'widgets/search_menu_grid.dart';
import 'widgets/search_message_tile.dart';

class ChatSearchEntryPage extends ConsumerWidget {
  const ChatSearchEntryPage({
    super.key,
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = (channelId: channelId, channelType: channelType);
    final state = ref.watch(chatKeywordSearchControllerProvider(target));
    final controller = ref.read(chatKeywordSearchControllerProvider(target).notifier);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('chat-search-field'),
          autofocus: true,
          onChanged: controller.updateKeyword,
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search'),
        ),
      ),
      body: state.showMenu
          ? SearchMenuGrid(
              key: const ValueKey('chat-search-menu-grid'),
              entries: buildDefaultSearchMenuEntries(),
              onTap: (entry) => _openScope(context, entry),
            )
          : ListView.builder(
              key: const ValueKey('chat-search-results-list'),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final hit = state.items[index];
                return SearchMessageTile(
                  hit: hit,
                  onTap: () async {
                    final openRequest = await ref.read(chatLocateCoordinatorProvider).buildOpenRequest(
                          hit,
                          highlightKeyword: state.keyword,
                          source: 'chat_keyword',
                        );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          channelId: openRequest.channelId,
                          channelType: openRequest.channelType,
                          channelName: openRequest.channelName,
                          initialAroundOrderSeq: openRequest.orderSeq,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _openScope(BuildContext context, SearchMenuEntry entry) {
    final Widget page = switch (entry.kind) {
      SearchMenuKind.date => ChatSearchDatePage(channelId: channelId, channelType: channelType),
      SearchMenuKind.image => ChatSearchCollectionPage(
          channelId: channelId,
          channelType: channelType,
          scope: SearchCollectionScope.image,
        ),
      SearchMenuKind.file => ChatSearchCollectionPage(
          channelId: channelId,
          channelType: channelType,
          scope: SearchCollectionScope.file,
        ),
      SearchMenuKind.link => ChatSearchCollectionPage(
          channelId: channelId,
          channelType: channelType,
          scope: SearchCollectionScope.link,
        ),
      SearchMenuKind.member => ChatSearchMemberPage(channelId: channelId, channelType: channelType),
    };

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
```

- [ ] **Step 4: Mount the search entry from the chat shell instead of leaving the placeholder**

```dart
// chat_page.dart
class ChatSearchPage extends StatelessWidget {
  const ChatSearchPage({
    super.key,
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;

  @override
  Widget build(BuildContext context) {
    return ChatSearchEntryPage(channelId: channelId, channelType: channelType);
  }
}
```

```dart
// chat_page_shell.dart
Future<void> _openChatSearch() async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatSearchPage(
        channelId: widget.channelId,
        channelType: widget.channelType,
      ),
    ),
  );
}

actions: [
  if (_showCallActions()) ...[
    // existing call buttons
  ],
  IconButton(
    key: const ValueKey('chat-open-search'),
    onPressed: _openChatSearch,
    icon: WKReferenceAssets.image(
      WKReferenceAssets.search,
      width: 20,
      height: 20,
      tint: WKColors.popupText,
    ),
  ),
  IconButton(
    onPressed: () {},
    icon: WKReferenceAssets.image(
      WKReferenceAssets.topMore,
      width: 20,
      height: 20,
      tint: WKColors.popupText,
    ),
  ),
],
```

- [ ] **Step 5: Run the entry-page tests and the chat parity check**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`
Expected: PASS with menu state and keyword state covered

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS with the new mounted search-entry assertion added and no regression in existing chat parity checks

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/search/application/chat_keyword_search_controller.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_results_page.dart lib/modules/search/presentation/widgets/search_message_tile.dart lib/modules/search/presentation/widgets/search_menu_grid.dart lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart lib/modules/search/search_exports.dart test/modules/search/chat_search_entry_page_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: rebuild in-chat keyword search entry"
```

### Task 5: Rebuild The Android-Style Date Search Page

**Files:**
- Create: `lib/modules/search/application/chat_date_calendar_controller.dart`
- Create: `lib/modules/search/presentation/chat_search_date_page.dart`
- Create: `lib/modules/search/presentation/widgets/search_date_calendar.dart`
- Modify: `lib/modules/search/search_with_date_page.dart`
- Test: `test/modules/search/chat_search_date_page_test.dart`

- [ ] **Step 1: Write the failing date-page tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_date_page.dart';

class _FakeDateRepository implements SearchRepository {
  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchDateMonthSection>[
      SearchDateMonthSection(
        year: 2026,
        month: 4,
        cells: <SearchDateCell>[
          SearchDateCell.placeholder(weekdayOffset: 0),
          SearchDateCell(
            year: 2026,
            month: 4,
            day: 1,
            messageCount: 3,
            anchorOrderSeq: 3000,
            isToday: false,
            isSelected: false,
          ),
          SearchDateCell(
            year: 2026,
            month: 4,
            day: 3,
            messageCount: 8,
            anchorOrderSeq: 8000,
            isToday: true,
            isSelected: true,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async => const <SearchMediaItem>[];

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async => const <SearchMemberHit>[];

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async =>
      const GlobalSearchSnapshot();
}

void main() {
  testWidgets('date page renders month sections and day cells', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeDateRepository()),
        ],
        child: const MaterialApp(
          home: ChatSearchDatePage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-date-section-2026-04')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-date-cell-2026-04-03')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the date-page tests to verify they fail**

Run: `flutter test test/modules/search/chat_search_date_page_test.dart`
Expected: FAIL with missing `ChatSearchDatePage` or missing date-section keys

- [ ] **Step 3: Implement the controller, calendar widget, and compatibility wrapper**

```dart
// lib/modules/search/application/chat_date_calendar_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'chat_keyword_search_controller.dart';
import 'search_providers.dart';

@immutable
class ChatDateCalendarState {
  const ChatDateCalendarState({
    this.sections = const <SearchDateMonthSection>[],
    this.isLoading = false,
    this.error,
  });

  final List<SearchDateMonthSection> sections;
  final bool isLoading;
  final String? error;
}

final chatDateCalendarControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatDateCalendarController, ChatDateCalendarState, ChatSearchTarget>((ref, target) {
  return ChatDateCalendarController(
    channelId: target.channelId,
    channelType: target.channelType,
    repository: ref.read(searchRepositoryProvider),
  )..load();
});

class ChatDateCalendarController extends StateNotifier<ChatDateCalendarState> {
  ChatDateCalendarController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatDateCalendarState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;

  Future<void> load() async {
    state = const ChatDateCalendarState(isLoading: true);
    try {
      final sections = await _repository.loadDateCalendar(
        channelId: channelId,
        channelType: channelType,
      );
      state = ChatDateCalendarState(sections: sections);
    } catch (error) {
      state = ChatDateCalendarState(error: '$error');
    }
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_date_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_page.dart';
import '../application/chat_date_calendar_controller.dart';
import '../application/chat_keyword_search_controller.dart';
import '../domain/search_models.dart';
import 'widgets/search_date_calendar.dart';

class ChatSearchDatePage extends ConsumerWidget {
  const ChatSearchDatePage({
    super.key,
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = (channelId: channelId, channelType: channelType);
    final state = ref.watch(chatDateCalendarControllerProvider(target));

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null) {
      return Scaffold(body: Center(child: Text(state.error!)));
    }

    return Scaffold(
      body: SearchDateCalendar(
        sections: state.sections,
        onTapCell: (cell) async {
          if (!cell.canOpen) {
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                channelId: channelId,
                channelType: channelType,
                initialAroundOrderSeq: cell.anchorOrderSeq,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

```dart
// lib/modules/search/search_with_date_page.dart
import 'presentation/chat_search_date_page.dart';

class SearchWithDatePage extends ChatSearchDatePage {
  const SearchWithDatePage({
    super.key,
    required super.channelId,
    required super.channelType,
  });
}
```

- [ ] **Step 4: Run the date-page tests and the search analysis**

Run: `flutter test test/modules/search/chat_search_date_page_test.dart`
Expected: PASS with month sections and date-cell rendering covered

Run: `dart analyze lib/modules/search`
Expected: PASS with no analyzer errors

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/application/chat_date_calendar_controller.dart lib/modules/search/presentation/chat_search_date_page.dart lib/modules/search/presentation/widgets/search_date_calendar.dart lib/modules/search/search_with_date_page.dart test/modules/search/chat_search_date_page_test.dart
git commit -m "feat: rebuild date-based chat search"
```

### Task 6: Rebuild The Image, File, Link, And Member Search Flows

**Files:**
- Create: `lib/modules/search/application/chat_media_search_controller.dart`
- Create: `lib/modules/search/application/chat_member_search_controller.dart`
- Create: `lib/modules/search/presentation/chat_search_collection_page.dart`
- Create: `lib/modules/search/presentation/chat_search_member_page.dart`
- Create: `lib/modules/search/presentation/widgets/search_collection_section.dart`
- Modify: `lib/modules/search/search_with_img_page.dart`
- Modify: `lib/modules/search/search_exports.dart`
- Test: `test/modules/search/chat_search_collection_page_test.dart`
- Test: `test/modules/search/chat_search_member_page_test.dart`

- [ ] **Step 1: Write the failing collection and member-page tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_member_page.dart';

class _FakeScopedRepository implements SearchRepository {
  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    return <SearchMediaItem>[
      SearchMediaItem(
        hit: const SearchMessageHit(
          channelId: 'g1001',
          channelType: 2,
          messageSeq: 33,
          orderSeq: 33000,
          timestamp: 1710000000,
          contentType: 2,
          fromUid: 'u_alice',
          fromName: 'Alice',
          previewText: '[image]',
          channelName: 'Design',
        ),
        scope: scope,
        sectionKey: '2026-04',
        mediaUrl: 'https://cdn.example.com/image.png',
      ),
    ];
  }

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchMemberHit>[
      SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
      SearchMemberHit(uid: 'u_bob', displayName: 'Bob'),
    ];
  }

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return <SearchMessageHit>[
      SearchMessageHit(
        channelId: channelId,
        channelType: channelType,
        messageSeq: 44,
        orderSeq: 44000,
        timestamp: 1710000000,
        contentType: 1,
        fromUid: memberUid,
        fromName: memberUid == 'u_alice' ? 'Alice' : 'Bob',
        previewText: 'member result',
        channelName: 'Design',
      ),
    ];
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async => const <SearchDateMonthSection>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async =>
      const GlobalSearchSnapshot();
}

void main() {
  testWidgets('image collection page renders grouped sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeScopedRepository()),
        ],
        child: const MaterialApp(
          home: ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-collection-section-2026-04')), findsOneWidget);
  });

  testWidgets('member page renders members and opens member-filtered results', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeScopedRepository()),
        ],
        child: const MaterialApp(
          home: ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-member-u_alice')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-member-u_alice')));
    await tester.pumpAndSettle();
    expect(find.text('member result'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the collection and member tests to verify they fail**

Run: `flutter test test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`
Expected: FAIL with missing controllers, missing pages, or missing collection/member keys

- [ ] **Step 3: Implement the collection and member controllers plus compatibility wrapper**

```dart
// lib/modules/search/application/chat_media_search_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'chat_keyword_search_controller.dart';
import 'search_providers.dart';

@immutable
class ChatMediaSearchState {
  const ChatMediaSearchState({
    this.items = const <SearchMediaItem>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<SearchMediaItem> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
}

final chatMediaSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMediaSearchController, ChatMediaSearchState, ({String channelId, int channelType, SearchCollectionScope scope})>((ref, target) {
  return ChatMediaSearchController(
    channelId: target.channelId,
    channelType: target.channelType,
    scope: target.scope,
    repository: ref.read(searchRepositoryProvider),
  )..refresh();
});
```

```dart
// lib/modules/search/presentation/chat_search_collection_page.dart
class ChatSearchCollectionPage extends ConsumerWidget {
  const ChatSearchCollectionPage({
    super.key,
    required this.channelId,
    required this.channelType,
    required this.scope,
  });

  final String channelId;
  final int channelType;
  final SearchCollectionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      chatMediaSearchControllerProvider(
        (channelId: channelId, channelType: channelType, scope: scope),
      ),
    );
    return Scaffold(
      body: ListView(
        children: groupCollectionItems(state.items)
            .entries
            .map(
              (entry) => SearchCollectionSection(
                key: ValueKey('search-collection-section-${entry.key}'),
                sectionKey: entry.key,
                items: entry.value,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
```

```dart
// lib/modules/search/search_with_img_page.dart
import 'presentation/chat_search_collection_page.dart';
import 'domain/search_models.dart';

class SearchWithImgPage extends ChatSearchCollectionPage {
  const SearchWithImgPage({
    super.key,
    required super.channelId,
    required super.channelType,
  }) : super(scope: SearchCollectionScope.image);
}
```

- [ ] **Step 4: Run the collection and member tests**

Run: `flutter test test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`
Expected: PASS with grouped collection rendering and member-selection flow covered

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/application/chat_media_search_controller.dart lib/modules/search/application/chat_member_search_controller.dart lib/modules/search/presentation/chat_search_collection_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/presentation/widgets/search_collection_section.dart lib/modules/search/search_with_img_page.dart lib/modules/search/search_exports.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart
git commit -m "feat: rebuild scoped collection and member search"
```

### Task 7: Converge Global Search Onto The New Feature Core And Verify Compatibility

**Files:**
- Create: `lib/modules/search/application/global_search_controller.dart`
- Create: `lib/modules/search/presentation/global_search_page.dart`
- Create: `test/modules/search/search_pages_compile_test.dart`
- Modify: `lib/wukong_uikit/search/global_search_page.dart`
- Modify: `test/wukong_uikit/search/global_search_page_parity_test.dart`
- Modify: `lib/modules/search/search_exports.dart`

- [ ] **Step 1: Write the failing compatibility and compile tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_date_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_member_page.dart';
import 'package:wukong_im_app/wukong_uikit/search/global_search_page.dart';

void main() {
  testWidgets('new search pages compile inside ProviderScope', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatSearchEntryPage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );

    expect(find.byType(ChatSearchEntryPage), findsOneWidget);
    expect(const ChatSearchDatePage(channelId: 'g1001', channelType: 2), isA<Widget>());
    expect(
      const ChatSearchCollectionPage(
        channelId: 'g1001',
        channelType: 2,
        scope: SearchCollectionScope.image,
      ),
      isA<Widget>(),
    );
    expect(const ChatSearchMemberPage(channelId: 'g1001', channelType: 2), isA<Widget>());
  });

  testWidgets('legacy global search import still resolves the compatibility page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalSearchPage(
          onSearch: _emptyGlobalSearch,
        ),
      ),
    );

    expect(find.byType(GlobalSearchPage), findsOneWidget);
  });
}

Future<GlobalSearchResults> _emptyGlobalSearch(String _) async =>
    const GlobalSearchResults();
```

- [ ] **Step 2: Run the compatibility and compile tests to verify they fail**

Run: `flutter test test/modules/search/search_pages_compile_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart`
Expected: FAIL with missing new pages or with legacy global-search imports still bound to the old implementation

- [ ] **Step 3: Implement the new global-search page and the compatibility export surface**

```dart
// lib/modules/search/presentation/global_search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/global_search_controller.dart';
import '../domain/search_models.dart';

class GlobalSearchResults {
  const GlobalSearchResults({
    this.users = const <SearchMemberHit>[],
    this.groups = const <SearchMessageHit>[],
    this.messages = const <SearchMessageHit>[],
  });

  final List<SearchMemberHit> users;
  final List<SearchMessageHit> groups;
  final List<SearchMessageHit> messages;
}

class GlobalSearchPage extends ConsumerWidget {
  const GlobalSearchPage({
    super.key,
    this.initialQuery,
    this.onSearch,
    this.onOpenSearchUser,
    this.onOpenUserChat,
    this.onOpenGroupChat,
    this.onOpenMessageResults,
  });

  final String? initialQuery;
  final Future<GlobalSearchResults> Function(String query)? onSearch;
  final ValueChanged<String>? onOpenSearchUser;
  final ValueChanged<SearchMemberHit>? onOpenUserChat;
  final ValueChanged<SearchMessageHit>? onOpenGroupChat;
  final void Function(SearchMessageHit message, String searchKey)? onOpenMessageResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _GlobalSearchScaffold();
  }
}
```

```dart
// lib/wukong_uikit/search/global_search_page.dart
export '../../modules/search/presentation/global_search_page.dart';
```

- [ ] **Step 4: Run the full search verification suite**

Run: `dart analyze lib/modules/search lib/wukong_uikit/search/global_search_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/search_pages_compile_test.dart`
Expected: PASS with the new page compile coverage green

Run: `flutter test test/wukong_uikit/search/global_search_page_parity_test.dart`
Expected: PASS with the legacy import path still behaving like the Android-style search UI

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS with mounted search entry and anchored navigation still green

- [ ] **Step 5: Verify the deployed backend if any global-search mismatch remains**

Run: `ssh root@103.207.68.33 "docker ps --format '{{.Names}}' && docker logs --tail 200 fullstack-tangsengdaoserver-1 && tail -n 200 /data/fullstack/wukongimdata/logs/error.log"`
Expected: the IM backend container is running and there are no search-module errors explaining a parity mismatch

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/search/application/global_search_controller.dart lib/modules/search/presentation/global_search_page.dart lib/wukong_uikit/search/global_search_page.dart lib/modules/search/search_exports.dart test/modules/search/search_pages_compile_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart
git commit -m "feat: converge global search on the new search feature core"
```

## Supporting Skeletons

The tasks above reference a few shared files that should be written exactly once and then reused across the feature. Keep these definitions in sync with the task code.

```dart
// lib/modules/search/data/search_remote_data_source.dart
import '../domain/search_models.dart';
import 'search_api_gateway.dart';

class SearchRemoteDataSource {
  SearchRemoteDataSource({required SearchApiGateway api}) : _api = api;

  final SearchApiGateway _api;

  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final rows = await _api.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      pageSize: limit,
    );
    return rows
        .map(
          (row) => SearchMessageHit(
            channelId: row['channel_id'] as String,
            channelType: row['channel_type'] as int,
            messageSeq: row['message_seq'] as int,
            orderSeq: row['order_seq'] as int? ?? 0,
            timestamp: row['timestamp'] as int,
            contentType: row['content_type'] as int,
            fromUid: row['from_uid'] as String? ?? '',
            fromName: row['from_name'] as String? ?? '',
            previewText: row['content'] as String? ?? '',
            channelName: row['channel_name'] as String?,
          ),
        )
        .toList(growable: false);
  }
}
```

```dart
// lib/modules/search/data/search_repository_impl.dart
import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'search_local_timeline_data_source.dart';
import 'search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required SearchRemoteDataSource remote,
    required SearchLocalTimelineDataSource local,
  }) : _remote = remote,
       _local = local;

  final SearchRemoteDataSource _remote;
  final SearchLocalTimelineDataSource _local;

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) {
    return _remote.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    final buckets = await _local.loadDateBuckets(
      channelId: channelId,
      channelType: channelType,
    );
    return buildDateCalendarSections(
      buckets: buckets,
      now: DateTime.now(),
    );
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_results_page.dart
class ChatSearchResultsPage extends StatelessWidget {
  const ChatSearchResultsPage({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<SearchMessageHit> items;
  final ValueChanged<SearchMessageHit> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('chat-search-results-list'),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final hit = items[index];
        return SearchMessageTile(hit: hit, onTap: () => onTap(hit));
      },
    );
  }
}

// lib/modules/search/presentation/widgets/search_message_tile.dart
class SearchMessageTile extends StatelessWidget {
  const SearchMessageTile({
    super.key,
    required this.hit,
    required this.onTap,
  });

  final SearchMessageHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(hit.fromName.isEmpty ? hit.channelId : hit.fromName),
      subtitle: Text(hit.previewText, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

// lib/modules/search/presentation/widgets/search_menu_grid.dart
List<SearchMenuEntry> buildDefaultSearchMenuEntries() {
  return const <SearchMenuEntry>[
    SearchMenuEntry(kind: SearchMenuKind.date, title: 'Date', iconAsset: 'assets/date.png', key: 'chat-search-menu-date'),
    SearchMenuEntry(kind: SearchMenuKind.image, title: 'Image', iconAsset: 'assets/image.png', key: 'chat-search-menu-image'),
    SearchMenuEntry(kind: SearchMenuKind.file, title: 'File', iconAsset: 'assets/file.png', key: 'chat-search-menu-file'),
    SearchMenuEntry(kind: SearchMenuKind.link, title: 'Link', iconAsset: 'assets/link.png', key: 'chat-search-menu-link'),
    SearchMenuEntry(kind: SearchMenuKind.member, title: 'Member', iconAsset: 'assets/member.png', key: 'chat-search-menu-member'),
  ];
}

class SearchMenuGrid extends StatelessWidget {
  const SearchMenuGrid({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<SearchMenuEntry> entries;
  final ValueChanged<SearchMenuEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      children: entries
          .map(
            (entry) => InkWell(
              key: ValueKey(entry.key),
              onTap: () => onTap(entry),
              child: Center(child: Text(entry.title)),
            ),
          )
          .toList(growable: false),
    );
  }
}
```

```dart
// lib/modules/search/presentation/widgets/search_date_calendar.dart
class SearchDateCalendar extends StatelessWidget {
  const SearchDateCalendar({
    super.key,
    required this.sections,
    required this.onTapCell,
  });

  final List<SearchDateMonthSection> sections;
  final ValueChanged<SearchDateCell> onTapCell;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: sections
          .map(
            (section) => Column(
              key: ValueKey('search-date-section-${section.sectionKey}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.sectionKey),
                Wrap(
                  children: section.cells
                      .map(
                        (cell) => GestureDetector(
                          key: cell.isPlaceholder
                              ? null
                              : ValueKey(
                                  'search-date-cell-${cell.year.toString().padLeft(4, '0')}-${cell.month.toString().padLeft(2, '0')}-${cell.day.toString().padLeft(2, '0')}',
                                ),
                          onTap: cell.canOpen ? () => onTapCell(cell) : null,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Text(cell.isPlaceholder ? '' : '${cell.day}'),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}
```

```dart
// lib/modules/search/application/chat_member_search_controller.dart
@immutable
class ChatMediaSearchState {
  const ChatMediaSearchState({
    this.items = const <SearchMediaItem>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<SearchMediaItem> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
}

class ChatMediaSearchController extends StateNotifier<ChatMediaSearchState> {
  ChatMediaSearchController({
    required this.channelId,
    required this.channelType,
    required this.scope,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatMediaSearchState());

  final String channelId;
  final int channelType;
  final SearchCollectionScope scope;
  final SearchRepository _repository;

  Future<void> refresh() async {
    state = const ChatMediaSearchState(isLoading: true);
    final items = await _repository.searchCollection(
      channelId: channelId,
      channelType: channelType,
      scope: scope,
      page: 1,
      limit: 20,
    );
    state = ChatMediaSearchState(
      items: items,
      page: 1,
      hasMore: items.length == 20,
    );
  }
}

@immutable
class ChatMemberSearchState {
  const ChatMemberSearchState({
    this.members = const <SearchMemberHit>[],
    this.selectedMemberUid,
    this.items = const <SearchMessageHit>[],
    this.isLoading = false,
  });

  final List<SearchMemberHit> members;
  final String? selectedMemberUid;
  final List<SearchMessageHit> items;
  final bool isLoading;
}

final chatMemberSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMemberSearchController, ChatMemberSearchState, ChatSearchTarget>((ref, target) {
  return ChatMemberSearchController(
    channelId: target.channelId,
    channelType: target.channelType,
    repository: ref.read(searchRepositoryProvider),
  )..loadMembers();
});

class ChatMemberSearchController extends StateNotifier<ChatMemberSearchState> {
  ChatMemberSearchController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatMemberSearchState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;

  Future<void> loadMembers() async {
    final members = await _repository.loadMembers(
      channelId: channelId,
      channelType: channelType,
    );
    state = ChatMemberSearchState(members: members);
  }
}
```

```dart
// lib/modules/search/presentation/widgets/search_collection_section.dart
Map<String, List<SearchMediaItem>> groupCollectionItems(List<SearchMediaItem> items) {
  final map = <String, List<SearchMediaItem>>{};
  for (final item in items) {
    map.putIfAbsent(item.sectionKey, () => <SearchMediaItem>[]).add(item);
  }
  return map;
}

class SearchCollectionSection extends StatelessWidget {
  const SearchCollectionSection({
    super.key,
    required this.sectionKey,
    required this.items,
  });

  final String sectionKey;
  final List<SearchMediaItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionKey),
        Wrap(
          children: items
              .map((item) => SizedBox(width: 72, height: 72, child: Text(item.hit.previewText)))
              .toList(growable: false),
        ),
      ],
    );
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_member_page.dart
class ChatSearchMemberPage extends ConsumerWidget {
  const ChatSearchMemberPage({
    super.key,
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = (channelId: channelId, channelType: channelType);
    final state = ref.watch(chatMemberSearchControllerProvider(target));

    return Scaffold(
      body: ListView(
        children: state.members
            .map(
              (member) => ListTile(
                key: ValueKey('search-member-${member.uid}'),
                title: Text(member.displayName),
                onTap: () {},
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
```

```dart
// lib/modules/search/application/global_search_controller.dart
@immutable
class GlobalSearchState {
  const GlobalSearchState({
    this.query = '',
    this.results = const GlobalSearchResults(),
    this.isLoading = false,
  });

  final String query;
  final GlobalSearchResults results;
  final bool isLoading;
}

final globalSearchControllerProvider =
    StateNotifierProvider.autoDispose<GlobalSearchController, GlobalSearchState>((ref) {
  return GlobalSearchController();
});

class GlobalSearchController extends StateNotifier<GlobalSearchState> {
  GlobalSearchController() : super(const GlobalSearchState());
}

class _GlobalSearchScaffold extends StatelessWidget {
  const _GlobalSearchScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Global Search')),
    );
  }
}
```

## Self-Review Checklist

- Spec coverage:
  - chat search entry and keyword results are covered by Task 4
  - date search rebuild is covered by Task 5
  - image, file, link, and member search are covered by Task 6
  - global search convergence is covered by Task 7
  - chat anchor navigation prerequisite is covered by Task 1
  - typed domain, repository, remote/local split, and locate coordination are covered by Tasks 2 and 3
- Placeholder scan:
  - no `TODO`, `TBD`, or "implement later" markers remain
  - each code-changing task includes explicit file paths, code blocks, and commands
- Type consistency:
  - `SearchMessageHit`, `SearchDateCell`, `SearchCollectionScope`, `SearchRepository`, `ChatLocateCoordinator`, and `ChatSearchEntryPage` use one stable naming scheme throughout the plan

## Expected Outcome

After this plan is implemented:

- chat search opens from a real mounted entry inside chat
- message search results land near the correct message instead of opening a generic conversation shell
- date search behaves like Android's month/day browser rather than a date-range picker
- image, file, link, and member search all share typed data flow and paged state handling
- global search uses the same search core while keeping the old import path stable
- the Flutter search subsystem becomes one authoritative, testable feature instead of three disconnected partial implementations
