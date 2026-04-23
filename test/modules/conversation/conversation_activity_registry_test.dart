import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  final registry = ConversationActivityRegistry.instance;

  setUp(() {
    registry.clearAll();
  });

  tearDown(() {
    registry.clearAll();
  });

  group('conversation activity registry', () {
    test('wk_typing uses Android personal typing label', () async {
      final cmd = WKCMD()
        ..cmd = 'wk_typing'
        ..param = <String, dynamic>{
          'channel_id': 'u_target',
          'channel_type': WKChannelType.personal,
          'from_uid': 'u_other',
          'from_name': 'Alice',
        };

      await registry.handleCommand(cmd, currentUid: 'u_self');

      final state = registry.getState('u_target', WKChannelType.personal);
      expect(state.isTyping, isTrue);
      expect(state.typingLabel, '对方正在输入');
    });

    test('wk_typing uses Android group typing label with fallback name lookup', () async {
      final cmd = WKCMD()
        ..cmd = 'wk_typing'
        ..param = <String, dynamic>{
          'channel_id': 'g_001',
          'channel_type': WKChannelType.group,
          'from_uid': 'u_other',
          'from_name': '',
        };

      await registry.handleCommand(
        cmd,
        currentUid: 'u_self',
        channelLookup: (channelId, channelType) async {
          return WKChannel(channelId, channelType)
            ..channelName = 'Alice'
            ..channelRemark = '备注Alice';
        },
      );

      final state = registry.getState('g_001', WKChannelType.group);
      expect(state.isTyping, isTrue);
      expect(state.typingLabel, '备注Alice正在输入');
    });

    test('typing state expires after Android 8 second timeout', () async {
      final cmd = WKCMD()
        ..cmd = 'wk_typing'
        ..param = <String, dynamic>{
          'channel_id': 'u_target',
          'channel_type': WKChannelType.personal,
          'from_uid': 'u_other',
          'from_name': 'Alice',
        };

      await registry.handleCommand(
        cmd,
        currentUid: 'u_self',
        typingDuration: const Duration(milliseconds: 1),
      );

      expect(
        registry.getState('u_target', WKChannelType.personal).isTyping,
        isTrue,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = registry.getState('u_target', WKChannelType.personal);
      expect(state.isTyping, isFalse);
      expect(state.typingLabel, isNull);
    });

    test('sync_channel_state uses Android calling flag rules', () async {
      final cmd = WKCMD()
        ..cmd = 'sync_channel_state'
        ..param = <String, dynamic>{
          'channel_id': 'u_self',
          'channel_type': WKChannelType.personal,
          'from_uid': 'u_other',
          'call_info': <String, dynamic>{
            'calling_participants': <String>['u_other'],
          },
        };

      await registry.handleCommand(cmd, currentUid: 'u_self');

      final state = registry.getState('u_other', WKChannelType.personal);
      expect(state.isCalling, isTrue);
    });

    test('sync_channel_state keeps Android call_info participants for chat ui', () async {
      final cmd = WKCMD()
        ..cmd = 'sync_channel_state'
        ..param = <String, dynamic>{
          'channel_id': 'u_self',
          'channel_type': WKChannelType.personal,
          'from_uid': 'u_other',
          'call_info': <String, dynamic>{
            'room_name': 'room-42',
            'calling_participants': <Map<String, String>>[
              <String, String>{'uid': 'u_other', 'name': 'Alice'},
              <String, String>{'uid': 'u_third', 'name': 'Bob'},
            ],
          },
        };

      await registry.handleCommand(cmd, currentUid: 'u_self');

      final state = registry.getState('u_other', WKChannelType.personal);
      expect(state.isCalling, isTrue);
      expect(state.callRoomName, 'room-42');
      expect(
        state.callingParticipants
            .map((participant) => participant.name)
            .toList(growable: false),
        <String>['Alice', 'Bob'],
      );
    });

    test('local calling state can be set and cleared for a conversation', () {
      registry.setCallingState('u_other', WKChannelType.personal, true);

      expect(
        registry.getState('u_other', WKChannelType.personal).isCalling,
        isTrue,
      );

      registry.setCallingState('u_other', WKChannelType.personal, false);

      expect(
        registry.getState('u_other', WKChannelType.personal).isCalling,
        isFalse,
      );
    });

    test('global listeners receive the changed conversation key', () {
      final keys = <String>[];

      void listener(String key) {
        keys.add(key);
      }

      registry.addGlobalListener(listener);
      addTearDown(() => registry.removeGlobalListener(listener));

      registry.setCallingState('u_other', WKChannelType.personal, true);

      expect(
        keys,
        [
          ConversationActivityRegistry.conversationKey(
            'u_other',
            WKChannelType.personal,
          ),
        ],
      );
    });
  });
}
