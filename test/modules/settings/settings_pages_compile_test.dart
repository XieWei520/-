import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/modules/settings/account_security_page.dart';
import 'package:wukong_im_app/modules/settings/blacklist_page.dart';
import 'package:wukong_im_app/modules/settings/device_management_page.dart';
import 'package:wukong_im_app/modules/settings/device_list_page.dart';
import 'package:wukong_im_app/modules/settings/notification_settings_page.dart';
import 'package:wukong_im_app/modules/settings/privacy_settings_page.dart';
import 'package:wukong_im_app/modules/user/user_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/privacy_settings_page.dart'
    as legacy_settings;

void main() {
  test('settings detail pages compile from modules/settings owner', () {
    expect(const PrivacySettingsPage(), isA<Widget>());
    expect(const NotificationSettingsPage(), isA<Widget>());
    expect(const BlacklistPage(), isA<Widget>());
    expect(const AccountSecurityPage(), isA<Widget>());
    expect(const DeviceListPage(), isA<Widget>());
  });

  test('settings wrappers and active consumer boundary compile', () {
    expect(const DeviceManagementPage(), isA<Widget>());
    expect(const legacy_settings.PrivacySettingsPage(), isA<Widget>());
    expect(const UserPage(), isA<Widget>());
  });
}
