import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter previousAdapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.uid': 'u_owner',
      'flutter.token': 'token_owner',
      'flutter.im_token': 'im_token_owner',
    });
    await StorageUtils.init();
    previousAdapter = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = _FriendListAdapter();
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = previousAdapter;
  });

  test('home contacts bootstrap does not open sqflite on web', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        homeShouldPersistContactsLocallyProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(homeContactsBootstrapRefresherProvider).call(),
      completes,
    );
  });

  test('friend list sync ignores local cache and persistence on web', () async {
    var cacheRead = false;
    var persist = false;
    final notifier = FriendListNotifier(
      loadOnInit: false,
      queryCachedFriends: () async {
        cacheRead = true;
        throw StateError('web must not read sqflite cache');
      },
      syncFriends: () async => <Friend>[Friend(uid: 'u_friend', name: '好友')],
      persistFriends: (_) async {
        persist = true;
        throw StateError('web must not persist to sqflite cache');
      },
      useLocalPersistence: false,
    );
    addTearDown(notifier.dispose);

    await notifier.loadFriends();

    expect(cacheRead, isFalse);
    expect(persist, isFalse);
    expect(notifier.state.requireValue.single.uid, 'u_friend');
  });

  test(
    'friend request sync ignores local cache and persistence on web',
    () async {
      var cacheRead = false;
      var persist = false;
      final notifier = FriendRequestListNotifier(
        loadOnInit: false,
        queryCachedRequests: () async {
          cacheRead = true;
          throw StateError('web must not read sqflite request cache');
        },
        syncRequests: () async => <FriendRequest>[
          FriendRequest(
            id: 1,
            fromUid: 'u_friend',
            toUid: 'u_owner',
            status: 0,
          ),
        ],
        persistRequests: (_) async {
          persist = true;
          throw StateError('web must not persist request cache');
        },
        useLocalPersistence: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadRequests();

      expect(cacheRead, isFalse);
      expect(persist, isFalse);
      expect(notifier.state.requireValue.single.fromUid, 'u_friend');
    },
  );
}

class _FriendListAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{
        'code': 0,
        'data': <Map<String, Object>>[
          <String, Object>{'uid': 'u_friend', 'name': '好友'},
        ],
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
