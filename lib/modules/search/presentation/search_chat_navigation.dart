import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_page.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';

Future<void> openChatFromLocateIntent({
  required BuildContext context,
  required WidgetRef ref,
  required ChatLocateIntent intent,
  String? fallbackChannelName,
}) async {
  final coordinator = ref.read(chatLocateCoordinatorProvider);
  final request = await coordinator.buildOpenRequestFromIntent(intent);
  if (!context.mounted) {
    return;
  }

  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: request.channelId,
          channelType: request.channelType,
          channelName: request.channelName ?? fallbackChannelName,
          initialAroundOrderSeq: request.orderSeq,
          initialLocateMessageSeq: request.locateMessageSeq,
        ),
      ),
    ),
  );

  final feedbackMessage = request.feedbackMessage;
  if (feedbackMessage == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(feedbackMessage)));
}
