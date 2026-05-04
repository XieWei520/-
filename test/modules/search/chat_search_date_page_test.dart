import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/search/application/chat_locate_coordinator.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/data/search_locate_resolver.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_date_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await StorageUtils.setUid('u_self');
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  Widget wrapWithApp(
    Widget child, {
    required SearchRepository repository,
    SearchLocateResolver? searchLocateResolver,
    ChatLocateCoordinator? chatLocateCoordinator,
  }) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
        if (searchLocateResolver != null)
          searchLocateResolverProvider.overrideWithValue(searchLocateResolver),
        if (chatLocateCoordinator != null)
          chatLocateCoordinatorProvider.overrideWithValue(
            chatLocateCoordinator,
          ),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
      ],
      child: MaterialApp(locale: const Locale('en'), home: child),
    );
  }

  testWidgets(
    'date page renders weekday headers with Sunday-first order and month cells',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
          repository: _FakeDateRepository(
            sections: const <SearchDateMonthSection>[
              SearchDateMonthSection(
                year: 2026,
                month: 4,
                cells: <SearchDateCell>[
                  SearchDateCell.placeholder(weekdayOffset: 0),
                  SearchDateCell(
                    year: 2026,
                    month: 4,
                    day: 1,
                    messageCount: 0,
                    anchorOrderSeq: 0,
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
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      const expectedWeekdays = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];
      for (var index = 0; index < expectedWeekdays.length; index++) {
        expect(
          find.byKey(ValueKey<String>('search-date-weekday-$index')),
          findsOneWidget,
        );
        final label = tester.widget<Text>(
          find.byKey(ValueKey<String>('search-date-weekday-$index')),
        );
        expect(label.data, expectedWeekdays[index]);
      }

      expect(
        find.byKey(const ValueKey<String>('search-date-section-2026-04')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-date-day-chip-2026-04-03')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-date-today-2026-04-03')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping a navigable day routes through locate pipeline and opens chat with resolved anchor',
    (tester) async {
      final resolver = _FakeSearchLocateResolver(
        resolvedIntent: const ChatLocateIntent(
          channelId: 'group-1',
          channelType: 2,
          orderSeq: 4321,
          source: 'resolved-date-cell',
          channelName: 'Resolved Room',
        ),
      );
      final coordinator = _FakeChatLocateCoordinator(
        requestBuilder: (intent) async => ChatOpenRequest(
          channelId: intent.channelId,
          channelType: intent.channelType,
          orderSeq: intent.orderSeq,
          highlightKeyword: intent.highlightKeyword,
          source: intent.source,
          channelName: intent.channelName,
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
          repository: _FakeDateRepository(
            sections: const <SearchDateMonthSection>[
              SearchDateMonthSection(
                year: 2026,
                month: 4,
                cells: <SearchDateCell>[
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
            ],
          ),
          searchLocateResolver: resolver,
          chatLocateCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')),
      );
      await tester.pumpAndSettle();

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, 4321);
      expect(shell.channelName, 'Resolved Room');
      expect(resolver.fromDateCellCallCount, 1);
      expect(resolver.lastCell?.dayKey, '2026-04-03');
      expect(resolver.lastChannelId, 'group-1');
      expect(resolver.lastChannelType, 2);
      expect(resolver.lastSource, 'search-date');
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.orderSeq, 4321);
      expect(coordinator.intents.single.source, 'resolved-date-cell');
    },
  );

  testWidgets(
    'tapping a date cell keeps the tapped day selected after returning from chat',
    (tester) async {
      final coordinator = _FakeChatLocateCoordinator(
        requestBuilder: (intent) async => ChatOpenRequest(
          channelId: intent.channelId,
          channelType: intent.channelType,
          orderSeq: 4321,
          highlightKeyword: intent.highlightKeyword,
          source: intent.source,
          channelName: intent.channelName,
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
          repository: _FakeDateRepository(
            sections: const <SearchDateMonthSection>[
              SearchDateMonthSection(
                year: 2026,
                month: 4,
                cells: <SearchDateCell>[
                  SearchDateCell(
                    year: 2026,
                    month: 4,
                    day: 3,
                    messageCount: 8,
                    anchorOrderSeq: 8000,
                    isToday: true,
                    isSelected: false,
                  ),
                ],
              ),
            ],
          ),
          chatLocateCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _chipColor(
          tester,
          const ValueKey<String>('search-date-day-chip-2026-04-03'),
        ),
        Colors.transparent,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatPageShell), findsOneWidget);

      Navigator.of(tester.element(find.byType(ChatPageShell))).pop();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        _chipColor(
          tester,
          const ValueKey<String>('search-date-day-chip-2026-04-03'),
        ),
        const Color(0xFFF65835),
      );
    },
  );

  testWidgets(
    'fallback locate request opens conversation root and shows feedback',
    (tester) async {
      final resolver = _FakeSearchLocateResolver(
        resolvedIntent: const ChatLocateIntent(
          channelId: 'group-1',
          channelType: 2,
          source: 'date-fallback',
        ),
      );
      final coordinator = _FakeChatLocateCoordinator(
        requestBuilder: (intent) async => ChatOpenRequest(
          channelId: intent.channelId,
          channelType: intent.channelType,
          orderSeq: null,
          highlightKeyword: intent.highlightKeyword,
          source: intent.source,
          channelName: 'Fallback Room',
          feedbackMessage: 'Opened conversation root',
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
          repository: _FakeDateRepository(
            sections: const <SearchDateMonthSection>[
              SearchDateMonthSection(
                year: 2026,
                month: 4,
                cells: <SearchDateCell>[
                  SearchDateCell(
                    year: 2026,
                    month: 4,
                    day: 3,
                    messageCount: 8,
                    anchorOrderSeq: 8000,
                    isToday: true,
                    isSelected: false,
                  ),
                ],
              ),
            ],
          ),
          searchLocateResolver: resolver,
          chatLocateCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')),
      );
      await tester.pumpAndSettle();

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, isNull);
      expect(shell.channelName, 'Fallback Room');
      expect(find.text('Opened conversation root'), findsOneWidget);
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.source, 'date-fallback');
    },
  );

  testWidgets('tapping a non-navigable day does nothing', (tester) async {
    final resolver = _FakeSearchLocateResolver();
    final coordinator = _FakeChatLocateCoordinator(
      requestBuilder: (intent) async => ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: intent.orderSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
      ),
    );

    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
        repository: _FakeDateRepository(
          sections: const <SearchDateMonthSection>[
            SearchDateMonthSection(
              year: 2026,
              month: 4,
              cells: <SearchDateCell>[
                SearchDateCell(
                  year: 2026,
                  month: 4,
                  day: 1,
                  messageCount: 0,
                  anchorOrderSeq: 0,
                  isToday: false,
                  isSelected: false,
                ),
              ],
            ),
          ],
        ),
        searchLocateResolver: resolver,
        chatLocateCoordinator: coordinator,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('search-date-cell-2026-04-01')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatPageShell), findsNothing);
    expect(resolver.fromDateCellCallCount, 0);
    expect(coordinator.intents, isEmpty);
  });

  testWidgets('date page shows an explicit empty state', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
        repository: _FakeDateRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-date-empty-state')),
      findsOneWidget,
    );
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('date page shows an error state and retries successfully', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
        repository: _FakeDateRepository(
          failLoads: 1,
          sections: const <SearchDateMonthSection>[
            SearchDateMonthSection(
              year: 2026,
              month: 4,
              cells: <SearchDateCell>[
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
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-date-error-state')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('search-date-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-date-section-2026-04')),
      findsOneWidget,
    );
  });

  testWidgets(
    'disposing the date page before a slow load completes does not write after dispose',
    (tester) async {
      final pendingSections = Completer<List<SearchDateMonthSection>>();

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
          repository: _FakeDateRepository(pendingSections: pendingSections),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      pendingSections.complete(const <SearchDateMonthSection>[]);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date page auto-scrolls toward the newest month', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
        repository: _FakeDateRepository(
          sections: List<SearchDateMonthSection>.generate(12, (index) {
            final month = index + 1;
            return SearchDateMonthSection(
              year: 2026,
              month: month,
              cells: <SearchDateCell>[
                SearchDateCell(
                  year: 2026,
                  month: month,
                  day: 1,
                  messageCount: 1,
                  anchorOrderSeq: 1000 + month,
                  isToday: month == 12,
                  isSelected: month == 12,
                ),
              ],
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-date-section-2026-12')),
      findsOneWidget,
    );
  });
}

class _FakeDateRepository implements SearchRepository {
  _FakeDateRepository({
    this.sections = const <SearchDateMonthSection>[],
    this.pendingSections,
    this.failLoads = 0,
  });

  final List<SearchDateMonthSection> sections;
  final Completer<List<SearchDateMonthSection>>? pendingSections;
  final int failLoads;
  int _loadAttempts = 0;

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    final pending = pendingSections;
    if (pending != null) {
      return pending.future;
    }
    if (_loadAttempts < failLoads) {
      _loadAttempts += 1;
      throw StateError('load failed');
    }
    return sections;
  }

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchMemberHit>[];
  }

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    return const <SearchMediaItem>[];
  }

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const <SearchMessageHit>[];
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
    return const <SearchMessageHit>[];
  }
}

Color? _chipColor(WidgetTester tester, ValueKey<String> key) {
  final chip = tester.widget<Container>(find.byKey(key));
  final decoration = chip.decoration as BoxDecoration?;
  return decoration?.color;
}

class _FakeSearchLocateResolver extends SearchLocateResolver {
  _FakeSearchLocateResolver({this.resolvedIntent});

  final ChatLocateIntent? resolvedIntent;
  int fromDateCellCallCount = 0;
  SearchDateCell? lastCell;
  String? lastChannelId;
  int? lastChannelType;
  String? lastChannelName;
  String? lastSource;

  @override
  ChatLocateIntent fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    String? channelName,
    required String source,
  }) {
    fromDateCellCallCount += 1;
    lastCell = cell;
    lastChannelId = channelId;
    lastChannelType = channelType;
    lastChannelName = channelName;
    lastSource = source;
    return resolvedIntent ??
        super.fromDateCell(
          cell: cell,
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
          source: source,
        );
  }
}

class _FakeChatLocateCoordinator extends ChatLocateCoordinator {
  _FakeChatLocateCoordinator({required this.requestBuilder})
    : super(resolveOrderSeq: _unusedResolveOrderSeq);

  final Future<ChatOpenRequest> Function(ChatLocateIntent intent)
  requestBuilder;
  final List<ChatLocateIntent> intents = <ChatLocateIntent>[];

  @override
  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    intents.add(intent);
    return requestBuilder(intent);
  }

  static Future<int> _unusedResolveOrderSeq({
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    return 0;
  }
}

class _ImmediateSuccessAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}
