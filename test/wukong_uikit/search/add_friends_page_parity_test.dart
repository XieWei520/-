import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/wukong_uikit/search/add_friends_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  Widget wrapWithAuth(Widget child, {int vipLevel = 1}) {
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

  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'add_friends_page_test_${DateTime.now().microsecondsSinceEpoch}';

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

  testWidgets('add friends page matches Android entry shell', (tester) async {
    var openedSearch = false;

    await tester.pumpWidget(
      wrapWithAuth(
        AddFriendsPage(
          currentShortNo: '10001',
          onOpenSearchUser: () {
            openedSearch = true;
          },
        ),
      ),
    );

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('我的悟空号：'), findsOneWidget);
    expect(find.text('10001'), findsOneWidget);
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('扫描二维码名片'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-friends-search-entry')));
    await tester.pumpAndSettle();

    expect(openedSearch, isTrue);
  });

  testWidgets('add friends page shows Android mail-list entry by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(const AddFriendsPage(currentShortNo: '10001')),
    );

    expect(
      find.byKey(const ValueKey('add-friends-mail-list-entry')),
      findsOneWidget,
    );
  });

  testWidgets('non vip is blocked from opening add-friends search entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(const AddFriendsPage(currentShortNo: '10001'), vipLevel: 0),
    );

    await tester.tap(find.byKey(const ValueKey('add-friends-search-entry')));
    await tester.pumpAndSettle();

    expect(find.text(vipRequiredMessage), findsOneWidget);
    expect(find.text('联系管理员'), findsOneWidget);

    await tester.tap(find.text('联系管理员'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('non vip is blocked from applying friend in search results', (
    tester,
  ) async {
    var applyCallCount = 0;

    await tester.pumpWidget(
      wrapWithAuth(
        SearchUserPage(
          onSearchUsers: (_) async => [
            User(uid: 'u_alice', name: 'Alice', vercode: 'vc_alice'),
          ],
          onLoadLocalChannel: (_, __) async => null,
          onApplyUser: (_, __) async {
            applyCallCount += 1;
          },
        ),
        vipLevel: 0,
      ),
    );

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-user-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(applyCallCount, 0);
    expect(find.text(vipRequiredMessage), findsOneWidget);

    await tester.tap(find.text('联系管理员'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets(
    'search user page uses Android search shell and button enablement',
    (tester) async {
      await tester.pumpWidget(
        wrapWithAuth(
          SearchUserPage(
            onSearchUsers: (_) async => const <User>[],
            onLoadLocalChannel: (_, __) async => null,
          ),
        ),
      );

      final searchButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('search-user-submit')),
      );
      expect(searchButton.onPressed, isNull);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('search-user-submit')),
      );
      expect(enabledButton.onPressed, isNotNull);
    },
  );

  testWidgets('search user page renders user row and apply action', (
    tester,
  ) async {
    var appliedUid = '';
    var openedUid = '';

    await tester.pumpWidget(
      wrapWithAuth(
        SearchUserPage(
          onSearchUsers: (_) async => [
            User(uid: 'u_alice', name: 'Alice', vercode: 'vc_alice'),
          ],
          onLoadLocalChannel: (_, __) async => null,
          onApplyUser: (user, _) async {
            appliedUid = user.uid;
          },
          onOpenUserDetail: (uid) {
            openedUid = uid;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-user-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('申请'), findsOneWidget);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(openedUid, 'u_alice');

    await tester.tap(find.text('申请'));
    await tester.pumpAndSettle();
    expect(appliedUid, 'u_alice');
  });

  testWidgets(
    'search user page shows Android no-data state after empty search',
    (tester) async {
      await tester.pumpWidget(
        wrapWithAuth(
          SearchUserPage(
            onSearchUsers: (_) async => const <User>[],
            onLoadLocalChannel: (_, __) async => null,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-user-submit')));
      await tester.pumpAndSettle();

      expect(find.text('暂无数据'), findsOneWidget);
    },
  );
  testWidgets('search user page auto searches when initialQuery is provided', (
    tester,
  ) async {
    final queries = <String>[];

    await tester.pumpWidget(
      wrapWithAuth(
        SearchUserPage(
          initialQuery: 'alice',
          onSearchUsers: (query) async {
            queries.add(query);
            return <User>[User(uid: 'u_alice', name: 'Alice')];
          },
          onLoadLocalChannel: (_, __) async => null,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(queries, <String>['alice']);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
    'search user page hides apply button when local personal channel already marks the user as a friend',
    (tester) async {
      await tester.pumpWidget(
        wrapWithAuth(
          SearchUserPage(
            onSearchUsers: (_) async => [
              User(uid: 'u_alice', name: 'Alice', vercode: 'vc_alice'),
            ],
            onLoadLocalChannel: (uid, channelType) async {
              if (uid != 'u_alice') {
                return null;
              }
              return WKChannel(uid, channelType)
                ..follow = 1
                ..isDeleted = 0;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-user-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
