import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/data/local_search_service.dart';
import 'package:wukong_im_app/modules/search/data/search_api_gateway.dart';
import 'package:wukong_im_app/modules/search/data/search_local_timeline_data_source.dart';
import 'package:wukong_im_app/modules/search/data/search_remote_data_source.dart';
import 'package:wukong_im_app/modules/search/data/search_repository_impl.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('buildDateCalendarSections', () {
    test('pads the first week and keeps anchor counts', () {
      final sections = buildDateCalendarSections(
        buckets: const <SearchDateBucket>[
          SearchDateBucket(
            dayKey: '2026-04-03',
            messageCount: 4,
            anchorOrderSeq: 88,
          ),
          SearchDateBucket(
            dayKey: '2026-05-10',
            messageCount: 2,
            anchorOrderSeq: 144,
          ),
        ],
        now: DateTime(2026, 5, 10),
      );

      expect(sections, hasLength(2));
      expect(sections.first.sectionKey, '2026-04');
      expect(
        sections.first.cells.take(3).every((cell) => cell.isPlaceholder),
        isTrue,
      );

      final aprilThird = sections.first.cells[5];
      expect(aprilThird.isPlaceholder, isFalse);
      expect(aprilThird.day, 3);
      expect(aprilThird.messageCount, 4);
      expect(aprilThird.anchorOrderSeq, 88);

      final mayTenth = sections.last.cells.firstWhere(
        (cell) => !cell.isPlaceholder && cell.day == 10,
      );
      expect(mayTenth.messageCount, 2);
      expect(mayTenth.anchorOrderSeq, 144);
      expect(mayTenth.isToday, isTrue);
      expect(mayTenth.isSelected, isTrue);
    });
  });

  group('SearchRepositoryImpl', () {
    late _FakeSearchApiGateway gateway;
    late _FakeLocalSearchService localSearchService;
    late SearchRepositoryImpl repository;

    setUp(() {
      gateway = _FakeSearchApiGateway();
      localSearchService = _FakeLocalSearchService();
      repository = SearchRepositoryImpl(
        remoteDataSource: SearchRemoteDataSource(apiGateway: gateway),
        localTimelineDataSource: _FakeSearchLocalTimelineDataSource(),
        localSearchService: localSearchService,
        now: () => DateTime(2026, 3, 10),
      );
    });

    test(
      'searchCollection groups image results by month and prefers local image path',
      () async {
        final fakeLocalPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}image.jpg';
        final probeCalls = <String>[];
        final repositoryWithProbe = SearchRepositoryImpl(
          remoteDataSource: SearchRemoteDataSource(apiGateway: gateway),
          localTimelineDataSource: _FakeSearchLocalTimelineDataSource(),
          now: () => DateTime(2026, 3, 10),
          localImagePathExists: (path) async {
            probeCalls.add(path);
            return path == fakeLocalPath;
          },
        );

        gateway.imageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 21,
            'timestamp': 1712123456,
            'content_type': WkMessageContentType.image,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content': '[image]',
            'image_url': 'https://cdn.example.com/image.png',
            'local_path': fakeLocalPath,
            'url': 'https://cdn.example.com/image.png',
            'channel_name': 'Project Group',
          },
        ];

        final items = await repositoryWithProbe.searchCollection(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          scope: SearchCollectionScope.image,
          page: 1,
          limit: 20,
        );

        expect(items, hasLength(1));
        expect(items.first.scope, SearchCollectionScope.image);
        expect(items.first.sectionKey, '2024-04');
        expect(items.first.mediaUrl, fakeLocalPath);
        expect(probeCalls, [fakeLocalPath]);
        expect(items.first.hit.channelId, 'group-1');
        expect(items.first.hit.fromName, 'Alex');
        expect(items.first.hit.previewText, '[image]');
        expect(items.first.hit.channelName, 'Project Group');
      },
    );

    test(
      'searchCollection image falls back to image_url when local path is missing',
      () async {
        final repositoryWithProbe = SearchRepositoryImpl(
          remoteDataSource: SearchRemoteDataSource(apiGateway: gateway),
          localTimelineDataSource: _FakeSearchLocalTimelineDataSource(),
          now: () => DateTime(2026, 3, 10),
          localImagePathExists: (_) async => false,
        );
        gateway.imageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 22,
            'timestamp': 1712123456,
            'content_type': WkMessageContentType.image,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content': '[image]',
            'local_path': '/tmp/does-not-exist.jpg',
            'image_url': 'https://cdn.example.com/fallback-image.png',
            'url': 'https://cdn.example.com/fallback-url.png',
          },
        ];

        final items = await repositoryWithProbe.searchCollection(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          scope: SearchCollectionScope.image,
          page: 1,
          limit: 20,
        );

        expect(items, hasLength(1));
        expect(
          items.first.mediaUrl,
          'https://cdn.example.com/fallback-image.png',
        );
      },
    );

    test(
      'searchCollection image falls back to url when image_url is absent',
      () async {
        gateway.imageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 23,
            'timestamp': 1712123456,
            'content_type': WkMessageContentType.image,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content': '[image]',
            'url': 'https://cdn.example.com/only-url.png',
          },
        ];

        final items = await repository.searchCollection(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          scope: SearchCollectionScope.image,
          page: 1,
          limit: 20,
        );

        expect(items, hasLength(1));
        expect(items.first.mediaUrl, 'https://cdn.example.com/only-url.png');
      },
    );

    test('searchCollection non-image section key remains day-level', () async {
      gateway.fileResults = <Map<String, dynamic>>[
        <String, dynamic>{
          'channel_id': 'group-1',
          'channel_type': WKChannelType.group,
          'message_seq': 24,
          'timestamp': 1712123456,
          'content_type': WkMessageContentType.file,
          'from_uid': 'u1',
          'from_name': 'Alex',
          'content': '[file]',
          'url': 'https://cdn.example.com/doc.pdf',
          'file_name': 'doc.pdf',
        },
      ];

      final items = await repository.searchCollection(
        channelId: 'group-1',
        channelType: WKChannelType.group,
        scope: SearchCollectionScope.file,
        page: 1,
        limit: 20,
      );

      expect(items, hasLength(1));
      expect(items.first.sectionKey, '2024-04-03');
    });

    test('searchGlobal delegates to local search service', () async {
      localSearchService.globalSnapshotsByPage[1] = GlobalSearchSnapshot(
        users: const <SearchMemberHit>[
          SearchMemberHit(uid: 'u1', displayName: 'Alex'),
        ],
        groups: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: WKChannelType.group,
            messageSeq: 0,
            orderSeq: 0,
            timestamp: 0,
            contentType: 0,
            fromUid: '',
            fromName: '',
            previewText: 'Contains: Alex',
            channelName: 'Design Group',
          ),
        ],
        messages: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: WKChannelType.group,
            messageSeq: 201,
            orderSeq: 3001,
            timestamp: 1712123999,
            contentType: WkMessageContentType.text,
            fromUid: 'u1',
            fromName: 'Alex',
            previewText: 'launch checklist',
            channelName: 'Design Group',
          ),
        ],
      );
      final snapshot = await repository.searchGlobal(
        keyword: 'launch',
        page: 1,
        limit: 20,
      );

      expect(localSearchService.lastGlobalKeyword, 'launch');
      expect(localSearchService.lastGlobalPage, 1);
      expect(localSearchService.lastGlobalLimit, 20);
      expect(snapshot.users, hasLength(1));
      expect(snapshot.users.first.uid, 'u1');
      expect(snapshot.users.first.displayName, 'Alex');
      expect(snapshot.groups, hasLength(1));
      expect(snapshot.groups.first.channelId, 'group-1');
      expect(snapshot.groups.first.channelType, WKChannelType.group);
      expect(snapshot.groups.first.channelName, 'Design Group');
      expect(snapshot.groups.first.previewText, 'Contains: Alex');
      expect(snapshot.messages, hasLength(1));
      expect(snapshot.messages.first.channelId, 'group-1');
      expect(snapshot.messages.first.channelType, WKChannelType.group);
      expect(snapshot.messages.first.messageSeq, 201);
      expect(snapshot.messages.first.orderSeq, 3001);
      expect(snapshot.messages.first.timestamp, 1712123999);
      expect(snapshot.messages.first.contentType, WkMessageContentType.text);
      expect(snapshot.messages.first.fromUid, 'u1');
      expect(snapshot.messages.first.fromName, 'Alex');
      expect(snapshot.messages.first.previewText, 'launch checklist');
      expect(snapshot.messages.first.channelName, 'Design Group');
      expect(gateway.lastGlobalSearchKeyword, isEmpty);
    });

    test('searchMessages delegates to local search service', () async {
      localSearchService
              .channelMessagePages['keyword:group-1:${WKChannelType.group}:1:2'] =
          const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'group-1',
              channelType: WKChannelType.group,
              messageSeq: 202,
              orderSeq: 3002,
              timestamp: 1712124001,
              contentType: WkMessageContentType.text,
              fromUid: 'u2',
              fromName: 'Blair',
              previewText: 'page-1-hit',
              channelName: 'Design Group',
            ),
            SearchMessageHit(
              channelId: 'group-1',
              channelType: WKChannelType.group,
              messageSeq: 203,
              orderSeq: 3003,
              timestamp: 1712124002,
              contentType: WkMessageContentType.text,
              fromUid: 'u3',
              fromName: 'Casey',
              previewText: 'page-1-hit-2',
              channelName: 'Design Group',
            ),
          ];

      final items = await repository.searchMessages(
        channelId: 'group-1',
        channelType: WKChannelType.group,
        keyword: 'keyword',
        page: 1,
        limit: 2,
      );

      expect(localSearchService.lastChannelKeyword, 'keyword');
      expect(localSearchService.lastChannelId, 'group-1');
      expect(localSearchService.lastChannelType, WKChannelType.group);
      expect(localSearchService.lastChannelPage, 1);
      expect(localSearchService.lastChannelLimit, 2);
      expect(items, hasLength(2));
      expect(items.first.messageSeq, 202);
      expect(items.first.orderSeq, 3002);
      expect(items.first.previewText, 'page-1-hit');
    });

    test(
      'loadMembers maps remark name and avatar into SearchMemberHit',
      () async {
        gateway.members = <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'u1',
            'name': 'Alex',
            'remark': 'Team Alex',
            'avatar': 'https://cdn.example.com/alex.png',
          },
          <String, dynamic>{
            'uid': 'u2',
            'name': 'Blair',
            'remark': '',
            'avatar': 'https://cdn.example.com/blair.png',
          },
          <String, dynamic>{'uid': 'u3', 'name': '', 'remark': ''},
        ];

        final members = await repository.loadMembers(
          channelId: 'group-1',
          channelType: WKChannelType.group,
        );

        expect(members, hasLength(3));
        expect(members[0].uid, 'u1');
        expect(members[0].displayName, 'Team Alex');
        expect(members[0].avatarUrl, 'https://cdn.example.com/alex.png');
        expect(members[1].displayName, 'Blair');
        expect(members[1].avatarUrl, 'https://cdn.example.com/blair.png');
        expect(members[2].displayName, 'u3');
        expect(members[2].avatarUrl, isNull);
      },
    );

    test(
      'searchMessagesByMember forwards page and limit directly to remote search',
      () async {
        gateway.memberMessageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 9,
            'timestamp': 1712123409,
            'content_type': WkMessageContentType.text,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content': 'page-3-item',
            'order_seq': 999,
          },
        ];

        final page = await repository.searchMessagesByMember(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          memberUid: 'u1',
          keyword: 'message',
          page: 3,
          limit: 20,
        );

        expect(gateway.lastMemberSearchPage, 3);
        expect(gateway.lastMemberSearchLimit, 20);
        expect(page, hasLength(1));
        expect(page.single.messageSeq, 9);
        expect(page.single.orderSeq, 999);
        expect(page.single.previewText, 'page-3-item');
      },
    );

    test(
      'searchMessagesByMember prefers plain_text preview when available',
      () async {
        gateway.memberMessageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 10,
            'timestamp': 1712123410,
            'content_type': 22,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content': '{"type":22,"plain_text":"raw-json-preview"}',
            'plain_text': 'resolved-plain-text-preview',
            'order_seq': 1000,
          },
        ];

        final page = await repository.searchMessagesByMember(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          memberUid: 'u1',
          keyword: 'robot',
          page: 1,
          limit: 20,
        );

        expect(page, hasLength(1));
        expect(page.single.previewText, 'resolved-plain-text-preview');
      },
    );

    test(
      'searchMessagesByMember falls back to nested card title/body for raw robot card payload without plain_text',
      () async {
        gateway.memberMessageResults = <Map<String, dynamic>>[
          <String, dynamic>{
            'channel_id': 'group-1',
            'channel_type': WKChannelType.group,
            'message_seq': 11,
            'timestamp': 1712123411,
            'content_type': 22,
            'from_uid': 'u1',
            'from_name': 'Alex',
            'content':
                '{"type":22,"robot":{"provider":"feishu","name":"Weather Robot"},"card":{"title":"Robot title","body":"Robot body"}}',
            'order_seq': 1001,
          },
        ];

        final page = await repository.searchMessagesByMember(
          channelId: 'group-1',
          channelType: WKChannelType.group,
          memberUid: 'u1',
          keyword: 'robot',
          page: 1,
          limit: 20,
        );

        expect(page, hasLength(1));
        expect(page.single.previewText, 'Robot title Robot body');
      },
    );
  });
}

