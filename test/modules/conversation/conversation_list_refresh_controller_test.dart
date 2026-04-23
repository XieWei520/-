import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_activity_registry.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_refresh_controller.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  group('conversation list refresh controller', () {
    test('marks only the matching conversation dirty for keyed updates', () {
      final controller = ConversationListRefreshController(attachSources: false);
      addTearDown(controller.dispose);

      final selfBefore = controller.state.versionFor(
        'u_self',
        WKChannelType.personal,
      );
      final otherBefore = controller.state.versionFor(
        'u_other',
        WKChannelType.personal,
      );

      controller.markConversationChanged('u_self', WKChannelType.personal);

      expect(
        controller.state.versionFor('u_self', WKChannelType.personal),
        isNot(selfBefore),
      );
      expect(
        controller.state.versionFor('u_other', WKChannelType.personal),
        otherBefore,
      );
    });

    test('markAllChanged invalidates every conversation snapshot', () {
      final controller = ConversationListRefreshController(attachSources: false);
      addTearDown(controller.dispose);

      final selfBefore = controller.state.versionFor(
        'u_self',
        WKChannelType.personal,
      );
      final otherBefore = controller.state.versionFor(
        'u_other',
        WKChannelType.personal,
      );

      controller.markAllChanged();

      expect(
        controller.state.versionFor('u_self', WKChannelType.personal),
        isNot(selfBefore),
      );
      expect(
        controller.state.versionFor('u_other', WKChannelType.personal),
        isNot(otherBefore),
      );
    });

    test('markConversationDirty invalidates the matching conversation key', () {
      final controller = ConversationListRefreshController(attachSources: false);
      addTearDown(controller.dispose);

      final before = controller.state.versionFor(
        'u_self',
        WKChannelType.personal,
      );

      controller.markConversationDirty(
        ConversationActivityRegistry.conversationKey(
          'u_self',
          WKChannelType.personal,
        ),
      );

      expect(
        controller.state.versionFor('u_self', WKChannelType.personal),
        isNot(before),
      );
    });

    test('message refresh invalidates the matching conversation snapshot', () {
      final controller = ConversationListRefreshController();
      addTearDown(controller.dispose);

      final before = controller.state.versionFor(
        'u_self',
        WKChannelType.personal,
      );

      final message = WKMsg()
        ..channelID = 'u_self'
        ..channelType = WKChannelType.personal;

      WKIM.shared.messageManager.setRefreshMsg(message);

      expect(
        controller.state.versionFor('u_self', WKChannelType.personal),
        isNot(before),
      );
    });
  });
}
