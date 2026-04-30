import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_identity.dart';

void main() {
  group('customer service identity', () {
    test(
      'normalizes backend aliases to a single customer service category',
      () {
        expect(
          normalizePublicAccountCategory('customer_service'),
          customerServiceCategory,
        );
        expect(
          normalizePublicAccountCategory('customerService'),
          customerServiceCategory,
        );
        expect(
          normalizePublicAccountCategory('customerservice'),
          customerServiceCategory,
        );
        expect(
          normalizePublicAccountCategory('service'),
          customerServiceCategory,
        );
      },
    );

    test(
      'detects customer service categories without affecting other tags',
      () {
        expect(isCustomerServiceCategory('customerService'), isTrue);
        expect(isCustomerServiceCategory('service'), isTrue);
        expect(isCustomerServiceCategory('system'), isFalse);
        expect(normalizePublicAccountCategory('system'), 'system');
      },
    );
  });
}
