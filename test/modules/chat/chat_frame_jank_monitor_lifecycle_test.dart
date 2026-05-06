import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_frame_jank_monitor.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

void main() {
  testWidgets('ChatPageShell starts and stops chat frame jank monitor', (
    tester,
  ) async {
    final registrar = _FakeFrameTimingRegistrar();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatFrameTimingRegistrarProvider.overrideWithValue(registrar),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          chatSceneGatewayProvider.overrideWith(
            (ref, session) => _CompileSafeChatSceneGateway(),
          ),
        ],
        child: const MaterialApp(
          home: ChatPageShell(channelId: 'u_monitor', channelType: 1),
        ),
      ),
    );

    expect(registrar.addCount, 1);
    expect(registrar.activeCallbackCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(registrar.removeCount, 1);
    expect(registrar.activeCallbackCount, 0);
  });
}

class _FakeFrameTimingRegistrar implements FrameTimingRegistrar {
  final Set<TimingsCallback> _callbacks = <TimingsCallback>{};
  int addCount = 0;
  int removeCount = 0;

  int get activeCallbackCount => _callbacks.length;

  @override
  void addTimingsCallback(TimingsCallback callback) {
    addCount += 1;
    _callbacks.add(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    removeCount += 1;
    _callbacks.remove(callback);
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

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
