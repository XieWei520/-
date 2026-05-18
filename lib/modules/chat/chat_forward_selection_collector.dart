import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_message_view_model.dart';

typedef ChatSelectedMessageFinder =
    ChatMessageViewModel? Function(String identity);

class ChatForwardSelectionCollector {
  ChatForwardSelectionCollector({
    required ChatSelectedMessageFinder findMessageByIdentity,
  }) : _findMessageByIdentity = findMessageByIdentity;

  final ChatSelectedMessageFinder _findMessageByIdentity;

  List<WKMsg> collect(Iterable<String> selectedIdentities) {
    final messages = <WKMsg>[];
    for (final identity in selectedIdentities) {
      final model = _findMessageByIdentity(identity);
      if (model == null) {
        continue;
      }
      messages.add(model.message);
    }
    return List<WKMsg>.unmodifiable(messages);
  }
}
