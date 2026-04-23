import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/im_config.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/contacts/contacts_directory_controller.dart';
import 'package:wukong_im_app/modules/contacts/contacts_page.dart';
import 'package:wukong_im_app/modules/contacts/contacts_presence_controller.dart';
import 'package:wukong_im_app/modules/contacts/widgets/contacts_alphabet_index.dart';
import 'package:wukong_im_app/modules/contacts/widgets/contacts_list_viewport.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/user_api.dart';
import 'package:wukong_im_app/widgets/wk_main_top_bar.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/contacts_menu.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

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

  testWidgets('contacts page uses Android default header entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: const AsyncValue.data(<Friend>[]),
          requestsStateOverride: AsyncValue.data([
            FriendRequest(id: 1, fromUid: 'u_1', status: 0),
            FriendRequest(id: 2, fromUid: 'u_2', status: 0),
          ]),
        ),
      ),
    );

    expect(find.text('\u65b0\u670b\u53cb'), findsOneWidget);
    expect(find.text('\u4fdd\u5b58\u7684\u7fa4\u804a'), findsOneWidget);
    expect(find.text('\u670b\u53cb\u5708'), findsOneWidget);
    expect(find.text('\u6807\u7b7e'), findsOneWidget);
    expect(find.text('\u5ba2\u670d'), findsOneWidget);
    expect(find.byTooltip('\u641c\u7d22'), findsOneWidget);
    expect(find.text('\u9ed1\u540d\u5355\u7ba1\u7406'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('contacts page routes Android extension headers', (tester) async {
    var openedMoments = false;
    var openedTags = false;
    var openedCustomerService = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ContactsPage(
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            onOpenMomentsPage: () {
              openedMoments = true;
            },
            onOpenTagManagePage: () {
              openedTags = true;
            },
            onOpenCustomerService: () {
              openedCustomerService = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('contacts-header-moments')));
    await tester.pumpAndSettle();
    expect(openedMoments, isTrue);

    await tester.tap(find.byKey(const ValueKey('contacts-header-tag')));
    await tester.pumpAndSettle();
    expect(openedTags, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('contacts-header-customer_service')),
    );
    await tester.pumpAndSettle();
    expect(openedCustomerService, isTrue);
  });

  testWidgets(
    'contacts page loads the first customer-service account from the API',
    (tester) async {
      final adapter = _RecordingJsonAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'cs_001', 'name': '售后客服'},
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      CustomerServiceAccount? openedService;

      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            onOpenResolvedCustomerService: (service) {
              openedService = service;
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('contacts-header-customer_service')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(adapter.lastRequestOptions?.path, '/v1/user/customerservices');
      expect(adapter.lastRequestOptions?.method, 'GET');
      expect(openedService?.uid, 'cs_001');
      expect(openedService?.name, '售后客服');
    },
  );

  testWidgets('contacts page renders Android-style custom header menu rows', (
    tester,
  ) async {
    var tappedSid = '';

    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          headerMenus: [
            ContactsMenu(
              sid: 'org',
              imgResource: WKReferenceAssets.newFriend,
              text: '\u7ec4\u7ec7\u67b6\u6784',
              uid: 'u_org',
              showRedDot: true,
              onClick: (sid) {
                tappedSid = sid;
              },
            ),
          ],
          friendsStateOverride: const AsyncValue.data(<Friend>[]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
        ),
      ),
    );

    expect(find.text('\u7ec4\u7ec7\u67b6\u6784'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contacts-header-dot-org')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('contacts-header-org')));
    await tester.pumpAndSettle();

    expect(tappedSid, 'org');
  });

  testWidgets(
    'contacts page does not show header red dot when custom uid menu disables it',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            headerMenus: [
              ContactsMenu(
                sid: 'org',
                imgResource: WKReferenceAssets.newFriend,
                text: '\u7ec4\u7ec7\u67b6\u6784',
                uid: 'u_org',
                showRedDot: false,
              ),
            ],
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          ),
        ),
      );

      expect(find.text('\u7ec4\u7ec7\u67b6\u6784'), findsOneWidget);
      expect(find.byKey(const ValueKey('contacts-header-org')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contacts-header-dot-org')),
        findsNothing,
      );
    },
  );

  testWidgets('contacts page shows Android long-press contact menu', (
    tester,
  ) async {
    var openedChatUid = '';
    var remarkUid = '';

    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(uid: 'u_alice', name: 'Alice'),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          onOpenContactChat: (uid) {
            openedChatUid = uid;
          },
          onSetContactRemark: (uid) {
            remarkUid = uid;
          },
        ),
      ),
    );

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('\u8bbe\u7f6e\u5907\u6ce8'), findsOneWidget);
    expect(find.text('\u53d1\u6d88\u606f'), findsOneWidget);

    await tester.tap(find.text('\u53d1\u6d88\u606f'));
    await tester.pumpAndSettle();
    expect(openedChatUid, 'u_alice');

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u8bbe\u7f6e\u5907\u6ce8'));
    await tester.pumpAndSettle();
    expect(remarkUid, 'u_alice');
  });

  testWidgets('contacts page shows Android online subtitle and avatar dot', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(uid: 'u_alice', name: 'Alice'),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          contactPresenceOverrides: const {
            'u_alice': ContactPresenceState(
              online: true,
              deviceFlag: IMConfig.deviceFlagWeb,
            ),
          },
        ),
      ),
    );

    expect(find.text('Web\u5728\u7ebf'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contacts-avatar-dot-u_alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('contacts-avatar-badge-u_alice')),
      findsNothing,
    );
  });

  testWidgets('contacts page shows Android recent-offline avatar badge', (
    tester,
  ) async {
    final nowSeconds = DateTime(2026, 4, 1, 12).millisecondsSinceEpoch ~/ 1000;

    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(uid: 'u_alice', name: 'Alice'),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          currentTimestampSecondsOverride: nowSeconds,
          contactPresenceOverrides: {
            'u_alice': ContactPresenceState(
              online: false,
              lastOffline: nowSeconds - (5 * 60),
            ),
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('contacts-avatar-badge-u_alice')),
      findsOneWidget,
    );
    expect(find.text('\u0035\u5206\u949f'), findsOneWidget);
    expect(
      find.textContaining('\u4e0a\u6b21\u5728\u7ebf\u65f6\u95f4'),
      findsNothing,
    );
  });

  testWidgets(
    'contacts page shows Android last-seen subtitle for stale offline contacts',
    (tester) async {
      final nowSeconds =
          DateTime(2026, 4, 1, 12).millisecondsSinceEpoch ~/ 1000;

      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            friendsStateOverride: AsyncValue.data([
              Friend(uid: 'u_alice', name: 'Alice'),
            ]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            currentTimestampSecondsOverride: nowSeconds,
            contactPresenceOverrides: {
              'u_alice': ContactPresenceState(
                online: false,
                lastOffline: nowSeconds - (61 * 60),
              ),
            },
          ),
        ),
      );

      expect(
        find.text('\u4e0a\u6b21\u5728\u7ebf\u65f6\u95f4 04-01 10:59'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contacts-avatar-dot-u_alice')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('contacts-avatar-badge-u_alice')),
        findsNothing,
      );
    },
  );

  testWidgets('contacts page shows Android robot tag label', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(
              uid: 'u_robot',
              name: 'Robot User',
              category: 'system',
              robot: 1,
            ),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
        ),
      ),
    );

    expect(find.text('官方'), findsOneWidget);
    expect(find.text('机器人'), findsOneWidget);
    expect(find.text('Bot'), findsNothing);
  });

  testWidgets('contacts page shows vip badge beside vip contact name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend.fromJson({
              'uid': 'u_vip',
              'name': 'VIP Alice',
              'vip_level': 1,
            }),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          contactPresenceOverrides: const {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('contacts-vip-badge-u_vip')),
      findsOneWidget,
    );
    expect(find.text('VIP商家'), findsOneWidget);
  });

  testWidgets('contacts page composes extracted viewport widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(uid: 'u_alice', name: 'Alice'),
          ]),
          requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          contactPresenceOverrides: const {},
        ),
      ),
    );

    expect(find.byType(ContactsListViewport), findsOneWidget);
    expect(find.byType(ContactsAlphabetIndex), findsOneWidget);
  });

  testWidgets(
    'contacts page local state changes do not rerun directory mapping',
    (tester) async {
      final controller = _CountingContactsDirectoryController();
      final harnessKey = GlobalKey<_PresenceOverrideHarnessState>();

      await tester.pumpWidget(
        wrapWithApp(
          _PresenceOverrideHarness(
            key: harnessKey,
            builder: (presenceOverrides) {
              return ContactsPage(
                friendsStateOverride: AsyncValue.data([
                  Friend(uid: 'u_alice', name: 'Alice'),
                  Friend(uid: 'u_bob', name: 'Bob'),
                ]),
                requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
                contactPresenceOverrides: presenceOverrides,
              );
            },
          ),
          overrides: [
            contactsDirectoryControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
        ),
      );

      expect(controller.buildCount, 1);

      harnessKey.currentState!.updatePresence(const {
        'u_alice': ContactPresenceState(online: true),
      });
      await tester.pump();

      expect(controller.buildCount, 1);
    },
  );

  testWidgets('friend request badge updates do not rerun directory mapping', (
    tester,
  ) async {
    final controller = _CountingContactsDirectoryController();
    final requestNotifier = _TestFriendRequestListNotifier(
      const <FriendRequest>[],
    );

    await tester.pumpWidget(
      wrapWithApp(
        ContactsPage(
          friendsStateOverride: AsyncValue.data([
            Friend(uid: 'u_alice', name: 'Alice'),
            Friend(uid: 'u_bob', name: 'Bob'),
          ]),
          contactPresenceOverrides: const {},
        ),
        overrides: [
          contactsDirectoryControllerProvider.overrideWith((ref) => controller),
          friendRequestListProvider.overrideWith((ref) => requestNotifier),
        ],
      ),
    );

    expect(controller.buildCount, 1);

    requestNotifier.emit([FriendRequest(id: 1, fromUid: 'u_1', status: 0)]);
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(controller.buildCount, 1);
  });

  test('contacts surface reliability follows async friend state', () {
    expect(
      resolveContactsSurfaceReliability(
        const AsyncValue<List<Friend>>.loading(),
      ),
      SurfaceReliabilityState.stale,
    );
    expect(
      resolveContactsSurfaceReliability(
        AsyncValue<List<Friend>>.error(StateError('boom'), StackTrace.empty),
      ),
      SurfaceReliabilityState.degraded,
    );
    expect(
      resolveContactsSurfaceReliability(
        const AsyncValue<List<Friend>>.data(<Friend>[]),
      ),
      SurfaceReliabilityState.healthy,
    );
  });

  testWidgets(
    'contacts page blocks non vip add-friend and create-group menu entries',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
          ),
          vipLevel: 0,
        ),
      );

      await tester.tap(find.byType(WKTopBarActionButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();

      expect(find.text(vipRequiredMessage), findsOneWidget);
      expect(find.text('联系管理员'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WKTopBarActionButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      expect(find.text(vipRequiredMessage), findsOneWidget);
      expect(find.text('联系管理员'), findsOneWidget);
    },
  );
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CountingContactsDirectoryController extends ContactsDirectoryController {
  int buildCount = 0;

  @override
  ContactsDirectoryData buildDirectory(List<Friend> friends) {
    buildCount++;
    return super.buildDirectory(friends);
  }
}

class _TestFriendRequestListNotifier extends FriendRequestListNotifier {
  _TestFriendRequestListNotifier(this._initialRequests) : super();

  final List<FriendRequest> _initialRequests;

  @override
  Future<void> loadRequests() async {
    state = AsyncValue.data(_initialRequests);
  }

  void emit(List<FriendRequest> requests) {
    state = AsyncValue.data(requests);
  }
}

class _PresenceOverrideHarness extends StatefulWidget {
  const _PresenceOverrideHarness({super.key, required this.builder});

  final Widget Function(Map<String, ContactPresenceState> presenceOverrides)
  builder;

  @override
  State<_PresenceOverrideHarness> createState() =>
      _PresenceOverrideHarnessState();
}

class _PresenceOverrideHarnessState extends State<_PresenceOverrideHarness> {
  Map<String, ContactPresenceState> _presenceOverrides = const {};

  void updatePresence(Map<String, ContactPresenceState> presenceOverrides) {
    setState(() {
      _presenceOverrides = presenceOverrides;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_presenceOverrides);
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
