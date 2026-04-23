import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';

const String _groupNo = 'g_task4_avatar';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;
  final imageHttpClient = _FakeHttpClient();
  imageHttpClient.request.response
    ..statusCode = HttpStatus.ok
    ..contentLength = _transparentImage.length
    ..content = <Uint8List>[Uint8List.fromList(_transparentImage)];

  setUpAll(() async {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    HttpOverrides.global = _FakeHttpOverrides(imageHttpClient);
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    HttpOverrides.global = null;
  });

  testWidgets(
    'owner/admin path can pick and upload a group avatar from group detail',
    (tester) async {
      final adapter = _GroupDetailAvatarRoutingAdapter(
        groupNo: _groupNo,
        group: _buildGroupJson(role: 1, avatar: 'https://example.com/old.png'),
        members: _buildMembersJson(currentUid: 'u_owner', currentRole: 1),
      );

      var pickCalls = 0;
      var uploadCalls = 0;
      String? uploadedGroupNo;
      String? uploadedFilePath;

      await _pumpGroupDetailPage(
        tester,
        adapter: adapter,
        currentUid: 'u_owner',
        pickAvatarImage: () async {
          pickCalls += 1;
          return 'C:/mock/new-avatar.png';
        },
        uploadAvatarImage: (groupNo, filePath) async {
          uploadCalls += 1;
          uploadedGroupNo = groupNo;
          uploadedFilePath = filePath;
          adapter.setGroupAvatar('https://example.com/new.png');
          return 'https://example.com/new.png';
        },
      );
      final postLoadGroupInfoCount = adapter.groupInfoRequestCount;

      expect(
        find.byKey(const ValueKey<String>('group-detail-avatar-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-detail-avatar-edit-badge')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('group-detail-avatar-button')),
      );
      await tester.pumpAndSettle();

      expect(pickCalls, 1);
      expect(uploadCalls, 1);
      expect(uploadedGroupNo, _groupNo);
      expect(uploadedFilePath, 'C:/mock/new-avatar.png');
      expect(
        adapter.groupInfoRequestCount,
        greaterThan(postLoadGroupInfoCount),
      );
    },
  );

  testWidgets('normal member sees read-only group avatar with no edit badge', (
    tester,
  ) async {
    final adapter = _GroupDetailAvatarRoutingAdapter(
      groupNo: _groupNo,
      group: _buildGroupJson(role: 0, avatar: 'https://example.com/old.png'),
      members: _buildMembersJson(currentUid: 'u_member', currentRole: 0),
    );

    var pickCalls = 0;
    var uploadCalls = 0;

    await _pumpGroupDetailPage(
      tester,
      adapter: adapter,
      currentUid: 'u_member',
      pickAvatarImage: () async {
        pickCalls += 1;
        return 'C:/mock/new-avatar.png';
      },
      uploadAvatarImage: (groupNo, filePath) async {
        uploadCalls += 1;
        return 'https://example.com/new.png';
      },
    );

    expect(
      find.byKey(const ValueKey<String>('group-detail-avatar-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-detail-avatar-edit-badge')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('group-detail-avatar-button')),
    );
    await tester.pumpAndSettle();

    expect(pickCalls, 0);
    expect(uploadCalls, 0);
  });
}

