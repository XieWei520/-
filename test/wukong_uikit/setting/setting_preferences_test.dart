import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/chat_background_option.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  group('WKSettingPreferences.resolvePreferredLocale', () {
    test(
      'returns null for follow-system mode so MaterialApp follows platform locale',
      () {
        expect(
          WKSettingPreferences.resolvePreferredLocale(
            WKLanguageSetting.followSystem,
          ),
          isNull,
        );
      },
    );

    test('keeps explicit English selection', () {
      expect(
        WKSettingPreferences.resolvePreferredLocale(WKLanguageSetting.english),
        const Locale('en', 'US'),
      );
    });

    test('keeps explicit simplified Chinese selection', () {
      expect(
        WKSettingPreferences.resolvePreferredLocale(
          WKLanguageSetting.simplifiedChinese,
        ),
        const Locale('zh', 'CN'),
      );
    });
  });

  group('WKSettingPreferences font scale', () {
    test(
      'setFontScale persists the value and notifies appearance listeners',
      () async {
        var notifications = 0;
        void listener() {
          notifications += 1;
        }

        WKSettingPreferences.appearanceChanges.addListener(listener);
        addTearDown(() {
          WKSettingPreferences.appearanceChanges.removeListener(listener);
        });

        await WKSettingPreferences.setFontScale(1.25);

        expect(WKSettingPreferences.getFontScale(), 1.25);
        expect(notifications, 1);
      },
    );
  });

  group('WKSettingPreferences chat background', () {
    test(
      'setChatBackgroundStyle clears selected server background and notifies listeners',
      () async {
        var notifications = 0;
        void listener() {
          notifications += 1;
        }

        WKSettingPreferences.appearanceChanges.addListener(listener);
        addTearDown(() {
          WKSettingPreferences.appearanceChanges.removeListener(listener);
        });

        await WKSettingPreferences.setSelectedChatBackground(
          const ChatBackgroundOption(
            cover: 'file/preview/common/chatbg/default/1_s.jpg',
            url: 'file/preview/common/chatbg/default/1_b.svg',
            isSvg: true,
            lightColors: <String>['a6B0CDEB', 'a69FB0EA'],
          ),
        );
        expect(
          WKSettingPreferences.getSelectedChatBackground()?.url,
          'file/preview/common/chatbg/default/1_b.svg',
        );

        await WKSettingPreferences.setChatBackgroundStyle(
          WKChatBackgroundStyle.paper,
        );

        expect(WKSettingPreferences.getSelectedChatBackground(), isNull);
        expect(
          WKSettingPreferences.getChatBackgroundStyle(),
          WKChatBackgroundStyle.paper,
        );
        expect(notifications, 2);
      },
    );

    test(
      'channel-scoped chat background overrides global selection and can be cleared back to global',
      () async {
        const globalOption = ChatBackgroundOption(
          cover: 'file/preview/common/chatbg/default/1_s.jpg',
          url: 'file/preview/common/chatbg/default/1_b.svg',
          isSvg: true,
          lightColors: <String>['a6B0CDEB', 'a69FB0EA'],
        );
        const scopedOption = ChatBackgroundOption(
          cover: 'file/preview/common/chatbg/default/14_s.jpg',
          url: 'file/preview/common/chatbg/default/14_b.jpg',
          isSvg: false,
        );

        await WKSettingPreferences.setSelectedChatBackground(globalOption);
        await WKSettingPreferences.setSelectedChatBackground(
          scopedOption,
          channelId: 'u_chat_bg',
          channelType: 1,
        );

        expect(
          WKSettingPreferences.getSelectedChatBackground(
            channelId: 'u_chat_bg',
            channelType: 1,
          )?.url,
          scopedOption.url,
        );
        expect(
          WKSettingPreferences.getSelectedChatBackground()?.url,
          globalOption.url,
        );

        await WKSettingPreferences.clearChatBackgroundOverride(
          channelId: 'u_chat_bg',
          channelType: 1,
        );

        expect(
          WKSettingPreferences.getSelectedChatBackground(
            channelId: 'u_chat_bg',
            channelType: 1,
          )?.url,
          globalOption.url,
        );
        expect(
          WKSettingPreferences.hasChatBackgroundOverride(
            channelId: 'u_chat_bg',
            channelType: 1,
          ),
          isFalse,
        );
      },
    );

    test(
      'channel-scoped local style suppresses the global server background selection',
      () async {
        const globalOption = ChatBackgroundOption(
          cover: 'file/preview/common/chatbg/default/1_s.jpg',
          url: 'file/preview/common/chatbg/default/1_b.svg',
          isSvg: true,
          lightColors: <String>['a6B0CDEB', 'a69FB0EA'],
        );

        await WKSettingPreferences.setSelectedChatBackground(globalOption);
        await WKSettingPreferences.setChatBackgroundStyle(
          WKChatBackgroundStyle.paper,
          channelId: 'u_chat_bg',
          channelType: 1,
        );

        expect(
          WKSettingPreferences.getSelectedChatBackground(
            channelId: 'u_chat_bg',
            channelType: 1,
          ),
          isNull,
        );
        expect(
          WKSettingPreferences.getChatBackgroundStyle(
            channelId: 'u_chat_bg',
            channelType: 1,
          ),
          WKChatBackgroundStyle.paper,
        );
      },
    );
  });
}
