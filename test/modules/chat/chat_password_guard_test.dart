import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/chat_password_runtime.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

void main() {
  testWidgets(
    'protected chats wait for password unlock before showing ChatPageShell',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'u_secure', chatPwd: 'stored-hash'),
                ),
              ),
            ),
            messageListProvider.overrideWith(
              (ref, session) => _EmptyMessageListNotifier(
                session.channelId,
                session.channelType,
              ),
            ),
            chatPasswordRuntimeProvider.overrideWithValue(
              ChatPasswordRuntime(
                loadChannel: (channelId, channelType) async {
                  return WKChannel(channelId, channelType)
                    ..remoteExtraMap = <String, dynamic>{'chat_pwd_on': 1}
                    ..localExtra = <String, dynamic>{'chat_pwd_on': 1};
                },
                clearChannelMessages: (_, __) async {},
              ),
            ),
            chatSceneGatewayProvider.overrideWith(
              (ref, session) => _CompileSafeChatSceneGateway(),
            ),
          ],
          child: const MaterialApp(
            home: ChatPage(
              channelId: 'u_secure',
              channelType: 1,
              channelName: 'Secure Chat',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(ChatPageShell), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType)
    : super(autoLoad: false);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}

class _CompileSafeChatSceneGateway extends ChatSceneGateway {
  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}
}
