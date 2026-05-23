import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/group_api.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/conversation.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid = 'group_api_test_uid_${DateTime.now().microsecondsSinceEpoch}';

  group('GroupApi contract', () {
    late HttpClientAdapter originalAdapter;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      WKIM.shared.options = wk.Options.newDefault(testUid, 'token');
      await WKDBHelper.shared.init();
    });

    setUp(() async {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      await _clearImTables();
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    tearDownAll(() {
      WKDBHelper.shared.close();
    });

    test(
      'createGroup posts member_names when display names are provided',
      () async {
        const groupNo = 'g_create_group_member_names';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'POST' && path == ApiConfig.groupCreate) {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(groupNo, name: 'Named Group', save: 1),
            });
          }
          if (method == 'PUT' &&
              path == '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}') {
            return _MockJsonResponse(const <String, dynamic>{'code': 0});
          }
          if (method == 'GET' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(groupNo, name: 'Named Group', save: 1),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic api = GroupApi.instance;
        await api.createGroup(
          const <String>['u-1', 'u-2'],
          memberNames: const <String>['test3', 'test4'],
        );

        final createRequest = adapter.requests.firstWhere(
          (request) =>
              request.method.toUpperCase() == 'POST' &&
              request.uri.path == ApiConfig.groupCreate,
        );

        expect(
          createRequest.data,
          containsPair('member_names', <String>['test3', 'test4']),
        );
        expect(
          createRequest.data,
          containsPair('names', <String>['test3', 'test4']),
        );
      },
    );

    test(
      'addGroupMembers posts names when display names are provided',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic api = GroupApi.instance;
        await api.addGroupMembers(
          'g-10001',
          const <String>['u-1', 'u-2'],
          memberNames: const <String>['test4', 'test5'],
        );

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupMembers}',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('names', <String>['test4', 'test5']),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('member_names', <String>['test4', 'test5']),
        );
      },
    );

    test(
      'getGroupMembers requests the full member list instead of backend default page size',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'code': 0,
            'data': List<Map<String, dynamic>>.generate(
              101,
              (index) => <String, dynamic>{
                'group_no': 'g-10001',
                'uid': 'u-${index + 1}',
                'name': 'Member ${index + 1}',
                'role': 0,
                'status': 1,
                'is_deleted': 0,
              },
            ),
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final members = await GroupApi.instance.getGroupMembers('g-10001');

        expect(members, hasLength(101));
        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupMembers}',
        );
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('page', 1),
        );
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('limit', 100000),
        );
      },
    );

    test(
      'getMyGroups does not resurrect local-only conversations when server no longer returns the group',
      () async {
        const serverGroupNo = 'g_server_only_phase3';
        const removedGroupNo = 'g_removed_local_phase3';
        await _seedLocalGroupConversation(removedGroupNo);

        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == ApiConfig.groupMy) {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <Map<String, dynamic>>[
                _buildGroupJson(serverGroupNo, name: 'Server Group', save: 1),
              ],
            });
          }
          if (method == 'GET' && path == '${ApiConfig.groups}/$serverGroupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(
                serverGroupNo,
                name: 'Server Group',
                save: 1,
              ),
            });
          }
          if (method == 'GET' &&
              path == '${ApiConfig.groups}/$removedGroupNo') {
            return _MockJsonResponse(const <String, dynamic>{
              'code': 1,
              'msg': 'group not found',
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final groups = await GroupApi.instance.getMyGroups();

        expect(groups.map((group) => group.groupNo).toList(), const <String>[
          serverGroupNo,
        ]);
      },
    );

    test(
      'getMyGroups caches real server save state instead of forcing save=1',
      () async {
        const groupNo = 'g_save_zero_from_my_phase3';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == ApiConfig.groupMy) {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <Map<String, dynamic>>[
                _buildGroupJson(groupNo, name: 'Muted Save Group', save: 0),
              ],
            });
          }
          if (method == 'GET' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(
                groupNo,
                name: 'Muted Save Group',
                save: 0,
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final groups = await GroupApi.instance.getMyGroups();
        final channel = await WKIM.shared.channelManager.getChannel(
          groupNo,
          WKChannelType.group,
        );

        expect(groups, hasLength(1));
        expect(groups.single.save, 0);
        expect(channel, isNotNull);
        expect(channel!.save, 0);
      },
    );

    test(
      'getGroupInfo caches real server save state instead of forcing save=1',
      () async {
        const groupNo = 'g_save_zero_from_info_phase3';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(
                groupNo,
                name: 'Info Save Group',
                save: 0,
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final group = await GroupApi.instance.getGroupInfo(groupNo);
        final channel = await WKIM.shared.channelManager.getChannel(
          groupNo,
          WKChannelType.group,
        );

        expect(group.save, 0);
        expect(channel, isNotNull);
        expect(channel!.save, 0);
      },
    );

    test(
      'getGroupInfo caches flame settings into channel remote extras',
      () async {
        const groupNo = 'g_flame_channel_cache_phase6';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(
                groupNo,
                name: 'Flame Cache Group',
                save: 1,
                flame: 1,
                flameSecond: 30,
                chatPwdOn: 1,
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final group = await GroupApi.instance.getGroupInfo(groupNo);
        final channel = await WKIM.shared.channelManager.getChannel(
          groupNo,
          WKChannelType.group,
        );

        expect(group.flame, 1);
        expect(group.flameSecond, 30);
        expect(channel, isNotNull);
        expect(channel!.remoteExtraMap, isA<Map>());
        expect(channel.remoteExtraMap['flame'], 1);
        expect(channel.remoteExtraMap['flame_second'], 30);
        expect(channel.remoteExtraMap['chat_pwd_on'], 1);
      },
    );

    test(
      'uploadGroupAvatar persists returned avatar url on group info endpoint',
      () async {
        const groupNo = 'g_avatar_upload_persist';
        final tempDir = await Directory.systemTemp.createTemp(
          'wukong_group_avatar_test_',
        );
        addTearDown(() async {
          try {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          } catch (_) {
            // Windows can keep MultipartFile handles open briefly after a
            // failed RED run; cleanup is best-effort for this temp directory.
          }
        });
        final avatarFile = File('${tempDir.path}/avatar.png');
        await avatarFile.writeAsBytes(const <int>[1, 2, 3, 4]);

        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'POST' &&
              path == '${ApiConfig.groups}/$groupNo/avatar') {
            return _MockJsonResponse(const <String, dynamic>{
              'code': 0,
              'data': <String, dynamic>{
                'avatar': 'groups/g_avatar_upload_persist/avatar.png',
              },
            });
          }
          if (method == 'PUT' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(const <String, dynamic>{'code': 0});
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final avatar = await GroupApi.instance.uploadGroupAvatar(
          groupNo,
          avatarFile.path,
        );

        expect(avatar, 'groups/g_avatar_upload_persist/avatar.png');
        final updateRequest = adapter.requests.firstWhere(
          (request) =>
              request.method.toUpperCase() == 'PUT' &&
              request.uri.path == '${ApiConfig.groups}/$groupNo',
        );
        expect(
          updateRequest.data,
          containsPair('avatar', 'groups/g_avatar_upload_persist/avatar.png'),
        );
      },
    );

    test(
      'uploadGroupAvatar persists canonical avatar url when upload response has no avatar',
      () async {
        const groupNo = 'g_avatar_upload_code_only';
        final tempDir = await Directory.systemTemp.createTemp(
          'wukong_group_avatar_empty_response_test_',
        );
        addTearDown(() async {
          try {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          } catch (_) {}
        });
        final avatarFile = File('${tempDir.path}/avatar.png');
        await avatarFile.writeAsBytes(const <int>[5, 6, 7, 8]);

        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'POST' &&
              path == '${ApiConfig.groups}/$groupNo/avatar') {
            return _MockJsonResponse(const <String, dynamic>{'code': 0});
          }
          if (method == 'PUT' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(const <String, dynamic>{'code': 0});
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final avatar = await GroupApi.instance.uploadGroupAvatar(
          groupNo,
          avatarFile.path,
        );

        expect(avatar, contains('/v1/groups/$groupNo/avatar'));
        expect(avatar, contains('t='));
        final updateRequest = adapter.requests.firstWhere(
          (request) =>
              request.method.toUpperCase() == 'PUT' &&
              request.uri.path == '${ApiConfig.groups}/$groupNo',
        );
        expect(
          updateRequest.data,
          containsPair(
            'avatar',
            allOf(
              contains('/v1/groups/$groupNo/avatar'),
              isNot(contains('t=')),
            ),
          ),
        );
      },
    );

    test(
      'inviteMembers uses POST /v1/groups/:group_no/member/invite',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.inviteMembers('g-10001', const <String>['u-1']);

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001/member/invite',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('uids', <String>['u-1']),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('member_ids', <String>['u-1']),
        );
      },
    );

    test(
      'setGroupInviteMode uses PUT /v1/groups/:group_no/setting with invite toggle',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.setGroupInviteMode('g-10001', true);

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupSetting}',
        );
        expect(adapter.lastRequestOptions?.method, 'PUT');
        expect(adapter.lastRequestOptions?.data, containsPair('invite', 1));
      },
    );

    test(
      'setGroupJoinGroupRemind uses PUT /v1/groups/:group_no/setting with join_group_remind toggle',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.setGroupJoinGroupRemind('g-10001', false);

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupSetting}',
        );
        expect(adapter.lastRequestOptions?.method, 'PUT');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('join_group_remind', 0),
        );
      },
    );

    test(
      'setGroupAllowViewHistory uses PUT /v1/groups/:group_no/setting with allow_view_history_msg toggle',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.setGroupAllowViewHistory('g-10001', true);

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupSetting}',
        );
        expect(adapter.lastRequestOptions?.method, 'PUT');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('allow_view_history_msg', 1),
        );
      },
    );

    test(
      'getGroupInfo parses allow_member_pinned_message from server response',
      () async {
        const groupNo = 'g_member_pinned_setting';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == '${ApiConfig.groups}/$groupNo') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildGroupJson(
                groupNo,
                name: 'Pinned Setting Group',
                save: 1,
                allowMemberPinnedMessage: 1,
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic group = await GroupApi.instance.getGroupInfo(groupNo);

        expect(group.allowMemberPinnedMessage, 1);
      },
    );

    test(
      'setGroupAllowMemberPinnedMessage uses PUT /v1/groups/:group_no/setting with allow_member_pinned_message toggle',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic api = GroupApi.instance;
        await api.setGroupAllowMemberPinnedMessage('g-10001', true);

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001${ApiConfig.groupSetting}',
        );
        expect(adapter.lastRequestOptions?.method, 'PUT');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('allow_member_pinned_message', 1),
        );
      },
    );

    test(
      'scanJoinGroup uses GET /v1/groups/:group_no/scanjoin with auth_code query',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.scanJoinGroup('g-10001', 'auth-123');

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001/scanjoin',
        );
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('auth_code', 'auth-123'),
        );
      },
    );

    test(
      'getForbiddenTimes uses GET /v1/group/forbidden_times and parses options',
      () async {
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'GET' && path == '/v1/group/forbidden_times') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <Map<String, dynamic>>[
                <String, dynamic>{'text': '1 minute', 'key': 1},
                <String, dynamic>{'text': '1 hour', 'key': 3},
              ],
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final options = await GroupApi.instance.getForbiddenTimes();

        expect(options.map((option) => option.key).toList(), <int>[1, 3]);
        expect(options.map((option) => option.text).toList(), <String>[
          '1 minute',
          '1 hour',
        ]);
      },
    );

    test(
      'updateMemberForbidden throws ArgumentError when mute action key is missing',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await expectLater(
          GroupApi.instance.updateMemberForbidden(
            'g-10001',
            memberUid: 'u-target',
            action: GroupMemberForbiddenAction.mute,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(adapter.lastRequestOptions, isNull);
      },
    );

    test(
      'updateMemberForbidden posts mute payload with selected key',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.updateMemberForbidden(
          'g-10001',
          memberUid: 'u-target',
          action: GroupMemberForbiddenAction.mute,
          key: 3,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001/forbidden_with_member',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('member_uid', 'u-target'),
        );
        expect(adapter.lastRequestOptions?.data, containsPair('action', 1));
        expect(adapter.lastRequestOptions?.data, containsPair('key', 3));
      },
    );

    test('updateMemberForbidden posts unmute payload without a key', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await GroupApi.instance.updateMemberForbidden(
        'g-10001',
        memberUid: 'u-target',
        action: GroupMemberForbiddenAction.unmute,
      );

      expect(
        adapter.lastRequestOptions?.path,
        '${ApiConfig.groups}/g-10001/forbidden_with_member',
      );
      expect(adapter.lastRequestOptions?.method, 'POST');

      final rawRequestData = adapter.lastRequestOptions?.data;
      expect(rawRequestData, isNotNull);
      expect(rawRequestData, isA<Map>());
      if (rawRequestData is! Map) {
        fail(
          'Expected request data to be a map, got ${rawRequestData.runtimeType}',
        );
      }
      final requestData = Map<String, dynamic>.from(rawRequestData);
      expect(requestData, containsPair('member_uid', 'u-target'));
      expect(requestData, containsPair('action', 0));
      expect(requestData.containsKey('key'), isFalse);
    });

    test(
      'updateBlacklist posts add requests to the confirmed endpoint',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.updateBlacklist(
          'g-10001',
          uids: const <String>['u-1', 'u-2'],
          action: GroupBlacklistAction.add,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001/blacklist/add',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('uids', <String>['u-1', 'u-2']),
        );
      },
    );

    test(
      'updateBlacklist posts remove requests to the confirmed endpoint',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await GroupApi.instance.updateBlacklist(
          'g-10001',
          uids: const <String>['u-1'],
          action: GroupBlacklistAction.remove,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '${ApiConfig.groups}/g-10001/blacklist/remove',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('uids', <String>['u-1']),
        );
      },
    );
  });
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    requests.add(options);
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

