import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_typing_gateway.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('Android typing report parity', () {
    test('group typing sends only for active non-deleted members', () async {
      final calls = <String>[];
      final gateway = WkImChatTypingGateway(
        currentUidReader: () => 'u_self',
        memberLoader: ({
          required String channelId,
          required int channelType,
          required String uid,
        }) async {
          return WKChannelMember()
            ..channelID = channelId
            ..channelType = channelType
            ..memberUID = uid
            ..isDeleted = 0
            ..status = 1;
        },
        sendTyping: ({required String channelId, required int channelType}) async {
          calls.add('$channelId:$channelType');
        },
      );

      await gateway.sendIfAllowed(
        channelId: 'g_active',
        channelType: WKChannelType.group,
      );

      expect(calls, const <String>['g_active:2']);
    });

    test('group typing skips deleted or inactive members', () async {
      final calls = <String>[];
      final gateway = WkImChatTypingGateway(
        currentUidReader: () => 'u_self',
        memberLoader: ({
          required String channelId,
          required int channelType,
          required String uid,
        }) async {
          return WKChannelMember()
            ..channelID = channelId
            ..channelType = channelType
            ..memberUID = uid
            ..isDeleted = 1
            ..status = 0;
        },
        sendTyping: ({required String channelId, required int channelType}) async {
          calls.add('$channelId:$channelType');
        },
      );

      await gateway.sendIfAllowed(
        channelId: 'g_blocked',
        channelType: WKChannelType.group,
      );

      expect(calls, isEmpty);
    });

    test('personal typing skips beDeleted or beBlacklist channels', () async {
      final calls = <String>[];
      final blockedGateway = WkImChatTypingGateway(
        channelLoader: ({
          required String channelId,
          required int channelType,
        }) async {
          return WKChannel(channelId, channelType)
            ..localExtra = <String, dynamic>{
              'beDeleted': 1,
              'beBlacklist': 1,
            };
        },
        sendTyping: ({required String channelId, required int channelType}) async {
          calls.add('$channelId:$channelType');
        },
      );

      await blockedGateway.sendIfAllowed(
        channelId: 'u_blocked',
        channelType: WKChannelType.personal,
      );

      expect(calls, isEmpty);
    });

    test('personal typing sends when peer state allows it', () async {
      final calls = <String>[];
      final gateway = WkImChatTypingGateway(
        channelLoader: ({
          required String channelId,
          required int channelType,
        }) async {
          return WKChannel(channelId, channelType)
            ..localExtra = <String, dynamic>{'beDeleted': 0, 'beBlacklist': 0};
        },
        sendTyping: ({required String channelId, required int channelType}) async {
          calls.add('$channelId:$channelType');
        },
      );

      await gateway.sendIfAllowed(
        channelId: 'u_allowed',
        channelType: WKChannelType.personal,
      );

      expect(calls, const <String>['u_allowed:1']);
    });
  });
}
