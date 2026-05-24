import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/indexed_db_chat_cache_paging.dart';

void main() {
  test('around page plan keeps the first newer message as the anchor', () {
    final plan = planIndexedDbAroundPage(limit: 3);

    expect(plan.beforeLimit, 1);
    expect(plan.afterLimitForBeforeCount(1), 2);
    expect(plan.includeAnchorInAfter, isTrue);
  });

  test(
    'around page plan fills forward when the anchor is near the beginning',
    () {
      final plan = planIndexedDbAroundPage(limit: 3);

      expect(plan.afterLimitForBeforeCount(0), 3);
    },
  );

  test(
    'around page plan backfills older messages when newer side underfills',
    () {
      final plan = planIndexedDbAroundPage(limit: 3);

      expect(plan.backfillBeforeLimitForAfterCount(1), 2);
      expect(plan.backfillBeforeLimitForAfterCount(0), 3);
    },
  );
}
