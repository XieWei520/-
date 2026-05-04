import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_badge.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_head_portrait_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_info_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/update_user_info_page.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return ProviderScope(child: MaterialApp(home: child));
  }

  testWidgets('my info page matches Android avatar size and sex mapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'u_self',
            name: 'Alice',
            shortNo: '1001',
            sex: 0,
          ),
        ),
      ),
    );

    final avatar = tester.widget<WKAvatar>(find.byType(WKAvatar).first);
    expect(avatar.size, 40);
    expect(find.text('女'), findsOneWidget);
    expect(find.text('保密'), findsNothing);
  });

  testWidgets('my info page shows Android sex sheet without privacy option', (
    tester,
  ) async {
    var updatedSex = -1;

    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          onUpdateSex: (value) async {
            updatedSex = value;
          },
          initialUserOverride: UserInfo(uid: 'u_self', name: 'Alice', sex: 1),
        ),
      ),
    );

    await tester.tap(find.text('性别'));
    await tester.pumpAndSettle();

    expect(find.text('男'), findsWidgets);
    expect(find.text('女'), findsOneWidget);
    expect(find.text('保密'), findsNothing);

    await tester.tap(find.text('女'));
    await tester.pumpAndSettle();

    expect(updatedSex, 0);
  });

  testWidgets(
    'my info page disables short number row and hides arrow when Android marks it immutable',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MyInfoPage(
            skipInitialLoad: true,
            runtimeCapabilitiesOverride: const AppRuntimeCapabilities(
              webLoginUrl: '',
              webLoginReachable: false,
              webLoginStatusMessage: '',
              shortNoEditable: true,
              shortNoEditStatusMessage: '服务端允许修改短编号',
            ),
            initialUserOverride: UserInfo(
              uid: 'u_self',
              name: 'Alice',
              shortNo: '1001',
              shortStatus: 1,
            ),
          ),
        ),
      );

      final shortNoCell = tester.widget<WKSettingsCell>(
        find.ancestor(
          of: find.text('悟空号'),
          matching: find.byType(WKSettingsCell),
        ),
      );

      expect(shortNoCell.enabled, isFalse);
      expect(shortNoCell.showArrow, isFalse);
    },
  );

  testWidgets('my info page opens Android head portrait page from avatar row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'u_self',
            name: 'Alice',
            avatar: 'mock-avatar',
          ),
        ),
      ),
    );

    await tester.tap(find.text('头像'));
    await tester.pumpAndSettle();

    expect(find.byType(MyHeadPortraitPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my_head_portrait_image')),
      findsOneWidget,
    );
  });

  testWidgets('my info page opens Android name editor page from name row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          initialUserOverride: UserInfo(uid: 'u_self', name: 'Alice'),
        ),
      ),
    );

    await tester.tap(find.text('名字'));
    await tester.pumpAndSettle();

    expect(find.byType(UpdateUserInfoPage), findsOneWidget);
    expect(find.text('修改名称'), findsOneWidget);
  });

  testWidgets(
    'my info page opens Android short number editor page from short number row',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          MyInfoPage(
            skipInitialLoad: true,
            runtimeCapabilitiesOverride: const AppRuntimeCapabilities(
              webLoginUrl: '',
              webLoginReachable: false,
              webLoginStatusMessage: '',
              shortNoEditable: true,
              shortNoEditStatusMessage: '服务端允许修改短编号',
            ),
            initialUserOverride: UserInfo(
              uid: 'u_self',
              name: 'Alice',
              shortNo: '1001',
              shortStatus: 0,
            ),
          ),
        ),
      );

      await tester.tap(find.text('悟空号'));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateUserInfoPage), findsOneWidget);
      expect(find.text('修改悟空号'), findsOneWidget);
      expect(find.text('悟空号只允许修改一次'), findsOneWidget);
    },
  );

  testWidgets('my info page shows vip identity row for vip users', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'u_self',
            name: 'Alice',
            vipLevel: 1,
          ),
        ),
      ),
    );

    expect(find.text('\u8EAB\u4EFD'), findsOneWidget);
    expect(find.byType(VipBadge), findsOneWidget);
  });

  testWidgets('my info page shows customer service identity row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        MyInfoPage(
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'cs_self',
            name: 'Support',
            category: 'customerService',
          ),
        ),
      ),
    );

    expect(find.text('\u8eab\u4efd'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('my-info-customer-service-badge')),
      findsOneWidget,
    );
    expect(find.byType(CustomerServiceBadge), findsOneWidget);
  });
}
