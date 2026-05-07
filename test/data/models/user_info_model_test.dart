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
      final user = UserInfo.fromJson({
        'uid': 'u_test',
        'category': 'system',
      });

      expect(user.category, 'system');
      expect(user.isCustomerService, isFalse);
    });
  });
}
