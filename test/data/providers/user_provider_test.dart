import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  group('countPendingFriendRequests', () {
    test('counts only pending requests', () {
      final requests = <FriendRequest>[
        FriendRequest(id: 1, fromUid: 'u1', status: 0),
        FriendRequest(id: 2, fromUid: 'u2', status: 1),
        FriendRequest(id: 3, fromUid: 'u3', status: 2),
        FriendRequest(id: 4, fromUid: 'u4', status: 0),
      ];

      expect(countPendingFriendRequests(requests), 2);
    });
  });

  group('FriendRequestListNotifier.handleRequest', () {
    test('rejects non-pending requests before calling the accept API', () async {
      final adapter = _RecordingJsonAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final notifier = _TestFriendRequestListNotifier(const <FriendRequest>[]);

      final result = await notifier.handleRequest(
        FriendRequest(
          id: 1,
          fromUid: 'u_alice',
          status: 1,
          token: 'already-processed-token',
        ),
        true,
      );

      expect(result.success, isFalse);
      expect(result.shouldRefreshFriends, isFalse);
      expect(
        result.message,
        '\u8be5\u597d\u53cb\u7533\u8bf7\u5df2\u5931\u6548\u6216\u5df2\u5904\u7406',
      );
      expect(adapter.requests, isEmpty);
    });

    test('rejects non-pending requests before calling the refuse API', () async {
      final adapter = _RecordingJsonAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final notifier = _TestFriendRequestListNotifier(const <FriendRequest>[]);

      final result = await notifier.handleRequest(
        FriendRequest(id: 2, fromUid: 'u_bob', status: 2),
        false,
      );

      expect(result.success, isFalse);
      expect(result.shouldRefreshFriends, isFalse);
      expect(
        result.message,
        '\u8be5\u597d\u53cb\u7533\u8bf7\u5df2\u5931\u6548\u6216\u5df2\u5904\u7406',
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

class _TestFriendRequestListNotifier extends FriendRequestListNotifier {
  _TestFriendRequestListNotifier(this._initialRequests) : super();

  final List<FriendRequest> _initialRequests;

  @override
  Future<void> loadRequests() async {
    state = AsyncValue.data(_initialRequests);
  }
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(const <String, dynamic>{}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
