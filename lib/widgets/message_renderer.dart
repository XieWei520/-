import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../modules/chat/chat_message_view_model.dart';

abstract class MessageRenderer {
  Widget build(BuildContext context, MessageRenderContext renderContext);
}

class MessageRenderContext {
  const MessageRenderContext({
    required this.model,
    required this.effectiveContentType,
    required this.previewText,
    required this.isSelf,
    this.useWarmTextColors = false,
  });

  final ChatMessageViewModel model;
  final int effectiveContentType;
  final String previewText;
  final bool isSelf;
  final bool useWarmTextColors;

  WKMsg get message => model.message;
  Map<String, dynamic>? get structuredPayload => model.structuredPayload;
}

class MessageRendererRegistration {
  const MessageRendererRegistration({
    required this.contentType,
    required this.renderer,
  });

  final int contentType;
  final MessageRenderer renderer;
}

class DelegatingMessageRenderer implements MessageRenderer {
  const DelegatingMessageRenderer(this.builder);

  final Widget Function(
    BuildContext context,
    MessageRenderContext renderContext,
  )
  builder;

  @override
  Widget build(BuildContext context, MessageRenderContext renderContext) {
    return builder(context, renderContext);
  }
}
