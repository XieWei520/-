import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/widgets/message_render_registry.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  testWidgets('MessageBubble renders custom content through registry', (
    tester,
  ) async {
    const customType = 880001;
    final registry = MessageRenderRegistry.defaults()
      ..register(
        MessageRendererRegistration(
          contentType: customType,
          renderer: _InlineTestRenderer(),
        ),
      );
    final message = WKMsg()
      ..contentType = customType
      ..content = '{"title":"红包"}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            model: ChatMessageViewModel(
              identity: 'custom-message',
              message: message,
              preview: 'custom preview',
              system: false,
              self: false,
              structured: const <String, dynamic>{'title': '红包'},
              revision: '1',
            ),
            renderRegistry: registry,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('inline-custom-renderer')),
      findsOneWidget,
    );
    expect(find.text('custom:880001'), findsOneWidget);
  });

  test('MessageBubble no longer owns image/video renderer methods', () {
    final source = File('lib/widgets/message_bubble.dart').readAsStringSync();

    expect(source, isNot(contains('Widget _buildImageContent')));
    expect(source, isNot(contains('Widget _buildVideoContent')));
    expect(source, isNot(contains('switch (resolvedContentType)')));
    expect(source, contains('MessageRenderRegistry'));
  });

  test(
    'MessageRenderRegistry documents built-in and custom extension points',
    () {
      final registrySource = File(
        'lib/widgets/message_render_registry.dart',
      ).readAsStringSync();
      final imageRendererSource = File(
        'lib/widgets/message_renderers/image_message_renderer.dart',
      ).readAsStringSync();
      final videoRendererSource = File(
        'lib/widgets/message_renderers/video_message_renderer.dart',
      ).readAsStringSync();

      expect(registrySource, contains('registerCustomMessageRendererExamples'));
      expect(registrySource, contains('910001'));
      expect(registrySource, contains('910002'));
      expect(registrySource, contains('910003'));
      expect(imageRendererSource, contains('implements MessageRenderer'));
      expect(videoRendererSource, contains('implements MessageRenderer'));
    },
  );
}

class _InlineTestRenderer implements MessageRenderer {
  @override
  Widget build(BuildContext context, MessageRenderContext renderContext) {
    return Text(
      'custom:${renderContext.effectiveContentType}',
      key: const ValueKey<String>('inline-custom-renderer'),
    );
  }
}
