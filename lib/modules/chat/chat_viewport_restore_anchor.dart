import 'package:wukongimfluttersdk/entity/conversation.dart';

import 'chat_viewport_controller.dart';

ChatViewportRestoreAnchor? restoreAnchorFromConversationExtra(
  WKConversationMsgExtra? extra,
) {
  if (extra == null || extra.keepMessageSeq <= 0) {
    return null;
  }
  return ChatViewportRestoreAnchor(
    aroundOrderSeq:
        extra.keepMessageSeq * ChatViewportController.orderSeqFactor,
    keepOffsetY: extra.keepOffsetY,
    browseTo: extra.browseTo,
  );
}
