import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/forward_message_page.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

void main() {
  testWidgets('forward chooser uses Android title and selection-aware submit', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway(
      targets: const <ForwardTarget>[
        ForwardTarget(
          channelId: 'g_product',
          channelType: 2,
          name: 'Product Team',
          subtitle: 'Group chat',
          isGroup: true,
        ),
        ForwardTarget(
          channelId: 'u_alice',
          channelType: 1,
          name: 'Alice',
          subtitle: 'Direct chat',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForwardMessagePage(
          payloads: const <ForwardPayload>[
            ForwardPayload(clientMsgNo: 'client-1', content: null),
          ],
          channelId: 'source_chat',
          channelType: 1,
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择会话'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '确定'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey<String>('forward-submit')),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('forward-target-2:g_product')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, '确定(1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('forward-submit')));
    await tester.pumpAndSettle();

    expect(gateway.sentPayloads, hasLength(1));
    expect(gateway.sentTargets.single.channelId, 'g_product');
  });

  testWidgets('forward chooser shows empty state for unmatched search', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway(
      targets: const <ForwardTarget>[
        ForwardTarget(
          channelId: 'u_alice',
          channelType: 1,
          name: 'Alice',
          subtitle: 'Direct chat',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForwardMessagePage(
          payloads: const <ForwardPayload>[
            ForwardPayload(clientMsgNo: 'client-1', content: null),
          ],
          channelId: 'source_chat',
          channelType: 1,
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('forward-search-field')),
      'nobody',
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无会话'), findsOneWidget);
  });
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  _FakeChatSceneGateway({required this.targets});

  final List<ForwardTarget> targets;
  List<ForwardPayload> sentPayloads = const <ForwardPayload>[];
  List<ForwardTarget> sentTargets = const <ForwardTarget>[];

  @override
  Future<void> addFavorite(WKMsg message) {
    throw UnimplementedError();
  }

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) {
    throw UnimplementedError();
  }

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return targets;
  }

  @override
  Future<void> recallMessage(WKMsg message) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {
    sentPayloads = List<ForwardPayload>.from(payloads, growable: false);
    sentTargets = List<ForwardTarget>.from(targets, growable: false);
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) {
    throw UnimplementedError();
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }
}
