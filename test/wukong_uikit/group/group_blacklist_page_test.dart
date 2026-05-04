import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_blacklist_page.dart';

import 'support/group_moderation_test_adapter.dart';

const String _groupNo = 'g_demo';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets('group blacklist page filters members by blacklist status', (
    tester,
  ) async {
    final adapter = GroupModerationTestAdapter(
      groupNo: _groupNo,
      currentUid: 'u_owner',
      members: <GroupMember>[
        _member(uid: 'u_owner', name: 'Owner', role: 1),
        _member(
          uid: 'u_blocked',
          name: 'Blocked',
          role: 0,
          status: GroupMemberStatus.blacklist,
        ),
      ],
    );

    await _pumpGroupBlacklistPage(tester, adapter: adapter);

    expect(
      find.byKey(const ValueKey<String>('group-blacklist-row-u_blocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-blacklist-row-u_owner')),
      findsNothing,
    );
  });

  testWidgets(
    'group blacklist page adds selected candidates through blacklist/add',
    (tester) async {
      final adapter = GroupModerationTestAdapter(
        groupNo: _groupNo,
        currentUid: 'u_owner',
        members: <GroupMember>[
          _member(uid: 'u_owner', name: 'Owner', role: 1),
          _member(uid: 'u_member', name: 'Member', role: 0),
        ],
      );

      await _pumpGroupBlacklistPage(tester, adapter: adapter);

      await tester.tap(
        find.byKey(const ValueKey<String>('group-blacklist-add')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('selectable-member-u_member')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('group-member-picker-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/add',
        ),
        1,
      );
      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/remove',
        ),
        0,
      );
      expect(
        find.byKey(const ValueKey<String>('group-blacklist-row-u_member')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'group blacklist page removes selected members through blacklist/remove',
    (tester) async {
      final adapter = GroupModerationTestAdapter(
        groupNo: _groupNo,
        currentUid: 'u_owner',
        members: <GroupMember>[
          _member(uid: 'u_owner', name: 'Owner', role: 1),
          _member(
            uid: 'u_blocked',
            name: 'Blocked',
            role: 0,
            status: GroupMemberStatus.blacklist,
          ),
        ],
      );

      await _pumpGroupBlacklistPage(tester, adapter: adapter);

      await tester.tap(
        find.byKey(const ValueKey<String>('group-blacklist-remove-u_blocked')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/remove',
        ),
        1,
      );
      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/add',
        ),
        0,
      );
      expect(
        find.byKey(const ValueKey<String>('group-blacklist-row-u_blocked')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'group blacklist page returns changed=true after a successful mutation',
    (tester) async {
      final adapter = GroupModerationTestAdapter(
        groupNo: _groupNo,
        currentUid: 'u_owner',
        members: <GroupMember>[
          _member(uid: 'u_owner', name: 'Owner', role: 1),
          _member(
            uid: 'u_blocked',
            name: 'Blocked',
            role: 0,
            status: GroupMemberStatus.blacklist,
          ),
        ],
      );

      bool? routeResult;
      await _pumpGroupBlacklistRouteHarness(
        tester,
        adapter: adapter,
        onResult: (value) => routeResult = value,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('open-group-blacklist-page')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('group-blacklist-remove-u_blocked')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'POST',
          '${ApiConfig.groups}/$_groupNo/blacklist/remove',
        ),
        1,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(routeResult, isTrue);
    },
  );
}

Future<void> _pumpGroupBlacklistPage(
  WidgetTester tester, {
  required GroupModerationTestAdapter adapter,
}) async {
  await bootstrapGroupModerationTestEnvironment(adapter: adapter);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: GroupBlacklistPage(channelId: adapter.groupNo)),
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

Future<void> _pumpGroupBlacklistRouteHarness(
  WidgetTester tester, {
  required GroupModerationTestAdapter adapter,
  required ValueChanged<bool?> onResult,
}) async {
  await bootstrapGroupModerationTestEnvironment(adapter: adapter);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: _BlacklistRouteHarness(
          groupNo: adapter.groupNo,
          onResult: onResult,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _BlacklistRouteHarness extends StatelessWidget {
  const _BlacklistRouteHarness({required this.groupNo, required this.onResult});

  final String groupNo;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('open-group-blacklist-page'),
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => GroupBlacklistPage(channelId: groupNo),
              ),
            );
            onResult(result);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
