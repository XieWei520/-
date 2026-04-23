import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

@immutable
class ChatMessageViewModel {
  const ChatMessageViewModel({
    required this.identity,
    required this.message,
    required this.preview,
    required this.system,
    required this.self,
    required this.structured,
    required this.revision,
  });

  final String identity;
  final WKMsg message;
  final String preview;
  final bool system;
  final bool self;
  final Map<String, dynamic>? structured;
  final String revision;

  String get previewText => preview;
  bool get isSystemNotice => system;
  bool get isSelf => self;
  Map<String, dynamic>? get structuredPayload => structured;
}
