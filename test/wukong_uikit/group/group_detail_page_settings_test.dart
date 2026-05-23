import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_dialog.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';

const String _groupNo = 'g_task2';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;
  final imageHttpClient = _FakeHttpClient();
  imageHttpClient.request.response
    ..statusCode = HttpStatus.ok
    ..contentLength = _transparentImage.length
    ..content = <Uint8List>[Uint8List.fromList(_transparentImage)];

  setUpAll(() async {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    HttpOverrides.global = _FakeHttpOverrides(imageHttpClient);
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    HttpOverrides.global = null;
  });

  testWidgets(
    'live Android settings section renders show_nick and advanced switches with server-backed values',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(
          role: 1,
          invite: 1,
          showNick: 0,
          allowViewHistoryMsg: 0,
          joinGroupRemind: 1,
          allowMemberPinnedMessage: 1,
        ),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey<String>('group_setting_show_nick_switch')),
      );
      expect(
        find.byKey(const ValueKey<String>('group_setting_show_nick_switch')),
        findsOneWidget,
      );
      expect(_switchValue(tester, 'group_setting_show_nick_switch'), isFalse);
      await _scrollToFinder(
        tester,
        find.byKey(
          const ValueKey<String>('group_setting_join_group_remind_switch'),
        ),
      );
      expect(
        find.byKey(
          const ValueKey<String>('group_setting_join_group_remind_switch'),
        ),
        findsOneWidget,
      );
      expect(
        _switchValue(tester, 'group_setting_join_group_remind_switch'),
        isTrue,
      );
      await _scrollToFinder(
        tester,
        find.byKey(
          const ValueKey<String>('group_setting_allow_view_history_switch'),
        ),
      );
      expect(
        find.byKey(
          const ValueKey<String>('group_setting_allow_view_history_switch'),
        ),
        findsOneWidget,
      );
      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey<String>('group_setting_invite_mode_switch')),
      );
      expect(
        find.byKey(const ValueKey<String>('group_setting_invite_mode_switch')),
        findsOneWidget,
      );
      expect(_switchValue(tester, 'group_setting_invite_mode_switch'), isTrue);
      await _scrollToFinder(
        tester,
        find.byKey(
          const ValueKey<String>(
            'group_setting_allow_member_pinned_message_switch',
          ),
        ),
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'group_setting_allow_member_pinned_message_switch',
          ),
        ),
        findsOneWidget,
      );
      expect(
        _switchValue(tester, 'group_setting_allow_view_history_switch'),
        isFalse,
      );
      expect(
        _switchValue(
          tester,
          'group_setting_allow_member_pinned_message_switch',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'small groups still expose all members entry and owner group mute switch',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 0, forbidden: 0),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      expect(
        find.byKey(const ValueKey<String>('group-all-members-entry')),
        findsOneWidget,
      );
      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey<String>('group_setting_forbidden_switch')),
      );
      expect(
        find.byKey(const ValueKey<String>('group_setting_forbidden_switch')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('group_setting_forbidden_switch')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/forbidden/1',
        ),
        1,
      );
    },
  );

  testWidgets(
    'live Android settings section renders chat password and message auto-delete from confirmed server values',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 1, chatPwdOn: 1),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
        messageAutoDeleteSeconds: 86400,
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey<String>('group_setting_chat_pwd_switch')),
      );
      expect(
        find.byKey(const ValueKey<String>('group_setting_chat_pwd_switch')),
        findsOneWidget,
      );
      expect(_switchValue(tester, 'group_setting_chat_pwd_switch'), isTrue);
      await _scrollToFinder(
        tester,
        find.byKey(
          const ValueKey<String>('group_setting_message_auto_delete_cell'),
        ),
      );
      expect(
        find.byKey(
          const ValueKey<String>('group_setting_message_auto_delete_cell'),
        ),
        findsOneWidget,
      );
      expect(
        _cellValue(tester, 'group_setting_message_auto_delete_cell'),
        '1天',
      );
    },
  );

  testWidgets('group detail renders localized Android section labels', (
    tester,
  ) async {
    final adapter = _GroupDetailRoutingAdapter(
      groupNo: _groupNo,
      group: _buildGroupJson(
        role: 1,
        invite: 1,
        showNick: 1,
        allowViewHistoryMsg: 1,
        joinGroupRemind: 1,
        allowMemberPinnedMessage: 1,
      ),
      members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
      friends: const <Map<String, dynamic>>[],
    );

    await _pumpGroupDetailPage(tester, adapter: adapter, currentUid: 'u_owner');

    expect(find.text('聊天信息(2)'), findsOneWidget);
    await _scrollToFinder(
      tester,
      find.byKey(const ValueKey<String>('group_setting_show_nick_switch')),
    );
    expect(find.text('显示群成员昵称'), findsOneWidget);
    await _scrollToFinder(
      tester,
      find.byKey(const ValueKey<String>('group_setting_invite_mode_switch')),
    );
    expect(find.text('邀请入群模式'), findsOneWidget);
    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('group_setting_allow_view_history_switch'),
      ),
    );
    expect(find.text('新成员可查看历史消息'), findsOneWidget);
    await _scrollToFinder(
      tester,
      find.byKey(const ValueKey<String>('group-blacklist-entry')),
    );
    expect(find.text('群黑名单'), findsOneWidget);
  });

  testWidgets(
    'group detail backfills member names from friends when member payload omits profile data',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 0),
        members: const <Map<String, dynamic>>[
          <String, dynamic>{
            'group_no': _groupNo,
            'uid': 'u_owner',
            'name': 'Owner',
            'role': 1,
          },
          <String, dynamic>{
            'channel_id': _groupNo,
            'member_uid': 'u_friend',
            'role': 0,
          },
        ],
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'u_friend',
            'name': 'test4',
            'avatar': 'https://example.com/test4.png',
          },
        ],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      expect(find.text('test4'), findsOneWidget);
      expect(find.text('u_friend'), findsNothing);
    },
  );

  testWidgets(
    'group detail uses settings-surface layout with readable member badges and compact desktop member layout',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(
          role: 1,
          invite: 1,
          showNick: 1,
          allowViewHistoryMsg: 1,
          joinGroupRemind: 1,
          allowMemberPinnedMessage: 1,
        ),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      expect(find.byType(SettingsHero), findsOneWidget);
      expect(find.text('群主'), findsOneWidget);
      expect(find.text('缇や富'), findsNothing);
      expect(find.text('兼容飞书机器人'), findsNothing);
      await _scrollToFinder(tester, find.text('飞书机器人'));
      expect(find.text('飞书机器人'), findsOneWidget);
      await _scrollToFinder(
        tester,
        find.byKey(const ValueKey<String>('group_exit_action_tile')),
      );
      expect(find.byType(SettingsSection), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('group_exit_action_tile')),
        findsOneWidget,
      );
      expect(find.byType(GridView), findsNothing);
    },
  );

  testWidgets('owner action sheet uses readable transfer-owner label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final adapter = _GroupDetailRoutingAdapter(
      groupNo: _groupNo,
      group: _buildGroupJson(role: 1, invite: 0),
      members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
      friends: const <Map<String, dynamic>>[],
    );

    await _pumpGroupDetailPage(tester, adapter: adapter, currentUid: 'u_owner');

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('转让群主'), findsOneWidget);
    expect(find.text('杞缇や富'), findsNothing);
  });

  testWidgets(
    'group detail updates chat password switch and auto-delete cache through confirmed routes',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 0, chatPwdOn: 0),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
        messageAutoDeleteSeconds: 0,
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      await _tapSwitch(tester, 'group_setting_chat_pwd_switch');
      await tester.pumpAndSettle();

      expect(adapter.requestCount('PUT', adapter.settingPath), greaterThan(0));
      expect(adapter.lastSettingRequestData, containsPair('chat_pwd_on', 1));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('group_setting_message_auto_delete_cell'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('channel_auto_delete_option_86400')),
      );
      await tester.pumpAndSettle();

      expect(adapter.requestCount('POST', adapter.autoDeletePath), 1);
      expect(
        adapter.lastAutoDeleteRequestData,
        containsPair('msg_auto_delete', 86400),
      );
    },
  );

  testWidgets('live Android exit action opens aligned WK confirm dialog path', (
    tester,
  ) async {
    final adapter = _GroupDetailRoutingAdapter(
      groupNo: _groupNo,
      group: _buildGroupJson(role: 0, invite: 0),
      members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
      friends: const <Map<String, dynamic>>[],
    );

    await _pumpGroupDetailPage(
      tester,
      adapter: adapter,
      currentUid: 'u_member',
    );

    final exitCell = find.byKey(
      const ValueKey<String>('group_exit_action_tile'),
    );
    await _scrollToFinder(tester, exitCell);
    expect(exitCell, findsOneWidget);

    await tester.ensureVisible(exitCell);
    await tester.pumpAndSettle();
    await tester.tap(exitCell);
    await tester.pumpAndSettle();

    expect(find.byType(WKDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'invite-only mode keeps add-member affordance visible for normal members',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 0, invite: 1),
        members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
        ],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_member',
      );

      expect(_findAddMemberAffordance(), findsOneWidget);
    },
  );

  testWidgets(
    'group avatar upload keeps returned avatar visible when reload is stale',
    (tester) async {
      const oldAvatar = 'groups/g_task2/avatar-old.png';
      const newAvatar = 'https://infoequity.cn/v1/groups/g_task2/avatar?t=123';
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 0, avatar: oldAvatar),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
        pickAvatarImage: () async => 'C:\\fake\\avatar.png',
        uploadAvatarImage: (_, _) async => newAvatar,
      );

      final avatarTile = find.byKey(
        const ValueKey<String>('group-detail-avatar-button'),
      );
      await _scrollToFinder(tester, avatarTile);
      expect(
        _avatarUrlInTile(tester, avatarTile),
        ApiConfig.resolveMediaUrl(oldAvatar),
      );

      await tester.tap(avatarTile);
      await tester.pumpAndSettle();

      expect(_avatarUrlInTile(tester, avatarTile), newAvatar);

      await _tapSwitch(tester, 'group_setting_show_nick_switch');
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(avatarTile, findsOneWidget);
      expect(_avatarUrlInTile(tester, avatarTile), newAvatar);
    },
  );

  testWidgets(
    'invite-only mode uses inviteMembers for normal member add flow',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 0, invite: 1),
        members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
        ],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_member',
      );

      await _runAddFlow(tester);

      expect(adapter.requestCount('POST', adapter.invitePath), 1);
      expect(adapter.requestCount('POST', adapter.membersPath), 0);
      expect(find.text('邀请已发送 (1 位)'), findsOneWidget);
    },
  );

  testWidgets('non-invite mode keeps addGroupMembers path for normal members', (
    tester,
  ) async {
    final adapter = _GroupDetailRoutingAdapter(
      groupNo: _groupNo,
      group: _buildGroupJson(role: 0, invite: 0),
      members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
      friends: const <Map<String, dynamic>>[
        <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
      ],
    );

    await _pumpGroupDetailPage(
      tester,
      adapter: adapter,
      currentUid: 'u_member',
    );

    await _runAddFlow(tester);

    expect(adapter.requestCount('POST', adapter.membersPath), 1);
    expect(adapter.requestCount('POST', adapter.invitePath), 0);
    expect(find.text('已添加 1 位成员'), findsOneWidget);
  });

  testWidgets(
    'invite-only mode keeps addGroupMembers path for owner-manager members',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, invite: 1),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
        ],
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
      );

      await _runAddFlow(tester);

      expect(adapter.requestCount('POST', adapter.membersPath), 1);
      expect(adapter.requestCount('POST', adapter.invitePath), 0);
      expect(find.text('已添加 1 位成员'), findsOneWidget);
    },
  );

  testWidgets(
    'invite-only mode shows invite-specific failure message for normal members',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 0, invite: 1),
        members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
        ],
        failInviteRequest: true,
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_member',
      );

      await _runAddFlow(tester);

      expect(find.textContaining('发送邀请失败'), findsOneWidget);
    },
  );

  testWidgets(
    'non-invite mode shows direct-add failure message for normal members',
    (tester) async {
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 0, invite: 0),
        members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'u-friend-1', 'name': 'Friend 1'},
        ],
        failMembersRequest: true,
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_member',
      );

      await _runAddFlow(tester);

      expect(find.textContaining('添加群成员失败'), findsOneWidget);
    },
  );

  testWidgets(
    'add member picker backfills uid-only friends from user profile',
    (tester) async {
      const friendUid = 'e7b89b61bf304c73a77f4db6a37a321f';
      final adapter = _GroupDetailRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 0, invite: 0),
        members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
        friends: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': friendUid},
        ],
        userProfiles: const <String, Map<String, dynamic>>{
          friendUid: <String, dynamic>{
            'uid': friendUid,
            'name': 'Friend Display Name',
            'avatar': 'https://example.com/friend.png',
          },
        },
      );

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_member',
      );

      final addAffordance = _findAddMemberAffordance();
      expect(addAffordance, findsOneWidget);

      await tester.tap(addAffordance);
      await tester.pumpAndSettle();

      expect(find.text('Friend Display Name'), findsOneWidget);
      expect(find.text(friendUid), findsOneWidget);
    },
  );
}

