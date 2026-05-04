import 'base_endpoint.dart';

/// Sticker view menu
/// 
/// Used for displaying sticker/emoji panel
class StickerViewMenu extends BaseEndpoint {
  /// Whether the search view is shown
  final bool isSearchViewShow;

  /// Callback when search view visibility changes
  final void Function(bool isShow)? onSearchViewShow;

  StickerViewMenu({
    this.isSearchViewShow = false,
    this.onSearchViewShow,
  }) : super(sid: 'sticker_view');
}

/// Sticker category refresh menu
/// 
/// Used for refreshing sticker categories
class StickerCategoryRefreshMenu {
  /// Category ID
  final String? categoryId;

  StickerCategoryRefreshMenu({this.categoryId});
}
