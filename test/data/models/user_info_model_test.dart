import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';

void main() {
  group('UserInfo customer service category', () {
    test('normalizes customer service aliases from payload', () {
      final user = UserInfo.fromJson({
        'uid': 'u_test',
        'category': 'customerService',
      });

      expect(user.category, 'customer_service');
      expect(user.isCustomerService, isTrue);
    });

    test('preserves non customer service categories', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'category': 'system'});

      expect(user.category, 'system');
      expect(user.isCustomerService, isFalse);
    });
  });

  group('UserInfo VIP status and entitlements', () {
    test(
      'treats unexpired merchant vip as active with default capabilities',
      () {
        final user = UserInfo.fromJson({
          'uid': 'u_vip',
          'vip_level': 1,
          'vip_expire_time': '2099-01-01 00:00:00',
        });

        expect(user.vipStatus, VipStatus.active);
        expect(user.isVip, isTrue);
        expect(user.canAddFriend, isTrue);
        expect(user.canCreateGroup, isTrue);
        expect(user.canInviteGroupMember, isTrue);
        expect(user.canUseSystemManagement, isTrue);
      },
    );

    test('treats expired merchant vip as expired without capabilities', () {
      final user = UserInfo.fromJson({
        'uid': 'u_expired',
        'vip_level': 1,
        'vip_expire_time': '2000-01-01 00:00:00',
      });

      expect(user.vipStatus, VipStatus.expired);
      expect(user.isVip, isFalse);
      expect(user.canAddFriend, isFalse);
      expect(user.canCreateGroup, isFalse);
      expect(user.canUseSystemManagement, isFalse);
    });

    test('treats vip expiring at current time as expired', () {
      final user = UserInfo(
        uid: 'u_expiring_now',
        vipLevel: 1,
        vipExpireTime: DateTime.now(),
      );

      expect(user.vipStatus, VipStatus.expired);
      expect(user.isVip, isFalse);
    });

    test('uses explicit entitlement list when provided by backend', () {
      final user = UserInfo.fromJson({
        'uid': 'u_vip_limited',
        'vip_level': 1,
        'vip_expire_time': '2099-01-01T00:00:00Z',
        'entitlements': ['add_friend', 'create_group'],
      });

      expect(user.canAddFriend, isTrue);
      expect(user.canCreateGroup, isTrue);
      expect(user.canInviteGroupMember, isFalse);
      expect(user.canUseSystemManagement, isFalse);
      expect(user.toJson()['entitlements'], ['add_friend', 'create_group']);
    });

    test('uses explicit entitlement map when provided by backend', () {
      final user = UserInfo.fromJson({
        'uid': 'u_vip_map',
        'vip_level': 1,
        'vip_expire_time': '2099-01-01 00:00:00',
        'entitlements': {
          'add_friend': true,
          'create_group': false,
          'system_management': true,
        },
      });

      expect(user.canAddFriend, isTrue);
      expect(user.canCreateGroup, isFalse);
      expect(user.canUseSystemManagement, isTrue);
    });

    test('copyWith preserves and overrides vip expiry fields', () {
      final active = UserInfo(
        uid: 'u_copy',
        vipLevel: 1,
        vipExpireTime: DateTime.utc(2099),
      );
      final expired = active.copyWith(
        vipStatus: VipStatus.expired,
        vipEntitlements: const <String>{},
      );

      expect(active.isVip, isTrue);
      expect(expired.vipStatus, VipStatus.expired);
      expect(expired.isVip, isFalse);
      expect(expired.canAddFriend, isFalse);
    });
  });
}
