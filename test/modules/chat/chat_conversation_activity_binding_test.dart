import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_activity_binding.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  final registry = ConversationActivityRegistry.instance;

  setUp(registry.clearAll);
  tearDown(registry.clearAll);

  test('bind reads current state and notifies listener on updates', () {
    registry.setCallingState(
      'group_01',
      WKChannelType.group,
      true,
      callRoomName: 'room_01',
    );
    final states = <ConversationActivityState>[];
    final binding = ChatConversationActivityBinding(
      registry: registry,
      onChanged: states.add,
    );

    final initialState = binding.bind(
      channelId: 'group_01',
      channelType: WKChannelType.group,
    );

    expect(initialState.isCalling, isTrue);
    expect(initialState.callRoomName, 'room_01');

    registry.clearTyping('group_01', WKChannelType.group);
    registry.setCallingState('group_01', WKChannelType.group, false);

    expect(states, hasLength(1));
    expect(states.single, ConversationActivityState.empty);
  });

  test('rebind detaches old channel listener', () {
    final states = <ConversationActivityState>[];
    final binding = ChatConversationActivityBinding(
      registry: registry,
      onChanged: states.add,
    );

    binding.bind(channelId: 'u_old', channelType: WKChannelType.personal);
    binding.bind(channelId: 'u_new', channelType: WKChannelType.personal);

    registry.setCallingState('u_old', WKChannelType.personal, true);
    registry.setCallingState('u_new', WKChannelType.personal, true);

    expect(states, hasLength(1));
    expect(states.single.isCalling, isTrue);
  });

  test('dispose removes active listener', () {
    final states = <ConversationActivityState>[];
    final binding = ChatConversationActivityBinding(
      registry: registry,
      onChanged: states.add,
    );

    binding.bind(channelId: 'u_demo', channelType: WKChannelType.personal);
    binding.dispose();
    registry.setCallingState('u_demo', WKChannelType.personal, true);

    expect(states, isEmpty);
  });
}
