/// Withdraw (revoke) message menu
/// 
/// Used for revoking/deleting messages
class WithdrawMsgMenu {
  /// Message ID
  final String messageId;

  /// Channel ID
  final String channelId;

  /// Client message number
  final String clientMsgNo;

  /// Channel type
  final int channelType;

  /// Message order seq
  final int messageSeq;

  WithdrawMsgMenu({
    required this.messageId,
    required this.channelId,
    required this.clientMsgNo,
    required this.channelType,
    required this.messageSeq,
  });
}