Future<void> _pumpGroupDetailPage(
  WidgetTester tester, {
  required _GroupDetailRoutingAdapter adapter,
  required String currentUid,
  Future<String?> Function()? pickAvatarImage,
  Future<String> Function(String groupNo, String filePath)? uploadAvatarImage,
}) async {
  await StorageUtils.setUid(currentUid);
  ApiClient.instance.dio.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: GroupDetailPage(
          channelId: _groupNo,
          pickAvatarImage: pickAvatarImage,
          uploadAvatarImage: uploadAvatarImage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _runAddFlow(WidgetTester tester) async {
  final addAffordance = _findAddMemberAffordance();
  expect(addAffordance, findsOneWidget);

  await tester.tap(addAffordance);
  await tester.pumpAndSettle();

  final selectableMembers = find.byType(CheckboxListTile);
  expect(selectableMembers, findsWidgets);
  await tester.tap(selectableMembers.first);
  await tester.pumpAndSettle();

  final submitButton = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(TextButton),
  );
  expect(submitButton, findsOneWidget);

  await tester.tap(submitButton);
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester, String key) {
  return tester.widget<SwitchListTile>(find.byKey(ValueKey<String>(key))).value;
}

String? _cellValue(WidgetTester tester, String key) {
  final tile = tester.widget<ListTile>(find.byKey(ValueKey<String>(key)));
  final subtitle = tile.subtitle;
  if (subtitle is Text) {
    return subtitle.data;
  }
  return null;
}

String? _avatarUrlInTile(WidgetTester tester, Finder tile) {
  final avatars = tester.widgetList<WKAvatar>(
    find.descendant(of: tile, matching: find.byType(WKAvatar)),
  );
  return avatars.first.url;
}

Future<void> _tapSwitch(WidgetTester tester, String key) async {
  final container = find.byKey(ValueKey<String>(key));
  await _scrollToFinder(tester, container);
  await tester.tap(container);
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _findAddMemberAffordance() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) {
      return false;
    }
    final imageProvider = widget.image;
    return imageProvider is AssetImage &&
        imageProvider.assetName == WKReferenceAssets.chatAdd;
  });
}

