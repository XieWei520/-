import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_password_runtime.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_identity.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('vip_guard', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('exposes vip guard constants', () {
      expect(vipCustomerServiceUid, 'system_kefu');
      expect(
        vipRequiredMessage,
        '\u8BE5\u529F\u80FD\u4EC5\u9650\u5546\u5BB6\u53EF\u7528\uFF0C\u8BF7\u8054\u7CFB\u7BA1\u7406\u5458',
      );
    });

    test('isVipUser returns false for null or non vip users', () {
      expect(isVipUser(null), isFalse);
      expect(isVipUser(UserInfo(uid: 'u1', vipLevel: 0)), isFalse);
      expect(isVipUser(UserInfo(uid: 'u1', vipLevel: -1)), isFalse);
      expect(isVipUser(UserInfo(uid: 'u1', vipLevel: 2)), isFalse);
      expect(
        isVipUser(
          UserInfo(uid: 'u1', vipLevel: 1, vipExpireTime: DateTime.utc(2000)),
        ),
        isFalse,
      );
    });

    test('isVipUser returns true only when vip level equals one', () {
      expect(isVipUser(UserInfo(uid: 'u1', vipLevel: 1)), isTrue);
    });

    test('hasVipEntitlement respects active vip entitlement model', () {
      final activeLimited = UserInfo(
        uid: 'u1',
        vipLevel: 1,
        vipExpireTime: DateTime.utc(2099),
        vipEntitlements: const <String>{VipEntitlement.addFriend},
      );

      expect(
        hasVipEntitlement(activeLimited, VipEntitlement.addFriend),
        isTrue,
      );
      expect(
        hasVipEntitlement(activeLimited, VipEntitlement.createGroup),
        isFalse,
      );
      expect(
        hasVipEntitlement(
          UserInfo(
            uid: 'u1',
            vipLevel: 1,
            vipExpireTime: DateTime.utc(2000),
            vipEntitlements: const <String>{VipEntitlement.addFriend},
          ),
          VipEntitlement.addFriend,
        ),
        isFalse,
      );
    });

    testWidgets('VipBadge renders default label with expected text settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: VipBadge())),
        ),
      );

      expect(find.text(vipBadgeDefaultLabel), findsOneWidget);

      final text = tester.widget<Text>(find.text(vipBadgeDefaultLabel));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('VipBadge renders the same default label in compact mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: VipBadge(compact: true))),
        ),
      );

      expect(find.text(vipBadgeDefaultLabel), findsOneWidget);
      expect(find.text('VIP'), findsNothing);
    });

    testWidgets('guardVipFeature returns false for an unmounted context', (
      tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await expectLater(guardVipFeature(capturedContext), completion(isFalse));
    });

    testWidgets(
      'contact admin opens the default customer service personal account',
      (tester) async {
        ApiClient.instance.dio.httpClientAdapter = _CustomerServicesAdapter(
          payload: const <String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'uid': 'cs_default',
                'name': '默认客服',
                'category': 'customerService',
              },
            ],
          },
        );
        late BuildContext capturedContext;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) {
                return _TestAuthNotifier(
                  ref,
                  initialState: AuthState(
                    isLoggedIn: true,
                    isRestoringSession: false,
                    userInfo: UserInfo(uid: 'u_normal', vipLevel: 0),
                  ),
                );
              }),
              authCurrentUserLoaderProvider.overrideWithValue(() async => null),
              authDraftSyncProvider.overrideWithValue(() async {}),
              chatPasswordRuntimeProvider.overrideWithValue(
                ChatPasswordRuntime(
                  loadChannel: (_, _) async => WKChannel(
                    'cs_default',
                    WKChannelType.personal,
                  )..localExtra = const <String, dynamic>{'chat_pwd_on': 1},
                  clearChannelMessages: (_, _) async {},
                ),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return const Scaffold(body: SizedBox.shrink());
                },
              ),
            ),
          ),
        );

        final guardFuture = guardVipFeature(capturedContext);
        await tester.pumpAndSettle();

        await tester.tap(find.text('联系管理员'));
        for (
          var i = 0;
          i < 20 && find.byType(ChatPage).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final chatPage = tester.widget<ChatPage>(find.byType(ChatPage));
        expect(chatPage.channelId, 'cs_default');
        expect(chatPage.channelType, WKChannelType.personal);
        expect(chatPage.channelName, '默认客服');
        expect(chatPage.channelCategory, customerServiceCategory);

        Navigator.of(capturedContext).pop();
        await tester.pumpAndSettle();
        await expectLater(guardFuture, completion(isFalse));
      },
    );
  });
}

class _CustomerServicesAdapter implements HttpClientAdapter {
  _CustomerServicesAdapter({required this.payload});

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

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
