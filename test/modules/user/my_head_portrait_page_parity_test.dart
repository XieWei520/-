import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_head_portrait_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final databaseUid =
      'my_head_portrait_page_test_${DateTime.now().microsecondsSinceEpoch}';

  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: child);
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    WKIM.shared.options = wk.Options.newDefault(databaseUid, 'token');
    await WKDBHelper.shared.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    EndpointManager.getInstance().clear();
  });

  tearDownAll(() {
    WKDBHelper.shared.close();
  });

  testWidgets('my head portrait page matches Android shell', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const MyHeadPortraitPage(
          displayName: 'Alice',
          avatarUrl: 'mock-avatar',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('my_head_portrait_image')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my_head_portrait_more_action')),
      findsOneWidget,
    );
  });

  test('buildRtcAvatarUrl replaces old query arguments with key', () {
    final url = buildRtcAvatarUrl(
      'https://example.com/avatar.png?t=2',
      'cache123',
    );

    final uri = Uri.parse(url);
    expect(
      '${uri.scheme}://${uri.host}${uri.path}',
      'https://example.com/avatar.png',
    );
    expect(uri.queryParameters, <String, String>{'key': 'cache123'});
  });

  test('resolveAvatarUploadSourcePath prefers the cropped file path', () async {
    final calls = <String>[];

    final resolved = await resolveAvatarUploadSourcePath(
      'source/avatar.jpg',
      cropAvatarPath: (sourcePath) async {
        calls.add(sourcePath);
        return 'cache/avatar_cropped.jpg';
      },
    );

    expect(calls, <String>['source/avatar.jpg']);
    expect(resolved, 'cache/avatar_cropped.jpg');
  });

  test('resolveAvatarUploadSourcePath returns null when crop is cancelled', () async {
    final resolved = await resolveAvatarUploadSourcePath(
      'source/avatar.jpg',
      cropAvatarPath: (_) async => null,
    );

    expect(resolved, isNull);
  });

  test(
    'syncAvatarParityArtifacts creates or updates the personal channel and invokes rtc avatar sync',
    () async {
      final caseUid =
          'my_head_portrait_case_${DateTime.now().microsecondsSinceEpoch}';
      await StorageUtils.setUid(caseUid);

      String? rtcAvatarUrl;
      EndpointManager.getInstance().register(
        'updateRtcAvatarUrl',
        '',
        0,
        VoidFunctionHandler(([param]) {
          rtcAvatarUrl = param as String?;
        }),
      );

      final artifacts = await syncAvatarParityArtifacts(
        'https://example.com/avatar.png?t=2',
      );
      final channel = await WKIM.shared.channelManager.getChannel(
        caseUid,
        WKChannelType.personal,
      );

      expect(artifacts, isNotNull);
      expect(channel, isNotNull);
      expect(channel!.avatarCacheKey, isNotEmpty);
      expect(channel.avatarCacheKey, artifacts!.avatarCacheKey);
      expect(rtcAvatarUrl, artifacts.rtcAvatarUrl);

      final uri = Uri.parse(rtcAvatarUrl!);
      expect(
        '${uri.scheme}://${uri.host}${uri.path}',
        'https://example.com/avatar.png',
      );
      expect(uri.queryParameters['key'], channel.avatarCacheKey);
      expect(uri.queryParameters.containsKey('t'), isFalse);
    },
  );
}
