import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/mail_list_contact.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/user_api.dart';

void main() {
  group('UserApi', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('getUserInfo preserves flame and chat password settings from server response', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{
          'uid': 'u_flame_personal_phase6',
          'name': 'Alice',
          'flame': 1,
          'flame_second': 20,
          'chat_pwd': 'stored_chat_pwd_hash',
          'chat_pwd_on': 1,
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final user = await UserApi.instance.getUserInfo(
        'u_flame_personal_phase6',
      );

      expect(
        adapter.lastRequestOptions?.path,
        '${ApiConfig.userInfo}/u_flame_personal_phase6',
      );
      expect(user.flame, 1);
      expect(user.flameSecond, 20);
      expect(user.chatPwd, 'stored_chat_pwd_hash');
      expect(user.chatPwdOn, 1);
    });

    test('updateUserSetting uses PUT /v1/users/:uid/setting', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await UserApi.instance.updateUserSetting(
        'u_flame_personal_phase6',
        'flame_second',
        180,
      );

      expect(
        adapter.lastRequestOptions?.path,
        '${ApiConfig.userInfo}/u_flame_personal_phase6/setting',
      );
      expect(adapter.lastRequestOptions?.method, 'PUT');
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('flame_second', 180),
      );
    });

    test('setChatPassword uses POST /v1/user/chatpwd with hashed chat password and plain login password', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await UserApi.instance.setChatPassword(
        uid: 'u_chat_pwd',
        chatPassword: '654321',
        loginPassword: 'Login@123',
      );

      expect(adapter.lastRequestOptions?.path, ApiConfig.userChatPwd);
      expect(adapter.lastRequestOptions?.method, 'POST');
      expect(
        adapter.lastRequestOptions?.data,
        containsPair(
          'chat_pwd',
          crypto.md5.convert(utf8.encode('654321u_chat_pwd')).toString(),
        ),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('login_pwd', 'Login@123'),
      );
    });

    test('getPcOnlineState reads pc online and mute_of_app payload', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{
          'code': 0,
          'pc': <String, dynamic>{'online': 1, 'mute_of_app': 1},
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final state = await UserApi.instance.getPcOnlineState();

      expect(adapter.lastRequestOptions?.path, '/v1/user/online');
      expect(state.online, 1);
      expect(state.muteOfApp, 1);
      expect(state.isOnline, isTrue);
    });

    test('uploadMailListContacts uses POST /v1/user/maillist', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await UserApi.instance.uploadMailListContacts(const <
        MailListUploadContact
      >[
        MailListUploadContact(name: 'Alice', zone: '', phone: '13800138000'),
        MailListUploadContact(name: 'Bob', zone: '0086', phone: '13900139000'),
      ]);

      expect(adapter.lastRequestOptions?.path, ApiConfig.userMailList);
      expect(adapter.lastRequestOptions?.method, 'POST');
      expect(adapter.lastRequestOptions?.data, const <Map<String, String>>[
        <String, String>{'name': 'Alice', 'zone': '', 'phone': '13800138000'},
        <String, String>{'name': 'Bob', 'zone': '0086', 'phone': '13900139000'},
      ]);
    });

    test(
      'getMailListContacts parses matched contacts from GET /v1/user/maillist',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Alice',
                'zone': '0086',
                'phone': '13800138000',
                'uid': 'u_alice',
                'vercode': 'vc_alice',
                'is_friend': 1,
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final contacts = await UserApi.instance.getMailListContacts();

        expect(adapter.lastRequestOptions?.path, ApiConfig.userMailList);
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(contacts, hasLength(1));
        expect(contacts.single.name, 'Alice');
        expect(contacts.single.zone, '0086');
        expect(contacts.single.phone, '13800138000');
        expect(contacts.single.uid, 'u_alice');
        expect(contacts.single.vercode, 'vc_alice');
        expect(contacts.single.isFriend, isTrue);
      },
    );

    test(
      'getCustomerServices parses customer-service accounts from GET /v1/user/customerservices',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <Map<String, dynamic>>[
            <String, dynamic>{'uid': 'cs_001', 'name': '售后客服'},
          ],
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final services = await UserApi.instance.getCustomerServices();

        expect(
          adapter.lastRequestOptions?.path,
          ApiConfig.userCustomerServices,
        );
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(services, hasLength(1));
        expect(services.single.uid, 'cs_001');
        expect(services.single.name, '售后客服');
      },
    );

    test('sendDestroySmsCode uses POST /v1/user/sms/destroy', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await UserApi.instance.sendDestroySmsCode();

      expect(adapter.lastRequestOptions?.path, ApiConfig.userDestroySms);
      expect(adapter.lastRequestOptions?.method, 'POST');
    });

    test('destroyAccount uses DELETE /v1/user/destroy/:code', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await UserApi.instance.destroyAccount('123456');

      expect(
        adapter.lastRequestOptions?.path,
        ApiConfig.userDestroy('123456'),
      );
      expect(adapter.lastRequestOptions?.method, 'DELETE');
    });
  });
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
