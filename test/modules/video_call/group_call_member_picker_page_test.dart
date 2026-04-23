import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/group_call_member_picker_page.dart';
import 'package:wukong_im_app/modules/video_call/group_call_service.dart';
import 'package:wukong_im_app/modules/video_call/video_call_page.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('picker submits selected members through the service', (
    tester,
  ) async {
    List<GroupCallMemberCandidate>? submittedMembers;
    final service = GroupCallService(
      loadMembersPage:
          ({
            required String channelId,
            required int channelType,
            required String keyword,
            required int page,
            required int pageSize,
          }) async {
            return const GroupCallMemberPage(
              items: <GroupCallMemberCandidate>[
                GroupCallMemberCandidate(uid: 'u_alice', displayName: 'Alice'),
              ],
              page: 1,
              hasMore: false,
              maxSelectableCount: 9,
            );
          },
      createGroupCallRunner:
          ({
            required String channelId,
            required int channelType,
            required List<GroupCallMemberCandidate> selectedMembers,
          }) async {
            submittedMembers = selectedMembers;
            return const GroupCallCreateResult(shouldClose: false);
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GroupCallMemberPickerPage(
          channelId: 'g_demo',
          channelType: WKChannelType.group,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group-call-member-u_alice')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('group-call-confirm-button')));
    await tester.pump();

    expect(submittedMembers?.map((member) => member.uid), <String>['u_alice']);
  });

  testWidgets('picker search reloads members with the trimmed keyword', (
    tester,
  ) async {
    final requestedKeywords = <String>[];
    final service = GroupCallService(
      loadMembersPage:
          ({
            required String channelId,
            required int channelType,
            required String keyword,
            required int page,
            required int pageSize,
          }) async {
            requestedKeywords.add(keyword);
            return GroupCallMemberPage(
              items: keyword == 'bob'
                  ? const <GroupCallMemberCandidate>[
                      GroupCallMemberCandidate(
                        uid: 'u_bob',
                        displayName: 'Bob',
                      ),
                    ]
                  : const <GroupCallMemberCandidate>[
                      GroupCallMemberCandidate(
                        uid: 'u_alice',
                        displayName: 'Alice',
                      ),
                    ],
              page: 1,
              hasMore: false,
              maxSelectableCount: 9,
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GroupCallMemberPickerPage(
          channelId: 'g_demo',
          channelType: WKChannelType.group,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('group-call-search-field')),
      '  bob  ',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requestedKeywords, contains('bob'));
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets(
    'picker launches VideoCallPage after successful group selection',
    (tester) async {
      final service = GroupCallService(
        loadMembersPage:
            ({
              required String channelId,
              required int channelType,
              required String keyword,
              required int page,
              required int pageSize,
            }) async {
              return const GroupCallMemberPage(
                items: <GroupCallMemberCandidate>[
                  GroupCallMemberCandidate(
                    uid: 'u_alice',
                    displayName: 'Alice',
                  ),
                ],
                page: 1,
                hasMore: false,
                maxSelectableCount: 9,
              );
            },
        createGroupCallRunner:
            ({
              required String channelId,
              required int channelType,
              required List<GroupCallMemberCandidate> selectedMembers,
            }) async {
              return const GroupCallCreateResult(shouldClose: true);
            },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GroupCallMemberPickerPage(
            channelId: 'g_demo',
            channelType: WKChannelType.group,
            channelName: '研发群',
            videoCallAutoStart: false,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('group-call-member-u_alice')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('group-call-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.byType(VideoCallPage), findsOneWidget);
    },
  );
}
