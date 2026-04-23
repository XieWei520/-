import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/modules/chat/chat_details_page.dart';
import 'package:wukong_im_app/modules/settings/notification_settings_page.dart';
import 'package:wukong_im_app/modules/settings/privacy_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/app_modules_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/chat_background_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/error_logs_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/about_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/theme_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/language_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/font_size_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/third_party_sharing_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_info_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';

void main() {
  test('profile and settings pages compile', () {
    expect(
      const ChatDetailsPage(
        channelId: 'u_demo',
        channelType: 1,
        channelName: 'Demo',
      ),
      isA<Widget>(),
    );
    expect(const SettingPage(), isA<Widget>());
    expect(const ThemeSettingsPage(), isA<Widget>());
    expect(const LanguageSettingsPage(), isA<Widget>());
    expect(const FontSizeSettingsPage(), isA<Widget>());
    expect(const ChatBackgroundSettingsPage(), isA<Widget>());
    expect(AppModulesPage(), isA<Widget>());
    expect(const ThirdPartySharingPage(), isA<Widget>());
    expect(const ErrorLogsPage(), isA<Widget>());
    expect(const AboutPage(), isA<Widget>());
    expect(const MyInfoPage(), isA<Widget>());
    expect(const UserDetailPage(uid: 'u_demo'), isA<Widget>());
    expect(const NotificationSettingsPage(), isA<Widget>());
    expect(const PrivacySettingsPage(), isA<Widget>());
  });
}
