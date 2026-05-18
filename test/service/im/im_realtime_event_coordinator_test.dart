import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';
import 'package:wukong_im_app/service/im/im_realtime_event_coordinator.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() {
    ConversationActivityRegistry.instance.clearAll();
  });

  tearDown(() {
    ConversationActivityRegistry.instance.clearAll();
  });

  test('applies conversation patch and forwards every session frame', () async {
    final patches = <ConversationPatch>[];
    final forwardedFrames = <SessionEventFrame>[];
    final coordinator = ImRealtimeEventCoordinator(
      applyConversationPatch: patches.add,
      handleCallSessionFrame: (frame) async {
        forwardedFrames.add(frame);
      },
    );
    final frame = SessionEventFrame(
      eventId: 'evt-1',
      userSeq: 1,
      serverTs: 100,
      kind: 'conversation.updated',
      aggregateId: '${WKChannelType.personal}:u_alice',
      payload: const <String, dynamic>{
        'unread_count': 3,
        'last_message_digest': 'hello',
        'sort_timestamp': 123,
      },
    );

    await coordinator.handleSessionFrame(frame);

    expect(forwardedFrames, <SessionEventFrame>[frame]);
    expect(patches, hasLength(1));
    expect(patches.single.channelId, 'u_alice');
    expect(patches.single.channelType, WKChannelType.personal);
    expect(patches.single.unreadCount, 3);
    expect(patches.single.lastMessageDigest, 'hello');
    expect(patches.single.sortTimestamp, 123);
  });

  test('forwards non-conversation frames without applying patches', () async {
    final patches = <ConversationPatch>[];
    final forwardedKinds = <String>[];
    final coordinator = ImRealtimeEventCoordinator(
      applyConversationPatch: patches.add,
      handleCallSessionFrame: (frame) async {
        forwardedKinds.add(frame.kind);
      },
    );

    await coordinator.handleSessionFrame(
      const SessionEventFrame(
        eventId: 'evt-2',
        userSeq: 2,
        serverTs: 101,
        kind: 'call.invited',
        aggregateId: 'call-room-1',
        payload: <String, dynamic>{},
      ),
    );

    expect(patches, isEmpty);
    expect(forwardedKinds, <String>['call.invited']);
  });

  test('reconciles recovered calling states and clears stale calls', () {
    final registry = ConversationActivityRegistry.instance;
    final coordinator = ImRealtimeEventCoordinator(
      applyConversationPatch: (_) {},
      handleCallSessionFrame: (_) async {},
    );

    registry.setCallingState('stale_group', WKChannelType.group, true);
    final activeKeys = coordinator.applyRecoveredCallingStates(<WKChannelState>[
      WKChannelState()
        ..channelID = 'group_01'
        ..channelType = WKChannelType.group
        ..calling = 1,
      WKChannelState()
        ..channelID = 'personal_01'
        ..channelType = WKChannelType.personal
        ..calling = 0,
    ]);

    expect(activeKeys, <String>{
      ConversationActivityRegistry.conversationKey(
        'group_01',
        WKChannelType.group,
      ),
    });
    expect(
      registry.getState('group_01', WKChannelType.group).isCalling,
      isTrue,
    );
    expect(
      registry.getState('personal_01', WKChannelType.personal).isCalling,
      isFalse,
    );
    expect(
      registry.getState('stale_group', WKChannelType.group).isCalling,
      isFalse,
    );
  });
}
