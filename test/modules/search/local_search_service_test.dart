import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/search/data/local_search_service.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'searchGlobal maps followed users, channel hits, and aggregated message hits',
    () async {
      final service = LocalSearchService(
        searchChannels: (_) async => <WKChannelSearchResult>[
          _groupResult(
            channelId: 'group-1',
            channelName: 'Design Group',
            containMemberName: 'Alex',
          ),
        ],
        searchFollowedUsers: (_, __, ___) async => <WKChannel>[
          _personalChannel(
            channelId: 'u1',
            channelName: 'Alex',
            channelRemark: 'Captain Alex',
          ),
        ],
        searchGlobalMessages: (_) async => <WKMessageSearchResult>[
          _messageAggregate(
            channelId: 'group-1',
            channelName: 'Design Group',
            searchableWord: 'launch checklist',
            messageCount: 1,
          ),
          _messageAggregate(
            channelId: 'group-2',
            channelName: 'Ops Group',
            searchableWord: 'deploy',
            messageCount: 3,
          ),
        ],
        searchMessagesWithChannel: (_, channelId, __) async {
          if (channelId != 'group-1') {
            return const <WKMsg>[];
          }
          return <WKMsg>[
            _message(
              channelId: 'group-1',
              channelName: 'Design Group',
              messageSeq: 201,
              orderSeq: 3201,
              fromUid: 'u1',
              fromName: 'Captain Alex',
              previewText: 'launch checklist',
            ),
          ];
        },
      );

      final snapshot = await service.searchGlobal(
        keyword: 'launch',
        page: 1,
        limit: 20,
      );

      expect(snapshot.users, hasLength(1));
      expect(snapshot.users.single.uid, 'u1');
      expect(snapshot.users.single.displayName, 'Captain Alex');

      expect(snapshot.groups, hasLength(1));
      expect(snapshot.groups.single.channelId, 'group-1');
      expect(snapshot.groups.single.channelName, 'Design Group');
      expect(snapshot.groups.single.previewText, 'Contains: Alex');

      expect(snapshot.messages, hasLength(2));
      expect(snapshot.messages.first.channelId, 'group-1');
      expect(snapshot.messages.first.messageSeq, 201);
      expect(snapshot.messages.first.orderSeq, 3201);
      expect(snapshot.messages.first.previewText, 'launch checklist');
      expect(snapshot.messages.first.matchCount, 1);

      expect(snapshot.messages.last.channelId, 'group-2');
      expect(snapshot.messages.last.messageSeq, 0);
      expect(snapshot.messages.last.orderSeq, 0);
      expect(snapshot.messages.last.previewText, 'deploy');
      expect(snapshot.messages.last.matchCount, 3);
    },
  );

  test('searchGlobal page > 1 returns message-only local slices', () async {
    final service = LocalSearchService(
      searchChannels: (_) async => const <WKChannelSearchResult>[],
      searchFollowedUsers: (_, __, ___) async => const <WKChannel>[],
      searchGlobalMessages: (_) async => <WKMessageSearchResult>[
        _messageAggregate(
          channelId: 'group-1',
          channelName: 'Design Group',
          searchableWord: 'hit-1',
          messageCount: 2,
        ),
        _messageAggregate(
          channelId: 'group-2',
          channelName: 'Ops Group',
          searchableWord: 'hit-2',
          messageCount: 2,
        ),
        _messageAggregate(
          channelId: 'group-3',
          channelName: 'QA Group',
          searchableWord: 'hit-3',
          messageCount: 2,
        ),
      ],
      searchMessagesWithChannel: (_, __, ___) async => const <WKMsg>[],
    );

    final snapshot = await service.searchGlobal(
      keyword: 'hit',
      page: 2,
      limit: 1,
    );

    expect(snapshot.users, isEmpty);
    expect(snapshot.groups, isEmpty);
    expect(snapshot.messages, hasLength(1));
    expect(snapshot.messages.single.channelId, 'group-2');
    expect(snapshot.messages.single.matchCount, 2);
  });

  test('searchMessages paginates local channel hits', () async {
    final service = LocalSearchService(
      searchChannels: (_) async => const <WKChannelSearchResult>[],
      searchFollowedUsers: (_, __, ___) async => const <WKChannel>[],
      searchGlobalMessages: (_) async => const <WKMessageSearchResult>[],
      searchMessagesWithChannel: (_, __, ___) async => <WKMsg>[
        _message(
          channelId: 'group-1',
          channelName: 'Design Group',
          messageSeq: 1,
          orderSeq: 1001,
          fromUid: 'u1',
          fromName: 'Alex',
          previewText: 'first',
        ),
        _message(
          channelId: 'group-1',
          channelName: 'Design Group',
          messageSeq: 2,
          orderSeq: 1002,
          fromUid: 'u2',
          fromName: 'Blair',
          previewText: 'second',
        ),
        _message(
          channelId: 'group-1',
          channelName: 'Design Group',
          messageSeq: 3,
          orderSeq: 1003,
          fromUid: 'u3',
          fromName: 'Casey',
          previewText: 'third',
        ),
      ],
    );

    final firstPage = await service.searchMessages(
      channelId: 'group-1',
      channelType: WKChannelType.group,
      keyword: 'result',
      page: 1,
      limit: 2,
    );
    final secondPage = await service.searchMessages(
      channelId: 'group-1',
      channelType: WKChannelType.group,
      keyword: 'result',
      page: 2,
      limit: 2,
    );

    expect(firstPage, hasLength(2));
    expect(firstPage.first.messageSeq, 1);
    expect(firstPage.last.messageSeq, 2);
    expect(secondPage, hasLength(1));
    expect(secondPage.single.messageSeq, 3);
    expect(secondPage.single.previewText, 'third');
  });

  test(
    'searchMessages uses robot card display text for per-message previews',
    () async {
      final service = LocalSearchService(
        searchChannels: (_) async => const <WKChannelSearchResult>[],
        searchFollowedUsers: (_, __, ___) async => const <WKChannel>[],
        searchGlobalMessages: (_) async => const <WKMessageSearchResult>[],
        searchMessagesWithChannel: (_, __, ___) async => <WKMsg>[
          WKMsg()
            ..channelID = 'group-1'
            ..channelType = WKChannelType.group
            ..messageSeq = 501
            ..orderSeq = 1501
            ..timestamp = 1712123999
            ..fromUID = 'u_robot'
            ..contentType = MsgContentType.robotCard
            ..messageID = 'robot-card-501'
            ..messageContent = (WKRobotCardContent()
              ..robotName = 'Feishu Robot'
              ..title = 'Message Notice'
              ..body = 'feishu-link-test-001'
              ..plainText = 'Message Notice feishu-link-test-001'),
        ],
      );

      final hits = await service.searchMessages(
        channelId: 'group-1',
        channelType: WKChannelType.group,
        keyword: 'feishu',
        page: 1,
        limit: 20,
      );

      expect(hits, hasLength(1));
      expect(hits.single.previewText, 'Message Notice feishu-link-test-001');
    },
  );
}