Map<String, dynamic> _buildGroupJson({
  required int role,
  required int invite,
  String? avatar,
  int showNick = 1,
  int allowViewHistoryMsg = 1,
  int joinGroupRemind = 1,
  int allowMemberPinnedMessage = 0,
  int chatPwdOn = 0,
  int forbidden = 0,
}) {
  return <String, dynamic>{
    'group_no': _groupNo,
    'name': 'Task2 Group',
    'creator': 'u_owner',
    'avatar': avatar,
    'member_count': 2,
    'role': role,
    'invite': invite,
    'forbidden': forbidden,
    'mute': 0,
    'top': 0,
    'save': 1,
    'show_nick': showNick,
    'chat_pwd_on': chatPwdOn,
    'allow_view_history_msg': allowViewHistoryMsg,
    'join_group_remind': joinGroupRemind,
    'allow_member_pinned_message': allowMemberPinnedMessage,
  };
}

List<Map<String, dynamic>> _buildMembersJson({
  required String currentUid,
  required int currentRole,
}) {
  final members = <Map<String, dynamic>>[
    <String, dynamic>{
      'group_no': _groupNo,
      'uid': 'u_owner',
      'name': 'Owner',
      'role': 1,
    },
    <String, dynamic>{
      'group_no': _groupNo,
      'uid': 'u_member',
      'name': 'Member',
      'role': 0,
    },
  ];

  if (currentUid != 'u_owner' && currentUid != 'u_member') {
    members.add(<String, dynamic>{
      'group_no': _groupNo,
      'uid': currentUid,
      'name': 'Current User',
      'role': currentRole,
    });
  } else {
    for (var i = 0; i < members.length; i++) {
      if (members[i]['uid'] == currentUid) {
        members[i] = <String, dynamic>{...members[i], 'role': currentRole};
      }
    }
  }

  return members;
}

