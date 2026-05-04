import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/group/saved_groups_page.dart';

void main() {
  Widget wrapWithApp(Widget child, {int vipLevel = 1}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) {
          return _TestAuthNotifier(
            ref,
            initialState: AuthState(
              isLoggedIn: true,
              isRestoringSession: false,
              userInfo: UserInfo(
                uid: 'u_self',
                name: 'Self',
                vipLevel: vipLevel,
              ),
            ),
          );
        }),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('saved groups page uses Android shell and simple group rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        SavedGroupsPage(
          autoLoad: false,
          initialGroups: [
            GroupInfo(groupNo: 'g_saved', name: '项目群', remark: '产品项目群'),
          ],
        ),
      ),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text('保存的群聊'), findsOneWidget);
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('产品项目群'), findsOneWidget);
    expect(find.textContaining('群号'), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
  });

  testWidgets('saved groups page shows Android empty helper copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const SavedGroupsPage(autoLoad: false, initialGroups: []),
      ),
    );

    expect(find.text('你可以通过群聊中的"保存到通讯录"选项，将其保存到这里'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
  });

  testWidgets('saved groups page blocks non vip create-group entry', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const SavedGroupsPage(autoLoad: false, initialGroups: []),
        vipLevel: 0,
      ),
    );

    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();

    expect(find.text(vipRequiredMessage), findsOneWidget);
    expect(find.text('联系管理员'), findsOneWidget);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
