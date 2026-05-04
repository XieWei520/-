import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_action_capability_policy.dart';
import 'package:wukong_im_app/modules/chat/chat_action_definition.dart';

void main() {
  test('desktop personal session exposes exact ordered action matrix', () {
    final policy = ChatActionCapabilityPolicy();
    final actions = policy.resolve(
      const ChatActionCapabilityContext(
        isGroup: false,
        isMobile: false,
        isDesktop: true,
        isWeb: false,
      ),
    );

    expect(
      actions.map((item) => item.id).toList(growable: false),
      <ChatActionId>[
        ChatActionId.chooseImage,
        ChatActionId.chooseFile,
        ChatActionId.sendLocation,
        ChatActionId.chooseCard,
        ChatActionId.composeRichText,
        ChatActionId.audioCall,
        ChatActionId.videoCall,
      ],
    );
  });

  test('mobile group session exposes exact ordered action matrix', () {
    final policy = ChatActionCapabilityPolicy();
    final actions = policy.resolve(
      const ChatActionCapabilityContext(
        isGroup: true,
        isMobile: true,
        isDesktop: false,
        isWeb: false,
      ),
    );

    expect(
      actions.map((item) => item.id).toList(growable: false),
      <ChatActionId>[
        ChatActionId.chooseImage,
        ChatActionId.captureImage,
        ChatActionId.chooseFile,
        ChatActionId.sendLocation,
        ChatActionId.chooseCard,
        ChatActionId.composeRichText,
        ChatActionId.groupCall,
      ],
    );
  });

  test('platform flags must be mutually exclusive and exactly one true', () {
    expect(
      () => ChatActionCapabilityContext(
        isGroup: false,
        isMobile: true,
        isDesktop: true,
        isWeb: false,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ChatActionCapabilityContext(
        isGroup: false,
        isMobile: false,
        isDesktop: false,
        isWeb: false,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ChatActionCapabilityContext(
        isGroup: false,
        isMobile: true,
        isDesktop: false,
        isWeb: true,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
