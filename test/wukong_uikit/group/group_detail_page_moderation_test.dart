import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';

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

  testWidgets('group detail page shows blacklist entry for owners and admins', (
    tester,
  ) async {
    final adapter = GroupModerationTestAdapter(
      groupNo: _groupNo,
      currentUid: 'u_owner',
      members: <GroupMember>[
        _member(uid: 'u_owner', name: 'Owner', role: 1),
        _member(uid: 'u_member', name: 'Member', role: 0),
      ],
    );

    await _pumpGroupDetailPage(tester, adapter: adapter);

    expect(
      find.byKey(const ValueKey<String>('group-blacklist-entry')),
      findsOneWidget,
    );
  });

  testWidgets('group detail page hides blacklist entry from normal members', (
    tester,
  ) async {
    final adapter = GroupModerationTestAdapter(
      groupNo: _groupNo,
      currentUid: 'u_member',
      members: <GroupMember>[
        _member(uid: 'u_owner', name: 'Owner', role: 1),
        _member(uid: 'u_member', name: 'Member', role: 0),
      ],
    );

    await _pumpGroupDetailPage(tester, adapter: adapter);

    expect(
      find.byKey(const ValueKey<String>('group-blacklist-entry')),
      findsNothing,
    );
  });
}

Future<void> _pumpGroupDetailPage(
  WidgetTester tester, {
  required GroupModerationTestAdapter adapter,
}) async {
  await bootstrapGroupModerationTestEnvironment(adapter: adapter);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: GroupDetailPage(channelId: adapter.groupNo)),
    ),
  );
  await tester.pumpAndSettle();
}

GroupMember _member({
  required String uid,
  required String name,
  required int role,
  int status = GroupMemberStatus.normal,
}) {
  return GroupMember(
    groupNo: _groupNo,
    uid: uid,
    name: name,
    role: role,
    status: status,
  );
}