class _GroupDetailRoutingAdapter implements HttpClientAdapter {
  _GroupDetailRoutingAdapter({
    required this.groupNo,
    required Map<String, dynamic> group,
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> friends,
    Map<String, Map<String, dynamic>> userProfiles = const {},
    this.failMembersRequest = false,
    this.failInviteRequest = false,
    this.messageAutoDeleteSeconds = 0,
  }) : _group = Map<String, dynamic>.from(group),
       _members = members
           .map((member) => Map<String, dynamic>.from(member))
           .toList(),
       _friends = friends
           .map((friend) => Map<String, dynamic>.from(friend))
           .toList(),
       _userProfiles = userProfiles.map(
         (uid, profile) => MapEntry(uid, Map<String, dynamic>.from(profile)),
       );

  final String groupNo;
  final Map<String, dynamic> _group;
  final List<Map<String, dynamic>> _members;
  final List<Map<String, dynamic>> _friends;
  final Map<String, Map<String, dynamic>> _userProfiles;
  final bool failMembersRequest;
  final bool failInviteRequest;
  int messageAutoDeleteSeconds;
  final List<RequestOptions> requests = <RequestOptions>[];

  String get groupPath => '${ApiConfig.groups}/$groupNo';
  String get membersPath => '$groupPath${ApiConfig.groupMembers}';
  String get settingPath => '$groupPath${ApiConfig.groupSetting}';
  String get invitePath => '$groupPath/member/invite';
  String get channelPath => '/v1/channels/$groupNo/1';
  String get autoDeletePath => '$channelPath/message/autodelete';
  Map<String, dynamic>? lastSettingRequestData;
  Map<String, dynamic>? lastAutoDeleteRequestData;

