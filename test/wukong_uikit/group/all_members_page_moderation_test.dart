import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/wukong_uikit/group/all_members_page.dart';

import 'support/group_moderation_test_adapter.dart';

const String _groupNo = 'g_demo';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    originalAdapter = Dio().httpClientAdapter;
  });

  tearDown(() {
    originalAdapter.close(force: true);
  });

  testWidgets('owner sees moderation trigger for eligible members only', (
    tester,
  ) async {
    final adapter = GroupModerationTestAdapter(
      groupNo: _groupNo,
      currentUid: 'u_owner',
      members: <GroupMember>[
        _member(uid: 'u_owner', name: 'Owner', role: 1),
        _member(uid: 'u_admin', name: 'Admin', role: 2),
        _member(uid: 'u_member', name: 'Member', role: 0),
      ],
    );

    await _pumpAllMembersPage(tester, adapter: adapter);

    expect(
      find.byKey(const ValueKey<String>('member-moderation-trigger-u_member')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('member-moderation-trigger-u_admin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('member-moderation-trigger-u_owner')),
      findsNothing,
    );
  });

  testWidgets('admin does not see moderation trigger in searchMessage mode', (
    tester,
  ) async {
    final adapter = GroupModerationTestAdapter(
      groupNo: _groupNo,
      currentUid: 'u_admin',
      members: <GroupMember>[
        _member(uid: 'u_admin', name: 'Admin', role: 2),
        _member(uid: 'u_member', name: 'Member', role: 0),
      ],
    );

    await _pumpAllMembersPage(tester, adapter: adapter, searchMessage: true);

    expect(
      find.byKey(const ValueKey<String>('member-moderation-trigger-u_member')),
      findsNothing,
    );
  });

  testWidgets(
    'mute flow loads backend durations and posts forbidden endpoint',
    (tester) async {
      final adapter = GroupModerationTestAdapter(
        groupNo: _groupNo,
        currentUid: 'u_owner',
        members: <GroupMember>[
          _member(uid: 'u_owner', name: 'Owner', role: 1),
          _member(uid: 'u_member', name: 'Member', role: 0),
        ],
      );

      await _pumpAllMembersPage(tester, adapter: adapter);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('member-moderation-trigger-u_member'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('member-moderation-action-mute-u_member'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('group-forbidden-time-option-3')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('group-forbidden-time-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount('GET', '${ApiConfig.v1}/group/forbidden_times'),
        1,
      );
      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/forbidden_with_member',
        ),
        1,
      );
    },
  );

  testWidgets(
    'blacklist action posts to blacklist/add from the member action sheet',
    (tester) async {
      final adapter = GroupModerationTestAdapter(
        groupNo: _groupNo,
        currentUid: 'u_owner',
        members: <GroupMember>[
          _member(uid: 'u_owner', name: 'Owner', role: 1),
          _member(uid: 'u_member', name: 'Member', role: 0),
        ],
      );

      await _pumpAllMembersPage(tester, adapter: adapter);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('member-moderation-trigger-u_member'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'member-moderation-action-addToBlacklist-u_member',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/add',
        ),
        1,
      );
    },
  );
}

Future<void> _pumpAllMembersPage(
  WidgetTester tester, {
  required GroupModerationTestAdapter adapter,
  bool searchMessage = false,
}) async {
  await bootstrapGroupModerationTestEnvironment(adapter: adapter);
  await tester.pumpWidget(
    MaterialApp(
      home: AllMembersPage(
        channelId: adapter.groupNo,
        searchMessage: searchMessage,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GroupMember _member({
  required String uid,
  required String name,
  required int role,
  int status = GroupMemberStatus.normal,
  int? forbiddenExpirTime,
}) {
  return GroupMember(
    groupNo: _groupNo,
    uid: uid,
    name: name,
    role: role,
    status: status,
    forbiddenExpirTime: forbiddenExpirTime,
  );
}
