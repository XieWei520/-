import '../../wukong_base/msg/msg_content_type.dart';

// IM message content types
class MessageContentType {
  MessageContentType._();

  // Core content types aligned with MsgContentType
  static const int text = MsgContentType.text;
  static const int image = MsgContentType.image;
  static const int voice = MsgContentType.voice;
  static const int video = MsgContentType.video;
  static const int file = MsgContentType.file;
  static const int location = MsgContentType.location;
  static const int card = MsgContentType.card;
  static const int robotCard = MsgContentType.robotCard;

  // App-specific legacy/local constants
  static const int merge = MsgContentType.multiForward;
  static const int emoji = 9;
  static const int typing = -4;
  static const int revoke = -5;
  static const int systemMsg = 0;
  static const int contentFormatError = -1;
  static const int insideMsg = -100;
}

// Channel types
class ChannelType {
  ChannelType._();

  static const int personal = 1;
  static const int group = 2;
  static const int community = 3;
  static const int communityTopic = 4;
}

// System message types
class SystemMessageType {
  SystemMessageType._();

  static const int addGroupMember = 1002;
  static const int removeGroupMember = 1003;
  static const int createGroup = 1004;
  static const int quitGroup = 1005;
  static const int updateGroupInfo = 1006;
  static const int dismissGroup = 1007;
  static const int setGroupAdmin = 1008;
  static const int revokeGroupAdmin = 1009;
  static const int transferGroupOwner = 1010;
  static const int groupMute = 1011;
}

// Message send status
class SendMsgResult {
  SendMsgResult._();

  static const int sending = 0;
  static const int sendSuccess = 1;
  static const int sendFail = 2;
}
