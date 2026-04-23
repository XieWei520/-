import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/modules/vip/vip_guard.dart';

void main() {
  group('vip_guard', () {
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
    });

    test('isVipUser returns true only when vip level equals one', () {
      expect(isVipUser(UserInfo(uid: 'u1', vipLevel: 1)), isTrue);
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
  });
}
