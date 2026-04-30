import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/wukong_base/views/mention_suggestion.dart';

void main() {
  testWidgets('mention suggestions render remote avatars through WKAvatar', (
    tester,
  ) async {
    const avatarUrl = 'https://cdn.example.com/avatar/alice.png';
    WKAvatar.setBytesLoaderForTesting((url) async => null);
    addTearDown(() => WKAvatar.setBytesLoaderForTesting(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentionSuggestionOverlay(
            suggestions: <MentionSuggestion>[
              MentionSuggestion(
                id: 'u_alice',
                name: 'Alice',
                avatar: avatarUrl,
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final avatar = tester.widget<WKAvatar>(find.byType(WKAvatar));
    expect(avatar.url, avatarUrl);
    expect(avatar.name, 'Alice');
    expect(avatar.size, 36);
    expect(find.text('@\u63d0\u53ca'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar && widget.backgroundImage is NetworkImage,
      ),
      findsNothing,
    );
  });
}
