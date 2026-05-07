import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';

import '../../tool/manual_phase3_runtime_probe.dart';

void main() {
  ManualPhase3ProbeSnapshot buildSnapshot() {
    return ManualPhase3ProbeSnapshot(
      uid: 'uid_001',
      tokenPreview: 'tok...0001',
      group: GroupInfo(groupNo: 'group_001', name: 'Probe Group'),
      members: <GroupMember>[
        GroupMember(groupNo: 'group_001', uid: 'uid_001', name: 'Owner'),
        GroupMember(groupNo: 'group_001', uid: 'uid_002', name: 'Member'),
      ],
      qrRawContent:
          'https://infoequity.cn/join_group.html?group_no=group_001&auth_code=auth_001',
      internalJoinGroupNo: 'group_001',
      internalJoinAuthCode: 'auth_001',
      usedSyntheticInternalJoin: false,
      notes: const <String>['Probe note'],
    );
  }

  testWidgets('renders phase 3 probe actions after loading snapshot', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 2200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ManualPhase3RuntimeProbeHomePage(
            loadSnapshot: () async => buildSnapshot(),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('UID: uid_001'), findsOneWidget);
    expect(find.text('Group: Probe Group'), findsOneWidget);
    expect(find.text('- Probe note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('phase3_probe_open_group_detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_all_members')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_all_members_search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_chat_search_entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_active_group_scan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_removed_group_scan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phase3_probe_open_internal_join_scan')),
      findsOneWidget,
    );
  });

  testWidgets('opens injected destinations from probe actions', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 2200));

    Widget destination(String label) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(label)),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ManualPhase3RuntimeProbeHomePage(
            loadSnapshot: () async => buildSnapshot(),
            buildGroupDetailPage: (_) =>
                destination('group-detail-destination'),
            buildAllMembersPage: (_) => destination('all-members-destination'),
            buildAllMembersSearchPage: (_) =>
                destination('all-members-search-destination'),
            buildChatSearchEntryPage: (_) =>
                destination('chat-search-entry-destination'),
            buildActiveGroupScanPage: (_) =>
                destination('active-scan-destination'),
            buildRemovedGroupScanPage: (_) =>
                destination('removed-scan-destination'),
            buildInternalJoinScanPage: (_) =>
                destination('internal-join-destination'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('phase3_probe_open_group_detail')),
    );
    await tester.pumpAndSettle();
    expect(find.text('group-detail-destination'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('phase3_probe_open_internal_join_scan')),
    );
    await tester.pumpAndSettle();
    expect(find.text('internal-join-destination'), findsOneWidget);
  });

  testWidgets('auto opens the requested target after snapshot load', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 2200));

    Widget destination(String label) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(label)),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ManualPhase3RuntimeProbeHomePage(
            loadSnapshot: () async => buildSnapshot(),
            autoOpenTarget: 'all_members_search',
            buildAllMembersSearchPage: (_) =>
                destination('auto-open-search-members'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('auto-open-search-members'), findsOneWidget);
  });
}
