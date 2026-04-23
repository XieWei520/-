import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/modules/chat/chat_action_definition.dart';
import 'package:wukong_im_app/modules/chat/chat_action_dispatcher.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

void main() {
  test('choose image dispatch returns message content result', () async {
    final imageContent = WKImageContent(320, 180)..localPath = 'C:/tmp/a.png';
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => imageContent,
      pickFile: (_) async => null,
      pickLocation: (_) async => null,
      pickCard: (_) async => null,
      pickRichText: (_) async => null,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.chooseImage,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionMessageResult>());
    expect((result as ChatActionMessageResult).content, same(imageContent));
  });

  test('choose file dispatch returns message content result', () async {
    final fileContent = WKFileContent()
      ..localPath = 'C:/tmp/a.pdf'
      ..name = 'a.pdf'
      ..size = 128
      ..suffix = 'pdf';
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => null,
      pickFile: (_) async => fileContent,
      pickLocation: (_) async => null,
      pickCard: (_) async => null,
      pickRichText: (_) async => null,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.chooseFile,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionMessageResult>());
    expect((result as ChatActionMessageResult).content, same(fileContent));
  });

  test('send location dispatch returns message content result', () async {
    final locationContent = WKLocationContent()
      ..latitude = 31.2304
      ..longitude = 121.4737
      ..title = 'Shanghai'
      ..address = 'Huangpu';
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => null,
      pickFile: (_) async => null,
      pickLocation: (_) async => locationContent,
      pickCard: (_) async => null,
      pickRichText: (_) async => null,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.sendLocation,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionMessageResult>());
    expect((result as ChatActionMessageResult).content, same(locationContent));
  });

  test('choose card dispatch returns message content result', () async {
    final cardContent = WKCardContent('u123', 'tester');
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => null,
      pickFile: (_) async => null,
      pickLocation: (_) async => null,
      pickCard: (_) async => cardContent,
      pickRichText: (_) async => null,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.chooseCard,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionMessageResult>());
    expect((result as ChatActionMessageResult).content, same(cardContent));
  });

  test('compose rich text dispatch returns message content result', () async {
    final richTextContent = WKRichTextContent(
      title: 'Daily Brief',
      body: 'Hello rich world',
    );
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => null,
      pickFile: (_) async => null,
      pickLocation: (_) async => null,
      pickCard: (_) async => null,
      pickRichText: (_) async => richTextContent,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.composeRichText,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionMessageResult>());
    expect((result as ChatActionMessageResult).content, same(richTextContent));
  });

  test('choose image dispatch returns noop when picker returns null', () async {
    final dispatcher = ChatActionDispatcher(
      pickImage: (_) async => null,
      pickFile: (_) async => null,
      pickLocation: (_) async => null,
      pickCard: (_) async => null,
      pickRichText: (_) async => null,
    );

    final result = await dispatcher.dispatch(
      ChatActionId.chooseImage,
      const ChatActionDispatchContext(),
    );

    expect(result, isA<ChatActionNoopResult>());
  });
}