WKChannel _personalChannel({
  required String channelId,
  required String channelName,
  String channelRemark = '',
}) {
  final channel = WKChannel(channelId, WKChannelType.personal);
  channel.channelName = channelName;
  channel.channelRemark = channelRemark;
  channel.follow = 1;
  return channel;
}

WKChannelSearchResult _groupResult({
  required String channelId,
  required String channelName,
  String containMemberName = '',
}) {
  final result = WKChannelSearchResult();
  final channel = WKChannel(channelId, WKChannelType.group);
  channel.channelName = channelName;
  result.channel = channel;
  result.containMemberName = containMemberName;
  return result;
}

WKMessageSearchResult _messageAggregate({
  required String channelId,
  required String channelName,
  required String searchableWord,
  required int messageCount,
}) {
  final aggregate = WKMessageSearchResult();
  final channel = WKChannel(channelId, WKChannelType.group);
  channel.channelName = channelName;
  aggregate.channel = channel;
  aggregate.searchableWord = searchableWord;
  aggregate.messageCount = messageCount;
  return aggregate;
}

WKMsg _message({
  required String channelId,
  required String channelName,
  required int messageSeq,
  required int orderSeq,
  required String fromUid,
  required String fromName,
  required String previewText,
}) {
  final msg = WKMsg();
  msg.channelID = channelId;
  msg.channelType = WKChannelType.group;
  msg.messageSeq = messageSeq;
  msg.orderSeq = orderSeq;
  msg.timestamp = 1712123456 + messageSeq;
  msg.contentType = WkMessageContentType.text;
  msg.fromUID = fromUid;
  msg.searchableWord = previewText;
  msg.messageID = 'msg-$messageSeq';
  msg.clientMsgNO = 'client-$messageSeq';

  final group = WKChannel(channelId, WKChannelType.group);
  group.channelName = channelName;
  msg.setChannelInfo(group);

  final sender = WKChannel(fromUid, WKChannelType.personal);
  sender.channelName = fromName;
  msg.setFrom(sender);

  final content = WKTextContent(previewText);
  msg.messageContent = content;
  return msg;
}