Future<void> _pumpGroupDetailPage(
  WidgetTester tester, {
  required _GroupDetailAvatarRoutingAdapter adapter,
  required String currentUid,
  Future<String?> Function()? pickAvatarImage,
  Future<String> Function(String groupNo, String filePath)? uploadAvatarImage,
}) async {
  await StorageUtils.setUid(currentUid);
  ApiClient.instance.dio.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: GroupDetailPage(
          channelId: _groupNo,
          pickAvatarImage: pickAvatarImage,
          uploadAvatarImage: uploadAvatarImage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _buildGroupJson({required int role, String? avatar}) {
  return <String, dynamic>{
    'group_no': _groupNo,
    'name': 'Task4 Avatar Group',
    'creator': 'u_owner',
    'avatar': avatar ?? '',
    'member_count': 2,
    'role': role,
    'invite': 0,
    'mute': 0,
    'top': 0,
    'save': 1,
    'show_nick': 1,
    'chat_pwd_on': 0,
    'allow_view_history_msg': 1,
    'join_group_remind': 0,
    'allow_member_pinned_message': 0,
  };
}

List<Map<String, dynamic>> _buildMembersJson({
  required String currentUid,
  required int currentRole,
}) {
  final members = <Map<String, dynamic>>[
    <String, dynamic>{
      'group_no': _groupNo,
      'uid': 'u_owner',
      'name': 'Owner',
      'role': 1,
    },
    <String, dynamic>{
      'group_no': _groupNo,
      'uid': 'u_member',
      'name': 'Member',
      'role': 0,
    },
  ];

  for (var i = 0; i < members.length; i++) {
    if (members[i]['uid'] == currentUid) {
      members[i] = <String, dynamic>{...members[i], 'role': currentRole};
    }
  }
  return members;
}

class _GroupDetailAvatarRoutingAdapter implements HttpClientAdapter {
  _GroupDetailAvatarRoutingAdapter({
    required this.groupNo,
    required Map<String, dynamic> group,
    required List<Map<String, dynamic>> members,
  }) : _group = Map<String, dynamic>.from(group),
       _members = members
           .map((member) => Map<String, dynamic>.from(member))
           .toList(growable: false);

  final String groupNo;
  final Map<String, dynamic> _group;
  final List<Map<String, dynamic>> _members;
  int groupInfoRequestCount = 0;

  String get groupPath => '${ApiConfig.groups}/$groupNo';
  String get membersPath => '$groupPath${ApiConfig.groupMembers}';
  String get channelPath => '/v1/channels/$groupNo/1';

  void setGroupAvatar(String avatarUrl) {
    _group['avatar'] = avatarUrl;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'GET' && path == groupPath) {
      groupInfoRequestCount += 1;
      return _jsonResponse(<String, dynamic>{'code': 0, 'data': _group});
    }
    if (method == 'GET' && path == membersPath) {
      return _jsonResponse(<String, dynamic>{'code': 0, 'data': _members});
    }
    if (method == 'GET' && path == ApiConfig.friends) {
      return _jsonResponse(const <String, dynamic>{'code': 0, 'data': []});
    }
    if (method == 'GET' && path.startsWith('${ApiConfig.userInfo}/')) {
      final uid = path.substring(ApiConfig.userInfo.length + 1);
      final member = _members.cast<Map<String, dynamic>?>().firstWhere(
        (item) => (item?['uid']?.toString() ?? '') == uid,
        orElse: () => null,
      );
      return _jsonResponse(<String, dynamic>{
        'uid': uid,
        'name': member?['name']?.toString() ?? uid,
        'avatar': member?['avatar']?.toString(),
      });
    }
    if (method == 'GET' && path == channelPath) {
      return _jsonResponse(<String, dynamic>{
        'channel': <String, dynamic>{'channel_id': groupNo, 'channel_type': 1},
        'name': _group['name'] ?? '',
        'extra': const <String, dynamic>{'msg_auto_delete': 0},
      });
    }

    return _jsonResponse(<String, dynamic>{
      'code': 404,
      'msg': 'Unhandled request: $method $path',
    }, statusCode: 404);
  }

  ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
];

class _FakeHttpClient extends Fake implements HttpClient {
  final _FakeHttpClientRequest request = _FakeHttpClientRequest();
  Object? thrownError;

  @override
  set autoUncompress(bool value) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (thrownError != null) {
      throw thrownError!;
    }
    return request;
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final _FakeHttpClientResponse response = _FakeHttpClientResponse();

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return response;
  }
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  bool drained = false;

  @override
  int statusCode = HttpStatus.ok;

  @override
  int contentLength = 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  late List<List<int>> content;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(content).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<E> drain<E>([E? futureValue]) async {
    drained = true;
    return futureValue ?? futureValue as E;
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpOverrides extends HttpOverrides {
  _FakeHttpOverrides(this.client);

  final HttpClient client;

  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}
