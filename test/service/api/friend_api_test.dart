import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/friend_api.dart';

void main() {
  group('FriendApi.updateFriendRemark', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('uses PUT /v1/friend/remark with uid and remark body', () async {
      final adapter = _RemarkContractAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await FriendApi.instance.updateFriendRemark('u_friend_01', '新备注');

      expect(adapter.lastRequestOptions?.method, 'PUT');
      expect(adapter.lastRequestOptions?.path, '/v1/friend/remark');
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('uid', 'u_friend_01'),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('remark', '新备注'),
      );
    });
  });
}

class _RemarkContractAdapter implements HttpClientAdapter {
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;

    final path = options.path;
    final method = options.method.toUpperCase();
    final body = options.data;
    final isExpectedRequest =
        method == 'PUT' &&
        path == '/v1/friend/remark' &&
        body is Map &&
        body['uid'] == 'u_friend_01' &&
        body['remark'] == '新备注';

    final payload = isExpectedRequest
        ? const <String, dynamic>{'code': 0}
        : <String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path body=$body',
          };

    return ResponseBody.fromString(
      jsonEncode(payload),
      isExpectedRequest ? 200 : 404,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
