import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_flame_message_runtime.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatFlameMessageRuntime', () {
    test('markViewed updates viewedAt and deletes flame message after ttl', () {
      fakeAsync((async) {
        final store = _FakeChatFlameMessageStore();
        final message = WKMsg()
          ..clientMsgNO = 'client-flame-text'
          ..messageID = 'm-flame-text'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 10,
          };
        store.seed(message);
        final runtime = ChatFlameMessageRuntime(
          store: store,
          now: () => DateTime.fromMillisecondsSinceEpoch(1_000),
        );

        expect(message.viewed, 0);
        expect(message.viewedAt, 0);

        runtime.markViewed(message);
        async.flushMicrotasks();

        expect(message.viewed, 1);
        expect(message.viewedAt, 1_000);
        expect(store.updatedViewedAt[message.clientMsgNO], 1_000);

        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();

        expect(store.findByClientMsgNo(message.clientMsgNO), isNull);
      });
    });

    test('markVisibleMessages only marks non-media flame messages as viewed', () {
      fakeAsync((async) {
        final store = _FakeChatFlameMessageStore();
        final textMessage = WKMsg()
          ..clientMsgNO = 'client-visible-flame-text'
          ..messageID = 'm-visible-flame-text'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 20,
          };
        final imageMessage = WKMsg()
          ..clientMsgNO = 'client-visible-flame-image'
          ..messageID = 'm-visible-flame-image'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.image
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 20,
          };
        store
          ..seed(textMessage)
          ..seed(imageMessage);
        final runtime = ChatFlameMessageRuntime(
          store: store,
          now: () => DateTime.fromMillisecondsSinceEpoch(2_000),
        );

        runtime.markVisibleMessages(<WKMsg>[textMessage, imageMessage]);
        async.flushMicrotasks();

        expect(textMessage.viewed, 1);
        expect(textMessage.viewedAt, 2_000);
        expect(imageMessage.viewed, 0);
        expect(imageMessage.viewedAt, 0);
      });
    });

    test('sweepViewedMessages deletes zero-second and expired flame messages', () {
      fakeAsync((async) {
        final store = _FakeChatFlameMessageStore();
        final zeroSecondMessage = WKMsg()
          ..clientMsgNO = 'client-flame-zero'
          ..messageID = 'm-flame-zero'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..viewed = 1
          ..viewedAt = 9_000
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 0,
          };
        final expiredMessage = WKMsg()
          ..clientMsgNO = 'client-flame-expired'
          ..messageID = 'm-flame-expired'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..viewed = 1
          ..viewedAt = 1_000
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 10,
          };
        final activeMessage = WKMsg()
          ..clientMsgNO = 'client-flame-active'
          ..messageID = 'm-flame-active'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..viewed = 1
          ..viewedAt = 6_000
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 10,
          };
        final unviewedMessage = WKMsg()
          ..clientMsgNO = 'client-flame-unviewed'
          ..messageID = 'm-flame-unviewed'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..viewed = 0
          ..viewedAt = 0
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 10,
          };
        store
          ..seed(zeroSecondMessage)
          ..seed(expiredMessage)
          ..seed(activeMessage)
          ..seed(unviewedMessage);
        final runtime = ChatFlameMessageRuntime(
          store: store,
          now: () => DateTime.fromMillisecondsSinceEpoch(12_000),
        );

        runtime.sweepViewedMessages();
        async.flushMicrotasks();

        expect(store.findByClientMsgNo(zeroSecondMessage.clientMsgNO), isNull);
        expect(store.findByClientMsgNo(expiredMessage.clientMsgNO), isNull);
        expect(
          store.findByClientMsgNo(activeMessage.clientMsgNO),
          same(activeMessage),
        );
        expect(
          store.findByClientMsgNo(unviewedMessage.clientMsgNO),
          same(unviewedMessage),
        );
      });
    });

    test('markViewed honors ttl override for flame voice playback', () {
      fakeAsync((async) {
        final store = _FakeChatFlameMessageStore();
        final message = WKMsg()
          ..clientMsgNO = 'client-flame-voice'
          ..messageID = 'm-flame-voice'
          ..channelID = 'u_flame'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.voice
          ..localExtraMap = <String, dynamic>{
            'flame': 1,
            'flame_second': 5,
          };
        store.seed(message);
        final runtime = ChatFlameMessageRuntime(
          store: store,
          now: () => DateTime.fromMillisecondsSinceEpoch(3_000),
        );

        runtime.markViewed(message, ttlSecondsOverride: 8);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(store.findByClientMsgNo(message.clientMsgNO), same(message));

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(store.findByClientMsgNo(message.clientMsgNO), isNull);
      });
    });
  });
}

class _FakeChatFlameMessageStore implements ChatFlameMessageStore {
  final Map<String, WKMsg> _messages = <String, WKMsg>{};
  final Map<String, int> updatedViewedAt = <String, int>{};

  void seed(WKMsg message) {
    _messages[message.clientMsgNO] = message;
  }

  @override
  Future<void> deleteWithClientMsgNo(String clientMsgNo) async {
    _messages.remove(clientMsgNo);
  }

  @override
  WKMsg? findByClientMsgNo(String clientMsgNo) {
    return _messages[clientMsgNo];
  }

  @override
  Future<List<WKMsg>> getWithFlame() async {
    return _messages.values
        .where((message) => isFlameMessage(message))
        .toList(growable: false);
  }

  @override
  Future<void> updateViewedAt(String clientMsgNo, int viewedAtMs) async {
    updatedViewedAt[clientMsgNo] = viewedAtMs;
    final message = _messages[clientMsgNo];
    if (message == null) {
      return;
    }
    message
      ..viewed = 1
      ..viewedAt = viewedAtMs;
  }
}
