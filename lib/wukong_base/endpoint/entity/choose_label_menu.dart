/// Choose label menu
/// 
/// Used for selecting labels/tags
class ChooseLabelMenu {
  /// Maximum number of selections
  final int maxCount;

  /// Callback when selection is complete
  final void Function(List<dynamic> selectedList)? onChooseBack;

  ChooseLabelMenu({
    this.maxCount = 10,
    this.onChooseBack,
  });
}

/// Choose label entity
/// 
/// Represents a single label
class ChooseLabelEntity {
  /// Label ID
  final String labelId;

  /// Label name
  final String name;

  /// Label color
  final int color;

  ChooseLabelEntity({
    required this.labelId,
    required this.name,
    this.color = 0,
  });
}
