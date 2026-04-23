import 'base_endpoint.dart';

/// Used for chat input toolbar items
class ChatToolBarMenu extends BaseEndpoint {
  /// Toolbar icon (image path or asset)
  final String? icon;

  /// Selected icon
  final String? selectedIcon;

  /// Whether this item is selected
  final bool isSelected;

  /// Whether this item is disabled
  final bool isDisable;

  /// Bottom view widget
  final dynamic bottomView;

  /// Callback when checked state changes
  final void Function(bool isSelected)? onChecked;

  ChatToolBarMenu({
    required super.sid,
    this.icon,
    this.selectedIcon,
    this.isSelected = false,
    this.isDisable = false,
    this.bottomView,
    this.onChecked,
  });
}

/// Used for chat function panel items
class ChatFunctionMenu extends BaseEndpoint {
  /// Icon path
  final String? icon;

  /// Function key
  final String functionKey;

  /// Callback when clicked
  @override
  // ignore: overridden_fields
  final MenuClickCallback? onClick;

  ChatFunctionMenu({
    required super.sid,
    this.icon,
    super.text,
    this.functionKey = '',
    this.onClick,
  });
}
