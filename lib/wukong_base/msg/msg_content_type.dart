/// Message content type constants
///
/// These constants define the different types of message content
/// supported by the WuKongIM SDK.
class MsgContentType {
  MsgContentType._();

  /// Text message
  static const int text = 1;

  /// Image message
  static const int image = 2;

  /// GIF message
  static const int gif = 3;

  /// Sticker message
  static const int sticker = 21;

  /// Robot card message
  static const int robotCard = 22;

  /// Voice message
  static const int voice = 4;

  /// Video message
  static const int video = 5;

  /// File message
  static const int file = 8;

  /// Location message
  static const int location = 6;

  /// Card message (contact sharing)
  static const int card = 7;

  /// Text link message
  static const int textLink = 8;

  /// JSON message (custom content)
  static const int json = 9;

  /// Recall/Revoke message
  static const int recall = 10;

  /// Typing indicator
  static const int typing = 11;

  /// Tip message (system notification)
  static const int tip = 12;

  /// Multi-forward message
  static const int multiForward = 13;

  /// Sensitive word warning (local display type, matching Android sensitiveWordsTips=-10)
  static const int sensitiveWord = -10;

  /// Rich text message (markdown/HTML subset)
  static const int richText = 14;

  /// Prompt new message
  static const int promptNewMsg = 15;

  /// No relation message (not friend)
  static const int noRelation = 16;

  /// Screenshot notification (P1-T06)
  static const int screenshot = 20;

  // --- Group system messages (1002-1009) ---

  /// Group member joined
  static const int groupMemberJoin = 1002;

  /// Group member quit
  static const int groupMemberQuit = 1003;

  /// Group name updated
  static const int groupNameUpdated = 1004;

  /// Group system info
  static const int groupSystemInfo = 1005;

  /// Group member removed
  static const int groupMemberRemoved = 1006;

  /// Group notice updated
  static const int groupNoticeUpdated = 1007;

  /// Group avatar updated
  static const int groupAvatarUpdated = 1008;

  /// Group member approval
  static const int groupMemberApprove = 1009;

  /// Unknown message type
  static const int unknown = 0;

  /// Message status constants
  static const int sendSuccess = 1;
  static const int sending = 2;
  static const int sendFailed = 3;
}

/// Channel type constants
class ChannelType {
  ChannelType._();

  /// Personal/One-on-one chat
  static const int p2p = 0;

  /// Group chat
  static const int group = 1;
}

/// Get display name for content type
String getContentTypeName(int contentType) {
  switch (contentType) {
    case MsgContentType.text:
      return 'text';
    case MsgContentType.image:
      return 'image';
    case MsgContentType.gif:
      return 'gif';
    case MsgContentType.sticker:
      return 'sticker';
    case MsgContentType.robotCard:
      return 'robot_card';
    case MsgContentType.voice:
      return 'voice';
    case MsgContentType.video:
      return 'video';
    case MsgContentType.file:
      return 'file';
    case MsgContentType.location:
      return 'location';
    case MsgContentType.card:
      return 'card';
    case MsgContentType.recall:
      return 'recall';
    case MsgContentType.typing:
      return 'typing';
    case MsgContentType.tip:
      return 'tip';
    case MsgContentType.multiForward:
      return 'multi_forward';
    case MsgContentType.sensitiveWord:
      return 'sensitive_word';
    case MsgContentType.richText:
      return 'rich_text';
    case MsgContentType.screenshot:
      return 'screenshot';
    case MsgContentType.groupMemberJoin:
      return 'group_member_join';
    case MsgContentType.groupMemberQuit:
      return 'group_member_quit';
    case MsgContentType.groupNameUpdated:
      return 'group_name_updated';
    case MsgContentType.groupSystemInfo:
      return 'group_system_info';
    case MsgContentType.groupMemberRemoved:
      return 'group_member_removed';
    case MsgContentType.groupNoticeUpdated:
      return 'group_notice_updated';
    case MsgContentType.groupAvatarUpdated:
      return 'group_avatar_updated';
    case MsgContentType.groupMemberApprove:
      return 'group_member_approve';
    default:
      return 'unknown';
  }
}
