import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'message_renderer.dart';
import 'message_renderers/image_message_renderer.dart';
import 'message_renderers/video_message_renderer.dart';

export 'message_renderer.dart';

class MessageRenderRegistry {
  MessageRenderRegistry({
    Iterable<MessageRendererRegistration> entries = const [],
  }) {
    registerAll(entries);
  }

  factory MessageRenderRegistry.defaults() {
    return MessageRenderRegistry(
      entries: const <MessageRendererRegistration>[
        MessageRendererRegistration(
          contentType: WkMessageContentType.image,
          renderer: ImageMessageRenderer(),
        ),
        MessageRendererRegistration(
          contentType: WkMessageContentType.video,
          renderer: VideoMessageRenderer(),
        ),
      ],
    );
  }

  final Map<int, MessageRenderer> _renderers = <int, MessageRenderer>{};

  Iterable<MessageRendererRegistration> get registrations sync* {
    for (final entry in _renderers.entries) {
      yield MessageRendererRegistration(
        contentType: entry.key,
        renderer: entry.value,
      );
    }
  }

  void register(MessageRendererRegistration registration) {
    _renderers[registration.contentType] = registration.renderer;
  }

  void registerAll(Iterable<MessageRendererRegistration> registrations) {
    for (final registration in registrations) {
      register(registration);
    }
  }

  void merge(MessageRenderRegistry other) {
    registerAll(other.registrations);
  }

  MessageRenderer? rendererFor(int contentType) {
    return _renderers[contentType];
  }
}

class ExampleLabelMessageRenderer implements MessageRenderer {
  const ExampleLabelMessageRenderer(this.label);

  final String label;

  @override
  Widget build(BuildContext context, MessageRenderContext renderContext) {
    return Text('$label:${renderContext.previewText}');
  }
}

MessageRenderRegistry registerCustomMessageRendererExamples(
  MessageRenderRegistry registry,
) {
  return registry
    ..register(
      const MessageRendererRegistration(
        contentType: 910001,
        renderer: ExampleLabelMessageRenderer('红包'),
      ),
    )
    ..register(
      const MessageRendererRegistration(
        contentType: 910002,
        renderer: ExampleLabelMessageRenderer('名片'),
      ),
    )
    ..register(
      const MessageRendererRegistration(
        contentType: 910003,
        renderer: ExampleLabelMessageRenderer('位置'),
      ),
    );
}