class _RoutingJsonAdapter implements HttpClientAdapter {
  _RoutingJsonAdapter(this._handler);

  final _MockJsonResponse Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.payload),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockJsonResponse {
  const _MockJsonResponse(this.payload, {this.statusCode = 200});

  final Object payload;
  final int statusCode;
}

Map<String, dynamic> _buildGroupJson(
  String groupNo, {
  required String name,
  required int save,
  int flame = 0,
  int flameSecond = 0,
  int allowMemberPinnedMessage = 0,
  int chatPwdOn = 0,
}) {
  return <String, dynamic>{
    'group_no': groupNo,
    'name': name,
    'save': save,
    'status': 1,
    'invite': 0,
    'mute': 0,
    'top': 0,
    'show_nick': 1,
    'version': 1,
    'flame': flame,
    'flame_second': flameSecond,
    'allow_member_pinned_message': allowMemberPinnedMessage,
    'chat_pwd_on': chatPwdOn,
  };
}

Future<void> _seedLocalGroupConversation(String groupNo) async {
  final channel = WKChannel(groupNo, WKChannelType.group)
    ..channelName = 'Local Ghost Group'
    ..save = 1;
  WKIM.shared.channelManager.addOrUpdateChannel(channel);

  final conversation = WKConversationMsg()
    ..channelID = groupNo
    ..channelType = WKChannelType.group
    ..lastClientMsgNO = 'local-$groupNo'
    ..lastMsgSeq = 1
    ..lastMsgTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000
    ..unreadCount = 0;
  await ConversationDB.shared.insertOrUpdateWithConvMsg(conversation);
}

Future<void> _clearImTables() async {
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    return;
  }

  await db.delete(WKDBConst.tableMessage);
  await db.delete(WKDBConst.tableMessageExtra);
  await db.delete(WKDBConst.tableConversation);
  await db.delete(WKDBConst.tableConversationExtra);
  await db.delete(WKDBConst.tableChannel);
}
