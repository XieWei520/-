import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_badge.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/file_helper_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_info_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/set_user_remark_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/system_team_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'user_detail_page_test_${DateTime.now().microsecondsSinceEpoch}';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    WKIM.shared.options = wk.Options.newDefault(testUid, 'token');
    await WKDBHelper.shared.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    await StorageUtils.setUid('u_self');
  });

  tearDownAll(() {
    WKDBHelper.shared.close();
  });

  Widget wrapWithApp(
    Widget child, {
    int vipLevel = 1,
    List<Override> overrides = const <Override>[],
  }) {
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
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('user detail page matches Android header avatar and tag labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          initialIsFriendOverride: true,
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            remark: '\u5907\u6ce8Alice',
            shortNo: '1001',
            sourceDesc: '\u624b\u673a\u901a\u8baf\u5f55',
            follow: 1,
          ),
        ),
      ),
    );

    expect(find.text('\u6635\u79f0\uff1a'), findsOneWidget);
    expect(find.text('\u609f\u7a7a\u53f7\uff1a'), findsOneWidget);
    expect(find.text('\u624b\u673a\u901a\u8baf\u5f55'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('user-detail-liquid-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('user-detail-liquid-panel')),
      findsOneWidget,
    );
    expect(find.byType(LiquidGlassPanel), findsAtLeastNWidgets(1));
    expect(find.byType(WKSubPageScaffold), findsNothing);

    final displayName = tester.widget<Text>(find.text('\u5907\u6ce8Alice'));
    expect(displayName.style?.color, LiquidGlassColors.text);
    expect(displayName.style?.color, isNot(WKColors.colorDark));
    final metadataLabel = tester.widget<Text>(find.text('\u6635\u79f0\uff1a'));
    expect(metadataLabel.style?.color, LiquidGlassColors.textSecondary);
    expect(metadataLabel.style?.color, isNot(WKColors.colorDark));
    final metadataValue = tester.widget<Text>(find.text('Alice'));
    expect(metadataValue.style?.color, LiquidGlassColors.text);
    expect(metadataValue.style?.color, isNot(WKColors.colorDark));

    final avatar = tester.widget<WKAvatar>(find.byType(WKAvatar).first);
    expect(avatar.size, 50);
  });

  testWidgets('user detail page shows vip badge near nickname for vip user', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            vipLevel: 1,
          ),
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(VipBadge), findsOneWidget);
  });

  testWidgets('user detail page shows customer service badge near nickname', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            category: 'customerService',
          ),
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(CustomerServiceBadge), findsOneWidget);
    expect(find.text('客服'), findsOneWidget);
  });

  testWidgets(
    'user detail page shows customer service badge near nickname for service account',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'cs_001',
            skipInitialLoad: true,
            initialUserOverride: UserInfo(
              uid: 'cs_001',
              name: 'Support',
              category: 'customerService',
            ),
          ),
        ),
      );

      expect(find.text('Support'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('user-detail-customer-service-badge'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CustomerServiceBadge), findsOneWidget);
    },
  );

  testWidgets(
    'user detail header wraps dense badges without narrow-screen overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'cs_vip_dense',
            skipInitialLoad: true,
            initialUserOverride: UserInfo(
              uid: 'cs_vip_dense',
              name: 'Support account with an extremely long display name',
              category: 'customerService',
              vipLevel: 1,
              sex: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'user detail page shows Android join-group description from server detail',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_alice',
            groupId: 'g_demo',
            skipInitialLoad: true,
            initialIsFriendOverride: true,
            initialUserOverride: UserInfo(
              uid: 'u_alice',
              name: 'Alice',
              follow: 1,
              joinGroupInviteUid: 'u_bob',
              joinGroupInviteName: 'Bob',
              joinGroupTime: '2026-04-01',
            ),
          ),
        ),
      );

      expect(find.text('\u8fdb\u7fa4\u65b9\u5f0f'), findsOneWidget);
      expect(
        find.text('2026-04-01 Bob\u9080\u8bf7\u5165\u7fa4'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'user detail page hides source row when Android source_desc is empty',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_alice',
            skipInitialLoad: true,
            initialIsFriendOverride: true,
            initialUserOverride: UserInfo(uid: 'u_alice', name: 'Alice'),
          ),
        ),
      );

      expect(find.text('\u6765\u6e90'), findsNothing);
    },
  );

  testWidgets('user detail page opens avatar preview on tap', (tester) async {
    var openedImage = '';

    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          onOpenAvatarPreview: (image) {
            openedImage = image;
          },
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            avatar: 'https://example.com/avatar.png',
          ),
        ),
      ),
    );

    await tester.tap(find.byType(WKAvatar).first);
    await tester.pumpAndSettle();

    expect(openedImage, 'https://example.com/avatar.png');
  });

  testWidgets(
    'user detail page shows Android copy menu for name and short number',
    (tester) async {
      var copiedText = '';

      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_alice',
            skipInitialLoad: true,
            onCopyText: (value) {
              copiedText = value;
            },
            initialUserOverride: UserInfo(
              uid: 'u_alice',
              name: 'Alice',
              remark: '\u5907\u6ce8Alice',
              shortNo: '1001',
            ),
          ),
        ),
      );

      await tester.longPress(find.text('\u5907\u6ce8Alice'));
      await tester.pumpAndSettle();
      expect(find.text('\u590d\u5236'), findsOneWidget);
      await tester.tap(find.text('\u590d\u5236'));
      await tester.pumpAndSettle();
      expect(copiedText, '\u5907\u6ce8Alice');

      await tester.longPress(find.text('1001'));
      await tester.pumpAndSettle();
      expect(find.text('\u590d\u5236'), findsOneWidget);
      await tester.tap(find.text('\u590d\u5236'));
      await tester.pumpAndSettle();
      expect(copiedText, '1001');
    },
  );

  testWidgets(
    'user detail page confirms Android blacklist action before toggling',
    (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_alice',
            skipInitialLoad: true,
            onToggleBlacklist: (_) async {
              toggled = true;
            },
            initialIsFriendOverride: true,
            initialUserOverride: UserInfo(
              uid: 'u_alice',
              name: 'Alice',
              follow: 1,
            ),
          ),
        ),
      );

      await tester.tap(find.text('\u52a0\u5165\u9ed1\u540d\u5355'));
      await tester.pumpAndSettle();

      expect(find.text('\u52a0\u5165\u9ed1\u540d\u5355'), findsNWidgets(2));
      expect(
        find.text(
          '\u52a0\u5165\u9ed1\u540d\u5355\u540e\uff0c\u4f60\u5c06\u4e0d\u518d\u63a5\u6536\u5bf9\u65b9\u6d88\u606f\u3002',
        ),
        findsOneWidget,
      );
      expect(toggled, isFalse);

      await tester.tap(find.text('\u786e\u5b9a'));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    },
  );

  testWidgets(
    'user detail page hides apply button when Android vercode is missing',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_alice',
            skipInitialLoad: true,
            initialIsFriendOverride: false,
            initialUserOverride: UserInfo(
              uid: 'u_alice',
              name: 'Alice',
              follow: 0,
            ),
          ),
        ),
      );

      expect(find.text('\u7533\u8bf7\u52a0\u597d\u53cb'), findsNothing);
    },
  );

  testWidgets('non vip is blocked when sending friend request', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          initialIsFriendOverride: false,
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            follow: 0,
            vercode: 'vc_alice',
          ),
        ),
        vipLevel: 0,
      ),
    );

    await tester.tap(find.text('\u7533\u8bf7\u52a0\u597d\u53cb'));
    await tester.pumpAndSettle();

    expect(find.text(vipRequiredMessage), findsOneWidget);

    await tester.tap(find.text('联系管理员'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('user detail page opens Android remark editor page', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        UserDetailPage(
          uid: 'u_alice',
          skipInitialLoad: true,
          initialIsFriendOverride: true,
          initialUserOverride: UserInfo(
            uid: 'u_alice',
            name: 'Alice',
            follow: 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('设置备注'));
    await tester.pumpAndSettle();

    expect(find.byType(SetUserRemarkPage), findsOneWidget);
    expect(find.byKey(const ValueKey('set_user_remark_input')), findsOneWidget);
  });

  testWidgets(
    'user detail page redirects Android file helper account to special page',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const UserDetailPage(uid: 'fileHelper', skipInitialLoad: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FileHelperPage), findsOneWidget);
      expect(find.text('\u6587\u4ef6\u4f20\u8f93\u52a9\u624b'), findsOneWidget);
    },
  );

  testWidgets(
    'user detail page redirects Android system team account to special page',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const UserDetailPage(uid: 'u_10000', skipInitialLoad: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SystemTeamPage), findsOneWidget);
      expect(find.text('\u7cfb\u7edf\u901a\u77e5'), findsOneWidget);
    },
  );

  testWidgets(
    'user detail page redirects current user to Android my info page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await StorageUtils.init();
      await StorageUtils.setUid('u_self');

      await tester.pumpWidget(
        wrapWithApp(
          UserDetailPage(
            uid: 'u_self',
            skipInitialLoad: true,
            initialUserOverride: UserInfo(uid: 'u_self', name: 'Alice'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MyInfoPage), findsOneWidget);
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
