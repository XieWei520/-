import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/file_helper_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/system_team_page.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('file helper page matches Android detail shell', (tester) async {
    var previewCalls = 0;
    var sendCalls = 0;

    await tester.pumpWidget(
      wrapWithApp(
        FileHelperPage(
          onOpenAvatarPreview: (_) {
            previewCalls += 1;
          },
          onSendMessage: () {
            sendCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('\u6587\u4ef6\u4f20\u8f93\u52a9\u624b'), findsOneWidget);
    expect(find.text('\u609f\u7a7aIM\u53f7\uff1a'), findsOneWidget);
    expect(find.text('20000'), findsOneWidget);
    expect(find.text('\u529f\u80fd\u4ecb\u7ecd'), findsOneWidget);
    expect(find.text('\u53d1\u6d88\u606f'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('system_account_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u53d1\u6d88\u606f'));
    await tester.pumpAndSettle();

    expect(previewCalls, 1);
    expect(sendCalls, 1);
  });

  testWidgets('system team page matches Android detail shell', (tester) async {
    await tester.pumpWidget(wrapWithApp(const SystemTeamPage()));
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('\u7cfb\u7edf\u901a\u77e5'), findsOneWidget);
    expect(find.text('\u609f\u7a7aIM\u53f7\uff1a'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('\u529f\u80fd\u4ecb\u7ecd'), findsOneWidget);
    expect(
      find.text('\u609f\u7a7aIM\u56e2\u961f\u5b98\u65b9\u8d26\u53f7'),
      findsOneWidget,
    );
    expect(find.text('\u53d1\u6d88\u606f'), findsOneWidget);
  });
}
