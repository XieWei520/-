import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_image_forward_page.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return ProviderScope(
      child: MaterialApp(locale: const Locale('en'), home: child),
    );
  }

  testWidgets('forward page shows resolved targets and filters by keyword', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        ChatSearchImageForwardPage(
          item: SearchMediaItem(
            hit: const SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 33,
              orderSeq: 33000,
              timestamp: 1710000000,
              contentType: 2,
              fromUid: 'u_alice',
              fromName: 'Alice',
              previewText: '[image]',
              channelName: 'Design',
            ),
            scope: SearchCollectionScope.image,
            sectionKey: '2026-04',
            mediaUrl: 'https://cdn.example.com/image.png',
          ),
          resolveTargets: (_) async => const <ForwardTarget>[
            ForwardTarget(
              channelId: 'u_bob',
              channelType: 1,
              name: 'Bobby',
              subtitle: 'Direct chat',
            ),
            ForwardTarget(
              channelId: 'g2002',
              channelType: 2,
              name: 'Product Team',
              subtitle: 'Group chat',
              isGroup: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-forward-search-field')),
      findsOneWidget,
    );
    expect(find.text('Bobby'), findsOneWidget);
    expect(find.text('Product Team'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('search-forward-avatar-1:u_bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('search-forward-avatar-2:g2002')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('search-forward-search-field')),
      'bob',
    );
    await tester.pumpAndSettle();

    expect(find.text('Bobby'), findsOneWidget);
    expect(find.text('Product Team'), findsNothing);
  });

  testWidgets('forward page supports multi-select and confirm send', (
    tester,
  ) async {
    List<ForwardTarget> submittedTargets = const <ForwardTarget>[];

    await tester.pumpWidget(
      wrapWithApp(
        ChatSearchImageForwardPage(
          item: SearchMediaItem(
            hit: const SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 33,
              orderSeq: 33000,
              timestamp: 1710000000,
              contentType: 2,
              fromUid: 'u_alice',
              fromName: 'Alice',
              previewText: '[image]',
              channelName: 'Design',
            ),
            scope: SearchCollectionScope.image,
            sectionKey: '2026-04',
            mediaUrl: 'https://cdn.example.com/image.png',
          ),
          resolveTargets: (_) async => const <ForwardTarget>[
            ForwardTarget(
              channelId: 'u_bob',
              channelType: 1,
              name: 'Bobby',
              subtitle: 'Direct chat',
            ),
            ForwardTarget(
              channelId: 'g2002',
              channelType: 2,
              name: 'Product Team',
              subtitle: 'Group chat',
              isGroup: true,
            ),
          ],
          onSubmitTargets: (targets, item) async {
            submittedTargets = targets;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('search-forward-confirm-button')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-target-1:u_bob')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-target-2:g2002')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-forward-selected-1:u_bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('search-forward-selected-2:g2002')),
      findsOneWidget,
    );
    final enabledButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('search-forward-confirm-button')),
    );
    expect(enabledButton.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(submittedTargets, hasLength(2));
    expect(
      submittedTargets.map((target) => target.channelId),
      containsAll(<String>['u_bob', 'g2002']),
    );
  });

  testWidgets('forward page sends selected images with 30 day retention', (
    tester,
  ) async {
    final sends = <_SearchForwardSendCall>[];

    await tester.pumpWidget(
      wrapWithApp(
        ChatSearchImageForwardPage(
          item: SearchMediaItem(
            hit: const SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 33,
              orderSeq: 33000,
              timestamp: 1710000000,
              contentType: 2,
              fromUid: 'u_alice',
              fromName: 'Alice',
              previewText: '[image]',
              channelName: 'Design',
            ),
            scope: SearchCollectionScope.image,
            sectionKey: '2026-04',
            mediaUrl: 'https://cdn.example.com/image.png',
          ),
          resolveTargets: (_) async => const <ForwardTarget>[
            ForwardTarget(
              channelId: 'u_bob',
              channelType: 1,
              name: 'Bobby',
              subtitle: 'Direct chat',
            ),
            ForwardTarget(
              channelId: 'g2002',
              channelType: 2,
              name: 'Product Team',
              subtitle: 'Group chat',
              isGroup: true,
            ),
          ],
          sendMessage: (content, channel, options) async {
            sends.add(_SearchForwardSendCall(content, channel, options.expire));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-target-1:u_bob')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-target-2:g2002')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('search-forward-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(sends, hasLength(2));
    expect(
      sends.map((send) => send.channel.channelID),
      <String>['u_bob', 'g2002'],
    );
    expect(
      sends.map((send) => send.expire),
      everyElement(defaultChatMessageRetentionSeconds),
    );
  });
}

class _SearchForwardSendCall {
  const _SearchForwardSendCall(this.content, this.channel, this.expire);

  final WKMessageContent content;
  final WKChannel channel;
  final int? expire;
}