class _FakeSearchApiGateway implements SearchApiGateway {
  final Map<int, Map<String, dynamic>> globalResultsByPage =
      <int, Map<String, dynamic>>{};
  List<Map<String, dynamic>> messageResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> imageResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> fileResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> linkResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> memberMessageResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> members = <Map<String, dynamic>>[];
  String lastGlobalSearchKeyword = '';
  int lastGlobalSearchPage = 0;
  int lastGlobalSearchLimit = 0;
  int lastMemberSearchPage = 0;
  int lastMemberSearchLimit = 0;

  @override
  Future<List<Map<String, dynamic>>> getChannelMembers({
    required String channelId,
  }) async {
    return members;
  }

  @override
  Future<Map<String, dynamic>> globalSearch({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    lastGlobalSearchKeyword = keyword;
    lastGlobalSearchPage = page;
    lastGlobalSearchLimit = limit;
    return globalResultsByPage[page] ?? <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> searchFiles({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return fileResults;
  }

  @override
  Future<List<Map<String, dynamic>>> searchImages({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return imageResults;
  }

  @override
  Future<List<Map<String, dynamic>>> searchLinks({
    required String channelId,
    required int channelType,
    required int page,
    required int limit,
  }) async {
    return linkResults;
  }

  @override
  Future<List<Map<String, dynamic>>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return messageResults;
  }

  @override
  Future<List<Map<String, dynamic>>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String senderId,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    lastMemberSearchPage = page;
    lastMemberSearchLimit = limit;
    return memberMessageResults;
  }
}

class _FakeLocalSearchService extends LocalSearchService {
  _FakeLocalSearchService()
    : super(
        searchChannels: (_) async => const <WKChannelSearchResult>[],
        searchFollowedUsers: (_, __, ___) async => const <WKChannel>[],
        searchGlobalMessages: (_) async => const <WKMessageSearchResult>[],
        searchMessagesWithChannel: (_, __, ___) async => const <WKMsg>[],
      );

  final Map<int, GlobalSearchSnapshot> globalSnapshotsByPage =
      <int, GlobalSearchSnapshot>{};
  final Map<String, List<SearchMessageHit>> channelMessagePages =
      <String, List<SearchMessageHit>>{};

  String lastGlobalKeyword = '';
  int lastGlobalPage = 0;
  int lastGlobalLimit = 0;

  String lastChannelKeyword = '';
  String lastChannelId = '';
  int lastChannelType = 0;
  int lastChannelPage = 0;
  int lastChannelLimit = 0;

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    lastGlobalKeyword = keyword;
    lastGlobalPage = page;
    lastGlobalLimit = limit;
    return globalSnapshotsByPage[page] ?? const GlobalSearchSnapshot();
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    lastChannelKeyword = keyword;
    lastChannelId = channelId;
    lastChannelType = channelType;
    lastChannelPage = page;
    lastChannelLimit = limit;
    return channelMessagePages['$keyword:$channelId:$channelType:$page:$limit'] ??
        const <SearchMessageHit>[];
  }
}

class _FakeSearchLocalTimelineDataSource extends SearchLocalTimelineDataSource {
  @override
  Future<List<SearchDateBucket>> loadDateBuckets({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchDateBucket>[
      SearchDateBucket(
        dayKey: '2026-03-10',
        messageCount: 5,
        anchorOrderSeq: 200,
      ),
    ];
  }
}
