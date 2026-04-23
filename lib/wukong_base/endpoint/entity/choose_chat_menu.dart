/// Choose chat menu
/// 
/// Used for choosing a chat session
class ChooseChatMenu {
  /// Maximum number of selections
  final int maxCount;

  /// Callback when selection is complete
  final void Function(List<dynamic> selectedList)? onChooseBack;

  ChooseChatMenu({
    this.maxCount = 9,
    this.onChooseBack,
  });
}
