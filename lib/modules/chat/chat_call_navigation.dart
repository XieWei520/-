import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_scene_providers.dart';

Future<void> pushGroupCallPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String channelId,
  required int channelType,
  String? channelName,
}) {
  final page = ref.read(chatGroupCallPageBuilderProvider)(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
  );
  return Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
}
