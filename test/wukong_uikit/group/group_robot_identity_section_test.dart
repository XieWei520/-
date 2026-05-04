import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_robot_identity_section.dart';

void main() {
  testWidgets('renders aligned avatar action row with keyed outlined buttons', (
    tester,
  ) async {
    final displayNameController = TextEditingController(text: '群内机器人');
    addTearDown(displayNameController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupRobotIdentitySection(
            providerName: '飞书',
            displayNameController: displayNameController,
            displayAvatar: '',
            isBusy: false,
            onUploadAvatar: () async {},
            onClearAvatar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byKey(
      const ValueKey('group-robot-avatar-action-row'),
    );
    final uploadButtonFinder = find.byKey(
      const ValueKey('group-robot-upload-avatar-button'),
    );
    final clearButtonFinder = find.byKey(
      const ValueKey('group-robot-clear-avatar-button'),
    );

    expect(rowFinder, findsOneWidget);
    expect(uploadButtonFinder, findsOneWidget);
    expect(clearButtonFinder, findsOneWidget);
    expect(find.text('机器人在 IM 群内展示'), findsOneWidget);
    expect(find.textContaining('仅影响悟空 IM 群内显示'), findsOneWidget);
    expect(find.text('上传头像'), findsOneWidget);
    expect(find.text('清空头像'), findsOneWidget);
    expect(
      find.descendant(of: rowFinder, matching: uploadButtonFinder),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowFinder, matching: clearButtonFinder),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(uploadButtonFinder).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<OutlinedButton>(clearButtonFinder).onPressed,
      isNotNull,
    );
  });
}
