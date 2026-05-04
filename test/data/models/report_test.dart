import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/report.dart';

void main() {
  group('ReportCategory', () {
    test('parses nested report categories from server payload', () {
      final category = ReportCategory.fromJson({
        'category_no': '10000',
        'category_name': '发布不适当内容对我造成骚扰',
        'parent_category_no': '',
        'children': [
          {
            'category_no': '10001',
            'category_name': '色情',
            'parent_category_no': '10000',
          },
        ],
      });

      expect(category.categoryNo, '10000');
      expect(category.categoryName, '发布不适当内容对我造成骚扰');
      expect(category.hasChildren, isTrue);
      expect(category.isLeaf, isFalse);
      expect(category.children, hasLength(1));
      expect(category.children.first.categoryNo, '10001');
      expect(category.children.first.parentCategoryNo, '10000');
      expect(category.children.first.isLeaf, isTrue);
    });
  });
}
