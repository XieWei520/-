import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary web UI copy does not expose English action labels', () {
    const filesToCheck = <String>[
      'assets/stickers/sample_pack/manifest.json',
      'lib/modules/auth/presentation/pages/auth_device_sessions_page.dart',
      'lib/modules/auth/presentation/pages/auth_login_page.dart',
      'lib/modules/auth/presentation/pages/auth_login_verification_code_page.dart',
      'lib/modules/auth/presentation/pages/auth_login_verification_page.dart',
      'lib/modules/auth/presentation/pages/auth_profile_completion_page.dart',
      'lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart',
      'lib/modules/auth/presentation/widgets/auth_copy.dart',
      'lib/modules/chat/chat_page.dart',
      'lib/modules/chat/chat_page_shell.dart',
      'lib/modules/chat/expression/chat_expression_registry.dart',
      'lib/modules/chat/widgets/chat_emoji_panel.dart',
      'lib/modules/chat/widgets/chat_expression_panel.dart',
      'lib/modules/conversation/conversation_list_page.dart',
      'lib/modules/conversation/widgets/conversation_action_sheet.dart',
      'lib/modules/home/home_shell_page.dart',
      'lib/modules/home/home_top_menu_slot_assembly.dart',
      'lib/modules/search/presentation/chat_search_collection_page.dart',
      'lib/modules/search/presentation/chat_search_entry_page.dart',
      'lib/modules/search/presentation/chat_search_image_forward_page.dart',
      'lib/modules/search/presentation/chat_search_member_page.dart',
      'lib/modules/search/presentation/chat_search_results_page.dart',
      'lib/modules/search/presentation/global_search_page.dart',
      'lib/modules/search/presentation/global_search_channel_results_page.dart',
      'lib/modules/search/presentation/widgets/search_menu_grid.dart',
      'lib/modules/settings/settings_strings.dart',
      'lib/modules/user/help_feedback_page.dart',
      'lib/modules/user/user_page.dart',
      'lib/wukong_push/notification_permission_prompt_bridge.dart',
      'lib/widgets/message_bubble.dart',
      'lib/wukong_base/emoji/emoji_manager.dart',
      'lib/wukong_scan/scan_webview_page.dart',
      'lib/wukong_uikit/group/group_blacklist_page.dart',
      'lib/wukong_uikit/group/group_member_picker_page.dart',
    ];
    const forbiddenSnippets = <String>[
      "'Back'",
      "'Cancel'",
      "'Confirm'",
      "'OK'",
      "'Reset'",
      "'Update API'",
      "'Forward'",
      "'Favorite'",
      "'Show in Chat'",
      "'Scan QR Code'",
      "'GIF'",
      "'Recent'",
      "'Smileys'",
      "'Gestures'",
      "'Symbols'",
      "'Delete'",
      "'搜索 GIF'",
      "'\\u641c\\u7d22 GIF'",
      "'GIF \\u52a0",
      "'PC/Web",
      'PC/Web 登录',
      'Web 登录',
      'INFORMATION EQUITY',
      'One unified auth stage across desktop, mobile, and web.',
      '"Android Motion"',
      '"Group"',
      '"Other"',
      '"Reply"',
      '"Typing"',
      '"Voice"',
      "'Retry'",
      "'Chats'",
      "'Contacts'",
      "'Me'",
      "'Create group'",
      "'Add friend'",
      "'Scan'",
      "'Search chat history'",
      "'Mute notifications'",
      "'Delete conversation'",
      "'No data'",
      "'No results'",
      "'Load more failed'",
      "'Favorite unavailable'",
      "'Added to favorites'",
      "'Favorite failed: ",
      "'Search chats'",
      "'No chats available'",
      "'No matches'",
      "'Forward unavailable'",
      "'Search Members'",
      "'Date'",
      "'Image'",
      "'File'",
      "'Link'",
      "'Member'",
      "'Enable notifications'",
      "'Not now'",
      "'Open Settings'",
      "'Link copied'",
      "'Unable to open link'",
      "'Copy link'",
      "'Refresh'",
      "'Open in browser'",
      "'Invalid link'",
      "'Allow'",
      "'Search members'",
      "'Group blacklist'",
    ];

    for (final path in filesToCheck) {
      final source = File(path).readAsStringSync();
      for (final snippet in forbiddenSnippets) {
        expect(
          source,
          isNot(contains(snippet)),
          reason: '$path still contains visible English copy: $snippet',
        );
      }
    }
  });

  test('web build policy keeps locale and emoji assets deterministic', () {
    final appSource = File('lib/app/app.dart').readAsStringSync();
    expect(appSource, contains("locale: const Locale('zh', 'CN')"));
    expect(appSource, isNot(contains("Locale('en', 'US')")));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/emoji/android/default/'));
  });
}
