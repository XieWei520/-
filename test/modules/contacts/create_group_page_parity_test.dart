import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/contacts/create_group_page.dart';
import 'package:wukong_im_app/modules/contacts/contacts_strings.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'create_group_page_test_${DateTime.now().microsecondsSinceEpoch}';
  final strings = resolveContactsStrings();

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

  Widget wrapWithAuth({
    required Widget child,
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

  List<Friend> buildFriends() => [
    Friend(uid: 'u_alice', name: 'Alice'),
    Friend(uid: 'u_bob', name: 'Bob'),
    Friend(uid: 'u_chen', name: '陈晨'),
  ];

  testWidgets('create group page uses Android choose-contacts shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(child: CreateGroupPage(initialFriends: buildFriends())),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text(strings.selectContactsTitle), findsOneWidget);
    expect(find.text('群名称'), findsNothing);
    expect(find.textContaining(strings.confirm), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(strings.searchPlaceholder), findsOneWidget);
    expect(find.text('A'), findsAtLeastNWidgets(1));
    expect(find.text('B'), findsAtLeastNWidgets(1));
  });

  testWidgets('create group page shows selected count and selected chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAuth(child: CreateGroupPage(initialFriends: buildFriends())),
    );

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text(strings.confirmWithCount(1)), findsOneWidget);
    expect(find.text('Alice'), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'create group page widens the search field on desktop after selecting a contact',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1366, 900));

      await tester.pumpWidget(
        wrapWithAuth(child: CreateGroupPage(initialFriends: buildFriends())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(TextField)).width, greaterThan(180));
    },
  );

  testWidgets(
    'create group page opens a personal chat when one contact is selected',
    (tester) async {
      Friend? openedFriend;

      await tester.pumpWidget(
        wrapWithAuth(
          child: CreateGroupPage(
            initialFriends: buildFriends(),
            onOpenSingleChat: (friend) async {
              openedFriend = friend;
            },
          ),
          vipLevel: 0,
        ),
      );

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.confirmWithCount(1)));
      await tester.pumpAndSettle();

      expect(openedFriend?.uid, 'u_alice');
    },
  );

  testWidgets('non vip is blocked when creating a group from submit', (
    tester,
  ) async {
    var createGroupCalls = 0;

    await tester.pumpWidget(
      wrapWithAuth(
        child: CreateGroupPage(
          initialFriends: buildFriends(),
          onCreateGroup: (_) async {
            createGroupCalls += 1;
            throw StateError('should not create group');
          },
        ),
        vipLevel: 0,
      ),
    );

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.confirmWithCount(2)));
    await tester.pumpAndSettle();

    expect(createGroupCalls, 0);
    expect(find.text(vipRequiredMessage), findsOneWidget);

    await tester.tap(find.text('联系管理员'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets(
    'create group page uses contacts load failed wording from resources',
    (tester) async {
      await tester.pumpWidget(
        wrapWithAuth(
          child: const CreateGroupPage(),
          overrides: [
            friendListProvider.overrideWith(
              (ref) => _ErrorFriendListNotifier(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text(strings.contactsLoadFailedMessage(StateError('boom'))),
        findsOneWidget,
      );
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}

class _ErrorFriendListNotifier extends FriendListNotifier {
  @override
  Future<void> loadFriends() async {
    state = AsyncValue.error(StateError('boom'), StackTrace.empty);
  }
}
