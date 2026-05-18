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
import 'package:wukong_im_app/service/api/user_api.dart';
import 'package:wukong_im_app/service/mail_list/mail_list_service.dart';
import 'package:wukong_im_app/wukong_uikit/search/add_friends_page.dart';
import 'package:wukong_im_app/wukong_uikit/search/mail_list_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'mail_list_page_test_${DateTime.now().microsecondsSinceEpoch}';

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

  Finder findSectionLetter(String letter) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == letter &&
          widget.style?.fontSize == 18,
    );
  }

  testWidgets('mail list page matches Android search shell and row states', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(
        MailListPage(
          initialContacts: const [
            MailListContact(
              name: 'Alice',
              phone: '13800138000',
              uid: 'u_alice',
              isFriend: true,
            ),
            MailListContact(
              name: 'Berta',
              phone: '13900139000',
              uid: 'u_berta',
            ),
            MailListContact(name: 'Cindy', phone: '13700137000'),
          ],
        ),
      ),
    );

    expect(find.text('手机联系人'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('13800138000'), findsOneWidget);
    expect(find.text('已添加'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('邀请用户'), findsOneWidget);
    expect(find.text('未注册联系人'), findsOneWidget);
    expect(findSectionLetter('A'), findsOneWidget);
    expect(findSectionLetter('B'), findsOneWidget);
    expect(findSectionLetter('C'), findsOneWidget);
  });

  testWidgets('mail list page filters by name and phone like Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(
        MailListPage(
          initialContacts: const [
            MailListContact(name: 'Alice', phone: '13800138000'),
            MailListContact(name: 'Berta', phone: '13900139000'),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '9000');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('Berta'), findsOneWidget);
  });

  testWidgets(
    'mail list page loads from default loader when callback is omitted',
    (tester) async {
      final loader = _FakeMailListLoader(
        result: const <MailListContact>[
          MailListContact(name: 'Alice', phone: '13800138000'),
        ],
      );

      await tester.pumpWidget(
        wrapWithAuth(MailListPage(mailListLoader: loader)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(loader.loadCount, 1);
      expect(find.text('Alice'), findsOneWidget);
    },
  );

  testWidgets('mail list page shows load failure from default loader', (
    tester,
  ) async {
    final loader = _FakeMailListLoader(error: Exception('load failed'));

    await tester.pumpWidget(wrapWithAuth(MailListPage(mailListLoader: loader)));

    await tester.pumpAndSettle();

    expect(find.textContaining('load failed'), findsOneWidget);
  });

  testWidgets('mail list page triggers Android add and invite actions', (
    tester,
  ) async {
    var appliedUid = '';
    var invitedPhone = '';

    await tester.pumpWidget(
      wrapWithAuth(
        MailListPage(
          initialContacts: const [
            MailListContact(
              name: 'Alice',
              phone: '13800138000',
              uid: 'u_alice',
              vercode: 'vc_alice',
            ),
            MailListContact(name: 'Cindy', phone: '13700137000'),
          ],
          onApplyContact: (contact, _) async {
            appliedUid = contact.uid ?? '';
          },
          onInviteContact: (contact) async {
            invitedPhone = contact.phone;
          },
        ),
      ),
    );

    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();
    expect(appliedUid, 'u_alice');

    await tester.tap(find.text('邀请用户'));
    await tester.pumpAndSettle();
    expect(invitedPhone, '13700137000');
  });

  testWidgets('non vip is blocked from adding friend in mail list', (
    tester,
  ) async {
    var applyCallCount = 0;

    await tester.pumpWidget(
      wrapWithAuth(
        MailListPage(
          initialContacts: const [
            MailListContact(
              name: 'Alice',
              phone: '13800138000',
              uid: 'u_alice',
              vercode: 'vc_alice',
            ),
          ],
          onApplyContact: (_, _) async {
            applyCallCount += 1;
          },
          vipCustomerServicesLoader: _fakeCustomerServicesLoader,
        ),
        vipLevel: 0,
      ),
    );

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    expect(applyCallCount, 0);
    expect(find.text(vipRequiredMessage), findsOneWidget);

    await tester.tap(find.text('联系管理员'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('add friends page opens mail list page from Android entry row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(
        Builder(
          builder: (context) {
            return AddFriendsPage(
              showMailList: true,
              vipCustomerServicesLoader: _fakeCustomerServicesLoader,
              onOpenMailList: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MailListPage(
                      initialContacts: const <MailListContact>[],
                      vipCustomerServicesLoader: _fakeCustomerServicesLoader,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    expect(find.text('手机联系人'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-friends-mail-list-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(MailListPage), findsOneWidget);
  });
}

Future<List<CustomerServiceAccount>> _fakeCustomerServicesLoader() async {
  return const <CustomerServiceAccount>[
    CustomerServiceAccount(uid: 'cs_test', name: 'Test CS'),
  ];
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}

class _FakeMailListLoader implements MailListLoader {
  _FakeMailListLoader({this.result = const <MailListContact>[], this.error});

  final List<MailListContact> result;
  final Object? error;
  int loadCount = 0;

  @override
  Future<List<MailListContact>> loadContacts() async {
    loadCount += 1;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}