  int requestCount(String method, String path) {
    final expectedMethod = method.toUpperCase();
    return requests.where((request) {
      return request.method.toUpperCase() == expectedMethod &&
          request.uri.path == path;
    }).length;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'GET' && path == groupPath) {
      return _jsonResponse(<String, dynamic>{'code': 0, 'data': _group});
    }
    if (method == 'GET' && path == membersPath) {
      return _jsonResponse(<String, dynamic>{'code': 0, 'data': _members});
    }
    if (method == 'GET' && path == ApiConfig.friends) {
      return _jsonResponse(<String, dynamic>{'code': 0, 'data': _friends});
    }
    if (method == 'GET' && path.startsWith('${ApiConfig.userInfo}/')) {
      final uid = path.substring(ApiConfig.userInfo.length + 1);
      return _jsonResponse(_resolveUserInfo(uid));
    }
    if (method == 'GET' && path == channelPath) {
      return _jsonResponse(<String, dynamic>{
        'channel': <String, dynamic>{'channel_id': groupNo, 'channel_type': 1},
        'name': _group['name'] ?? '',
        'extra': <String, dynamic>{'msg_auto_delete': messageAutoDeleteSeconds},
      });
    }
    if (method == 'PUT' && path == settingPath) {
      _applyGroupSettings(options.data);
      lastSettingRequestData = _asMap(options.data);
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path.startsWith('$groupPath/forbidden/')) {
      _group['forbidden'] = path.endsWith('/1') ? 1 : 0;
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == autoDeletePath) {
      final payload = _asMap(options.data);
      messageAutoDeleteSeconds =
          (payload['msg_auto_delete'] as num?)?.toInt() ??
          messageAutoDeleteSeconds;
      lastAutoDeleteRequestData = payload;
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == membersPath) {
      if (failMembersRequest) {
        return _jsonResponse(const <String, dynamic>{
          'code': 1,
          'msg': 'mock direct add failure',
        });
      }
      _appendMembers(options.data);
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == invitePath) {
      if (failInviteRequest) {
        return _jsonResponse(const <String, dynamic>{
          'code': 1,
          'msg': 'mock invite failure',
        });
      }
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }

