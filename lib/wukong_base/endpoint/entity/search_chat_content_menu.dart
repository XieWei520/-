/// Search chat content menu
/// 
/// Used for searching within chat messages
class SearchChatContentMenu {
  /// Channel ID
  final String channelId;

  /// Channel type
  final int channelType;

  SearchChatContentMenu({
    required this.channelId,
    required this.channelType,
  });
}

/// Search chat edit sticker menu
/// 
/// Used for searching stickers in edit mode
class SearchChatEditStickerMenu {
  /// Callback when sticker is selected
  final void Function(String stickerId)? onStickerSelected;

  SearchChatEditStickerMenu({this.onStickerSelected});
}
