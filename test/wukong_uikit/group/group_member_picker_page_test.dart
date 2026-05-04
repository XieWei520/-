import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_member_picker_page.dart';

void main() {
  testWidgets('member picker renders remote avatars through WKAvatar', (
    tester,
  ) async {
    const avatarUrl = 'https://cdn.example.com/avatar/member.png';
    WKAvatar.setBytesLoaderForTesting((url) async => null);
    addTearDown(() => WKAvatar.setBytesLoaderForTesting(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: GroupMemberPickerPage(
          title: 'Select member',
          submitLabel: 'Done',
          emptyText: 'No members',
          candidates: <SelectableGroupMember>[
            SelectableGroupMember(
              uid: 'u_member',
              title: 'Member Alice',
              subtitle: 'Online',
              avatar: avatarUrl,
            ),
          ],
        ),
      ),
    );

    final avatar = tester.widget<WKAvatar>(find.byType(WKAvatar));
    expect(avatar.url, avatarUrl);
    expect(avatar.name, 'Member Alice');
    expect(avatar.size, 40);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar && widget.backgroundImage is NetworkImage,
      ),
      findsNothing,
    );
  });
}
