import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_forward_selection_collector.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('collects selected messages in selection order', () {
    final first = WKMsg()
      ..messageID = 'm1'
      ..clientMsgNO = 'c1';
    final second = WKMsg()
      ..messageID = 'm2'
      ..clientMsgNO = 'c2';
    final collector = ChatForwardSelectionCollector(
      findMessageByIdentity: (identity) {
        return switch (identity) {
          'mid:m1' => _model(identity: identity, message: first),
          'mid:m2' => _model(identity: identity, message: second),
          _ => null,
        };
      },
    );

    final messages = collector.collect(<String>{'mid:m2', 'mid:m1'});

    expect(messages, <WKMsg>[second, first]);
  });

  test('skips selected identities that are no longer in the viewport', () {
    final message = WKMsg()
      ..messageID = 'm1'
      ..clientMsgNO = 'c1';
    final collector = ChatForwardSelectionCollector(
      findMessageByIdentity: (identity) => identity == 'mid:m1'
          ? _model(identity: identity, message: message)
          : null,
    );

    final messages = collector.collect(<String>{'mid:missing', 'mid:m1'});

    expect(messages, <WKMsg>[message]);
  });
}

ChatMessageViewModel _model({
  required String identity,
  required WKMsg message,
}) {
  return ChatMessageViewModel(
    identity: identity,
    message: message,
    preview: '',
    system: false,
    self: false,
    structured: null,
    revision: identity,
  );
}
