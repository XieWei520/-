import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/user.dart';

void main() {
  group('Friend model', () {
    test('parses peer blacklist flag from friend payload', () {
      final friend = Friend.fromJson({'uid': 'u_test', 'be_blacklist': 1});

      expect(friend.beBlacklist, 1);
    });

    test('parses vip level from friend payload', () {
      final friend = Friend.fromJson({'uid': 'u_test', 'vip_level': 1});

      expect(friend.vipLevel, 1);
      expect(friend.toJson()['vip_level'], 1);
    });

    test('normalizes customer service category aliases', () {
      final friend = Friend.fromJson({
        'uid': 'u_test',
        'category': 'customerService',
      });

      expect(friend.category, 'customer_service');
      expect(friend.isCustomerService, isTrue);
    });
  });

  group('FriendRequest model', () {
    test('exposes request status helpers', () {
      expect(FriendRequest(id: 1, fromUid: 'u1', status: 0).isPending, isTrue);
      expect(FriendRequest(id: 2, fromUid: 'u1', status: 1).isAccepted, isTrue);
      expect(FriendRequest(id: 3, fromUid: 'u1', status: 2).isRejected, isTrue);
    });
  });

  group('UserInfo model', () {
    test('parses peer blacklist flag from user payload', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'be_blacklist': 1});

      expect(user.beBlacklist, 1);
    });

    test('parses vip level and exposes isVip getter', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'vip_level': 1});

      expect(user.vipLevel, 1);
      expect(user.isVip, isTrue);
    });

    test('parses vip level string value', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'vip_level': '1'});

      expect(user.vipLevel, 1);
      expect(user.isVip, isTrue);
    });

    test('falls back to 0 for invalid vip level string', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'vip_level': 'oops'});

      expect(user.vipLevel, 0);
      expect(user.isVip, isFalse);
    });

    test('treats vip level above 1 as non vip', () {
      final user = UserInfo.fromJson({'uid': 'u_test', 'vip_level': 2});

      expect(user.vipLevel, 2);
      expect(user.isVip, isFalse);
    });

    test('uses vip level default of 0 when missing', () {
      final user = UserInfo.fromJson({'uid': 'u_test'});

      expect(user.vipLevel, 0);
      expect(user.isVip, isFalse);
    });

    test('supports vip level in toJson and copyWith', () {
      final user = UserInfo(uid: 'u_test', vipLevel: 1);
      final copied = user.copyWith(vipLevel: -1);

      expect(user.toJson()['vip_level'], 1);
      expect(copied.vipLevel, -1);
      expect(copied.isVip, isFalse);
    });
  });
}
