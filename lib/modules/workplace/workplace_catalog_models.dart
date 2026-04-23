class WorkplaceBanner {
  const WorkplaceBanner({
    required this.bannerNo,
    required this.cover,
    required this.title,
    required this.description,
    required this.jumpType,
    required this.route,
    required this.sortNum,
    required this.createdAt,
  });

  final String bannerNo;
  final String cover;
  final String title;
  final String description;
  final int jumpType;
  final String route;
  final int sortNum;
  final String createdAt;

  factory WorkplaceBanner.fromJson(Map<String, dynamic> json) {
    return WorkplaceBanner(
      bannerNo: _toString(json['banner_no']),
      cover: _toString(json['cover']),
      title: _toString(json['title']),
      description: _toString(json['description']),
      jumpType: _toInt(json['jump_type']),
      route: _toString(json['route']),
      sortNum: _toInt(json['sort_num']),
      createdAt: _toString(json['created_at']),
    );
  }
}

class WorkplaceCategory {
  const WorkplaceCategory({
    required this.categoryNo,
    required this.name,
    required this.sortNum,
  });

  final String categoryNo;
  final String name;
  final int sortNum;

  factory WorkplaceCategory.fromJson(Map<String, dynamic> json) {
    return WorkplaceCategory(
      categoryNo: _toString(json['category_no']),
      name: _toString(json['name']),
      sortNum: _toInt(json['sort_num']),
    );
  }
}

class WorkplaceApp {
  const WorkplaceApp({
    required this.appId,
    required this.sortNum,
    required this.icon,
    required this.name,
    required this.description,
    required this.appCategory,
    required this.status,
    required this.jumpType,
    required this.appRoute,
    required this.webRoute,
    required this.isPaidApp,
    required this.isAdded,
  });

  final String appId;
  final int sortNum;
  final String icon;
  final String name;
  final String description;
  final String appCategory;
  final int status;
  final int jumpType;
  final String appRoute;
  final String webRoute;
  final int isPaidApp;
  final bool isAdded;

  factory WorkplaceApp.fromJson(Map<String, dynamic> json) {
    return WorkplaceApp(
      appId: _toString(json['app_id']),
      sortNum: _toInt(json['sort_num']),
      icon: _toString(json['icon']),
      name: _toString(json['name']),
      description: _toString(json['description']),
      appCategory: _toString(json['app_category']),
      status: _toInt(json['status']),
      jumpType: _toInt(json['jump_type']),
      appRoute: _toString(json['app_route']),
      webRoute: _toString(json['web_route']),
      isPaidApp: _toInt(json['is_paid_app']),
      isAdded: _toInt(json['is_added']) == 1,
    );
  }

  WorkplaceApp copyWith({bool? isAdded}) {
    return WorkplaceApp(
      appId: appId,
      sortNum: sortNum,
      icon: icon,
      name: name,
      description: description,
      appCategory: appCategory,
      status: status,
      jumpType: jumpType,
      appRoute: appRoute,
      webRoute: webRoute,
      isPaidApp: isPaidApp,
      isAdded: isAdded ?? this.isAdded,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _toString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}
