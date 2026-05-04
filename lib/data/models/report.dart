class ReportCategory {
  final String categoryNo;
  final String categoryName;
  final String parentCategoryNo;
  final List<ReportCategory> children;

  const ReportCategory({
    required this.categoryNo,
    required this.categoryName,
    required this.parentCategoryNo,
    this.children = const <ReportCategory>[],
  });

  bool get hasChildren => children.isNotEmpty;
  bool get isLeaf => children.isEmpty;

  factory ReportCategory.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final children = rawChildren is List
        ? rawChildren
              .whereType<Map>()
              .map(
                (child) =>
                    ReportCategory.fromJson(Map<String, dynamic>.from(child)),
              )
              .toList()
        : const <ReportCategory>[];

    return ReportCategory(
      categoryNo: (json['category_no'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      parentCategoryNo: (json['parent_category_no'] ?? '').toString(),
      children: children,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_no': categoryNo,
      'category_name': categoryName,
      'parent_category_no': parentCategoryNo,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}
