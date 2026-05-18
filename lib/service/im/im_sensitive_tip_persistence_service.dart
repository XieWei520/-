import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

typedef ImSensitiveTipDelay = Future<void> Function(Duration duration);
typedef ImSensitiveTipDatabaseReadyChecker = Future<bool> Function();
typedef ImSensitiveTipOrderSeqLoader =
    Future<int> Function(int messageSeq, String channelId, int channelType);
typedef ImSensitiveTipMessageSaver = Future<int> Function(WKMsg message);
typedef ImSensitiveTipConversationSaver =
    Future<WKUIConversationMsg?> Function(WKMsg message, int redDot);
typedef ImSensitiveTipInsertedPublisher = void Function(WKMsg message);
typedef ImSensitiveTipConversationRefreshPublisher =
    void Function(List<WKUIConversationMsg> messages);

class ImSensitiveTipPersistenceService {
  ImSensitiveTipPersistenceService({
    required ImSensitiveTipDatabaseReadyChecker ensureDatabaseReady,
    ImSensitiveTipDelay? delay,
    ImSensitiveTipOrderSeqLoader? orderSeqLoader,
    ImSensitiveTipMessageSaver? messageSaver,
    ImSensitiveTipConversationSaver? conversationSaver,
    ImSensitiveTipInsertedPublisher? insertedPublisher,
    ImSensitiveTipConversationRefreshPublisher? conversationRefreshPublisher,
  }) : _ensureDatabaseReady = ensureDatabaseReady,
       _delay = delay ?? Future<void>.delayed,
       _orderSeqLoader =
           orderSeqLoader ?? WKIM.shared.messageManager.getMessageOrderSeq,
       _messageSaver = messageSaver ?? WKIM.shared.messageManager.saveMsg,
       _conversationSaver =
           conversationSaver ?? WKIM.shared.conversationManager.saveWithLiMMsg,
       _insertedPublisher =
           insertedPublisher ?? WKIM.shared.messageManager.setOnMsgInserted,
       _conversationRefreshPublisher =
           conversationRefreshPublisher ??
           WKIM.shared.conversationManager.setRefreshUIMsgs;

  final ImSensitiveTipDatabaseReadyChecker _ensureDatabaseReady;
  final ImSensitiveTipDelay _delay;
  final ImSensitiveTipOrderSeqLoader _orderSeqLoader;
  final ImSensitiveTipMessageSaver _messageSaver;
  final ImSensitiveTipConversationSaver _conversationSaver;
  final ImSensitiveTipInsertedPublisher _insertedPublisher;
  final ImSensitiveTipConversationRefreshPublisher
  _conversationRefreshPublisher;

  Future<void> insertSensitiveWordTipMessage(WKMsg tip) async {
    await _delay(const Duration(seconds: 2));
    if (!await _ensureDatabaseReady()) {
      return;
    }

    final orderSeq = await _orderSeqLoader(0, tip.channelID, tip.channelType);
    tip.orderSeq = orderSeq + 1;
    final clientSeq = await _messageSaver(tip);
    tip.clientSeq = clientSeq;
    final uiMsg = await _conversationSaver(tip, 0);
    _insertedPublisher(tip);
    if (uiMsg != null) {
      _conversationRefreshPublisher(<WKUIConversationMsg>[uiMsg]);
    }
  }
}
