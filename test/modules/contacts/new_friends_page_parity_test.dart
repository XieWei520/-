import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/contacts/contacts_page.dart';
import 'package:wukong_im_app/modules/contacts/contacts_strings.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/widgets/wk_theme.dart';

void main() {
  final strings = resolveContactsStrings();

  Widget wrapWithApp(
    Widget child, {
    List<Override> overrides = const [],
    int vipLevel = 1,
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

  FriendRequest buildPendingRequest() => FriendRequest(
    id: 1,
    fromUid: 'u_alice',
    fromName: 'Alice',
    extra: 'request add friend',
  );

  FriendRequest buildAcceptedRequest() => FriendRequest(
    id: 2,
    fromUid: 'u_bob',
    fromName: 'Bob',
    status: 1,
    extra: 'request add friend',
  );

  FriendRequest buildRejectedRequest() => FriendRequest(
    id: 3,
    fromUid: 'u_carla',
    fromName: 'Carla',
    status: 2,
    extra: 'request add friend',
  );

  testWidgets('new friends page matches Android row actions and status style', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        NewFriendsPage(
          initialRequests: [buildPendingRequest(), buildAcceptedRequest()],
        ),
      ),
    );

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.text(strings.newFriendsTitle), findsOneWidget);
    expect(find.text('\u62d2\u7edd'), findsNothing);
    expect(find.text(strings.approve), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('new-friend-approve-action-u_alice')),
      findsOneWidget,
    );
    expect(find.text(strings.processed), findsOneWidget);
  });

  testWidgets(
    'new friends page keeps approve action visible on Windows with app theme',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: WKTheme.themeData,
            home: NewFriendsPage(initialRequests: [buildPendingRequest()]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(strings.approve), findsOneWidget);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'new friends page marks a request as approved after tapping agree',
    (tester) async {
      String? approvedUid;

      await tester.pumpWidget(
        wrapWithApp(
          NewFriendsPage(
            initialRequests: [buildPendingRequest()],
            onApprove: (request) async {
              approvedUid = request.fromUid;
            },
          ),
        ),
      );

      await tester.tap(find.text(strings.approve));
      await tester.pumpAndSettle();

      expect(approvedUid, 'u_alice');
      expect(find.text(strings.processed), findsOneWidget);
      expect(find.text(strings.approve), findsNothing);
    },
  );

  testWidgets('new friends page deletes a request from the long-press menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(NewFriendsPage(initialRequests: [buildPendingRequest()])),
    );

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('new friends page opens accepted user detail on tap', (
    tester,
  ) async {
    String? openedUid;

    await tester.pumpWidget(
      wrapWithApp(
        NewFriendsPage(
          initialRequests: [buildAcceptedRequest()],
          onOpenUserDetail: (uid) {
            openedUid = uid;
          },
        ),
      ),
    );

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(openedUid, 'u_bob');
  });

  testWidgets(
    'new friends page treats rejected requests as processed and non-navigable',
    (tester) async {
      String? openedUid;

      await tester.pumpWidget(
        wrapWithApp(
          NewFriendsPage(
            initialRequests: [buildRejectedRequest()],
            onOpenUserDetail: (uid) {
              openedUid = uid;
            },
          ),
        ),
      );

      expect(find.text(strings.approve), findsNothing);
      expect(find.text(strings.processed), findsOneWidget);

      await tester.tap(find.text('Carla'));
      await tester.pumpAndSettle();

      expect(openedUid, isNull);
    },
  );

  testWidgets(
    'new friends page normalizes pending requests to accepted when already friends',
    (tester) async {
      String? openedUid;

      await tester.pumpWidget(
        wrapWithApp(
          NewFriendsPage(
            initialRequests: [buildPendingRequest()],
            onOpenUserDetail: (uid) {
              openedUid = uid;
            },
          ),
          overrides: [
            friendListProvider.overrideWith(
              (ref) => _TestFriendListNotifier([
                Friend(uid: 'u_alice', name: 'Alice'),
              ]),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text(strings.approve), findsNothing);
      expect(find.text(strings.processed), findsOneWidget);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(openedUid, 'u_alice');
    },
  );

  testWidgets(
    'new friends page keeps pending requests non-actionable until friend relation resolves',
    (tester) async {
      final friendNotifier = _ControlledFriendListNotifier();
      String? approvedUid;

      await tester.pumpWidget(
        wrapWithApp(
          NewFriendsPage(
            initialRequests: [buildPendingRequest()],
            onApprove: (request) async {
              approvedUid = request.fromUid;
            },
          ),
          overrides: [friendListProvider.overrideWith((ref) => friendNotifier)],
        ),
      );
      await tester.pump();

      final loadingAction = tester.widget<InkWell>(
        find.byKey(
          const ValueKey<String>('new-friend-approve-action-u_alice'),
        ),
      );
      expect(loadingAction.onTap, isNull);
      expect(approvedUid, isNull);

      friendNotifier.emit([Friend(uid: 'u_alice', name: 'Alice')]);
      await tester.pump();

      expect(find.text(strings.approve), findsNothing);
      expect(find.text(strings.processed), findsOneWidget);
    },
  );

  testWidgets('new friends page blocks non vip add-friend entry', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        NewFriendsPage(initialRequests: [buildPendingRequest()]),
        vipLevel: 0,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('new-friends-add-friend-entry')));
    await tester.pumpAndSettle();

    expect(find.text(vipRequiredMessage), findsOneWidget);
    expect(find.text('联系管理员'), findsOneWidget);
  });
}

class _TestFriendListNotifier extends FriendListNotifier {
  _TestFriendListNotifier(this._friends) : super();

  final List<Friend> _friends;

  @override
  Future<void> loadFriends() async {
    state = AsyncValue.data(_friends);
  }
}

class _ControlledFriendListNotifier extends FriendListNotifier {
  @override
  Future<void> loadFriends() async {}

  void emit(List<Friend> friends) {
    state = AsyncValue.data(friends);
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
