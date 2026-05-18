import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';

class NoopChatConversationExtraGateway implements ChatConversationExtraGateway {
  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    return null;
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {}
}