    return _jsonResponse(<String, dynamic>{
      'code': 404,
      'msg': 'Unhandled request: $method $path',
    }, statusCode: 404);
  }

  Map<String, dynamic> _resolveUserInfo(String uid) {
    final profile = _userProfiles[uid];
    if (profile != null) {
      return <String, dynamic>{'uid': uid, ...profile};
    }

    final member = _members.cast<Map<String, dynamic>?>().firstWhere((item) {
      final map = item ?? const <String, dynamic>{};
      final memberUid =
          map['uid']?.toString() ?? map['member_uid']?.toString() ?? '';
      return memberUid == uid;
    }, orElse: () => null);
    if (member != null) {
      return <String, dynamic>{
        'uid': uid,
        'name':
            member['name']?.toString() ??
            member['member_name']?.toString() ??
            member['username']?.toString() ??
            uid,
        'avatar':
            member['avatar']?.toString() ?? member['member_avatar']?.toString(),
      };
    }

    final friend = _friends.cast<Map<String, dynamic>?>().firstWhere(
      (item) => (item?['uid']?.toString() ?? '') == uid,
      orElse: () => null,
    );
    if (friend != null) {
      return <String, dynamic>{
        'uid': uid,
        'name': friend['name']?.toString() ?? uid,
        'avatar': friend['avatar']?.toString(),
        'remark': friend['remark']?.toString(),
      };
    }

    return <String, dynamic>{'uid': uid, 'name': uid};
  }

  void _applyGroupSettings(dynamic data) {
    final payload = _asMap(data);
    for (final entry in payload.entries) {
      _group[entry.key] = entry.value;
    }
  }

  void _appendMembers(dynamic data) {
    final payload = _asMap(data);
    final rawIds =
        payload['uids'] ?? payload['members'] ?? payload['member_ids'];
    if (rawIds is! List) {
      return;
    }

    final rawNames = payload['names'] ?? payload['member_names'];
    final names = rawNames is List
        ? rawNames.map((item) => item.toString()).toList(growable: false)
        : const <String>[];

    final existing = _members
        .map(
          (member) =>
              member['uid']?.toString() ??
              member['member_uid']?.toString() ??
              '',
        )
        .toSet();
    for (var i = 0; i < rawIds.length; i++) {
      final uid = rawIds[i].toString();
      if (existing.contains(uid)) {
        continue;
      }
      final displayName = i < names.length && names[i].trim().isNotEmpty
          ? names[i].trim()
          : uid;
      _members.add(<String, dynamic>{
        'group_no': groupNo,
        'uid': uid,
        'name': displayName,
        'role': 0,
      });
      existing.add(uid);
    }
    _group['member_count'] = _members.length;
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
];

class _FakeHttpClient extends Fake implements HttpClient {
  final _FakeHttpClientRequest request = _FakeHttpClientRequest();
  Object? thrownError;

  @override
  set autoUncompress(bool value) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (thrownError != null) {
      throw thrownError!;
    }
    return request;
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final _FakeHttpClientResponse response = _FakeHttpClientResponse();

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return response;
  }
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  bool drained = false;

  @override
  int statusCode = HttpStatus.ok;

  @override
  int contentLength = 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  late List<List<int>> content;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(content).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<E> drain<E>([E? futureValue]) async {
    drained = true;
    return futureValue ?? futureValue as E;
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpOverrides extends HttpOverrides {
  _FakeHttpOverrides(this.client);

  final HttpClient client;

  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}
