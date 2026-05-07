import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/chat_background_option.dart';
import 'package:wukong_im_app/wukong_uikit/setting/chat_background_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  testWidgets('chat background settings saves selected server background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatBackgroundSettingsPage(
          backgroundsLoader: () async => const <ChatBackgroundOption>[
            ChatBackgroundOption(
              cover: 'file/preview/common/chatbg/default/1_s.jpg',
              url: 'file/preview/common/chatbg/default/1_b.svg',
              isSvg: true,
              lightColors: <String>['a6B0CDEB', 'a69FB0EA'],
              darkColors: <String>['a6A4DBFF', 'a6009FDD'],
            ),
            ChatBackgroundOption(
              cover: 'file/preview/common/chatbg/default/14_s.jpg',
              url: 'file/preview/common/chatbg/default/14_b.jpg',
              isSvg: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-background-option-remote-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-background-complete')),
    );
    await tester.pumpAndSettle();

    expect(
      WKSettingPreferences.getSelectedChatBackground()?.url,
      'file/preview/common/chatbg/default/14_b.jpg',
    );
  });
}
