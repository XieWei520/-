import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_message_favorite_registry.dart';
import 'chat_scene_gateway.dart';
import 'message_content_preview.dart';
import 'message_forwarding.dart';

typedef ChatMessageClipboardSink = Future<void> Function(String text);

const String _favoriteSuccessMessage = '\u5df2\u6536\u85cf';
const String _favoriteFailureMessage = '\u6536\u85cf\u5931\u8d25';
const String _copySuccessMessage = '\u5df2\u590d\u5236';
const String _deleteSuccessMessage = '\u5df2\u5220\u9664';
const String _recallSuccessMessage = '\u5df2\u64a4\u56de';
const String _reactionSuccessMessage =
    '\u5df2\u66f4\u65b0\u8868\u60c5\u56de\u5e94';
const String _pinnedSuccessMessage = '\u5df2\u66f4\u65b0\u7f6e\u9876\u72b6\u6001';

@immutable
class ChatForwardRequest {
  ChatForwardRequest({required List<ForwardPayload> payloads})
    : payloads = List<ForwardPayload>.unmodifiable(payloads);

  final List<ForwardPayload> payloads;
}

@immutable
class ChatMessageEditRequest {
  const ChatMessageEditRequest({
    required this.message,
    required this.messageId,
    required this.messageSeq,
    required this.initialText,
  });

  final WKMsg message;
  final String messageId;
  final int messageSeq;
  final String initialText;
}

@immutable
class ChatMessageActionState {
  ChatMessageActionState({
    this.feedbackMessage,
    this.forwardRequest,
    this.editRequest,
    Set<String> busyOperationKeys = const <String>{},
    Set<String> knownFavoriteKeys = const <String>{},
  }) : busyOperationKeys = Set<String>.unmodifiable(busyOperationKeys),
       knownFavoriteKeys = Set<String>.unmodifiable(knownFavoriteKeys);

  final String? feedbackMessage;
  final ChatForwardRequest? forwardRequest;
  final ChatMessageEditRequest? editRequest;
  final Set<String> busyOperationKeys;
  final Set<String> knownFavoriteKeys;

  ChatMessageActionState copyWith({
    String? feedbackMessage,
    bool clearFeedbackMessage = false,
    ChatForwardRequest? forwardRequest,
    bool clearForwardRequest = false,
    ChatMessageEditRequest? editRequest,
    bool clearEditRequest = false,
    Set<String>? busyOperationKeys,
    Set<String>? knownFavoriteKeys,
  }) {
    return ChatMessageActionState(
      feedbackMessage: clearFeedbackMessage
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      forwardRequest: clearForwardRequest
          ? null
          : (forwardRequest ?? this.forwardRequest),
      editRequest: clearEditRequest ? null : (editRequest ?? this.editRequest),
      busyOperationKeys: busyOperationKeys ?? this.busyOperationKeys,
      knownFavoriteKeys: knownFavoriteKeys ?? this.knownFavoriteKeys,
    );
  }
}

class ChatMessageActionController
    extends StateNotifier<ChatMessageActionState> {
  ChatMessageActionController({
    required ChatSceneGateway gateway,
    ChatMessageFavoriteRegistry? favoriteRegistry,
    ChatMessageClipboardSink? clipboardSink,
  }) : this._(
         gateway: gateway,
         favoriteRegistry:
             favoriteRegistry ?? SharedPrefsChatMessageFavoriteRegistry(),
         clipboardSink: clipboardSink ?? _defaultClipboardSink,
       );

  ChatMessageActionController._({
    required ChatSceneGateway gateway,
    required ChatMessageFavoriteRegistry favoriteRegistry,
    required ChatMessageClipboardSink clipboardSink,
  }) : _gateway = gateway,
       _favoriteRegistry = favoriteRegistry,
       _clipboardSink = clipboardSink,
       super(
         ChatMessageActionState(knownFavoriteKeys: favoriteRegistry.snapshot()),
       );

  final ChatSceneGateway _gateway;
  final ChatMessageFavoriteRegistry _favoriteRegistry;
  final ChatMessageClipboardSink _clipboardSink;

  static Future<void> _defaultClipboardSink(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> favorite(WKMsg message) async {
    final favoriteKeys = favoriteMessageKeysOf(message);
    if (favoriteKeys.isEmpty) {
      state = state.copyWith(feedbackMessage: _favoriteFailureMessage);
      throw UnsupportedError(
        'Favorite is unsupported for messages without identity.',
      );
    }
    if (_containsAny(state.busyOperationKeys, favoriteKeys)) {
      return;
    }
    if (_containsAnyKnownFavoriteKey(favoriteKeys)) {
      try {
        await _markFavoriteKeysIfMissing(favoriteKeys);
      } catch (_) {
        // Best effort only: already-known favorites should remain success.
      }
      state = state.copyWith(
        feedbackMessage: _favoriteSuccessMessage,
        knownFavoriteKeys: {...state.knownFavoriteKeys, ...favoriteKeys},
      );
      return;
    }

    state = state.copyWith(
      busyOperationKeys: {...state.busyOperationKeys, ...favoriteKeys},
    );
    try {
      await _gateway.addFavorite(message);
      await _markFavoriteKeysIfMissing(favoriteKeys);
      state = state.copyWith(
        feedbackMessage: _favoriteSuccessMessage,
        knownFavoriteKeys: {...state.knownFavoriteKeys, ...favoriteKeys},
      );
    } catch (_) {
      state = state.copyWith(feedbackMessage: _favoriteFailureMessage);
      rethrow;
    } finally {
      final clearedBusy = {...state.busyOperationKeys}..removeAll(favoriteKeys);
      state = state.copyWith(busyOperationKeys: clearedBusy);
    }
  }

  Future<void> copy(WKMsg message) async {
    final visibleText = resolveVisibleTextMessage(message).trim();
    if (visibleText.isEmpty) {
      return;
    }
    await _clipboardSink(visibleText);
    state = state.copyWith(feedbackMessage: _copySuccessMessage);
  }

  Future<void> deleteMessage(WKMsg message) async {
    final messageIdentity = _messageIdentityOf(message);
    if (messageIdentity != null &&
        state.busyOperationKeys.contains(messageIdentity)) {
      return;
    }
    if (messageIdentity == null) {
      await _gateway.deleteSelfMessage(message);
      state = state.copyWith(feedbackMessage: _deleteSuccessMessage);
      return;
    }

    final nextBusy = {...state.busyOperationKeys, messageIdentity};
    state = state.copyWith(busyOperationKeys: nextBusy);
    try {
      await _gateway.deleteSelfMessage(message);
      state = state.copyWith(feedbackMessage: _deleteSuccessMessage);
    } finally {
      final clearedBusy = {...state.busyOperationKeys}..remove(messageIdentity);
      state = state.copyWith(busyOperationKeys: clearedBusy);
    }
  }

  Future<void> recall(WKMsg message) async {
    final messageIdentity = _messageIdentityOf(message);
    if (messageIdentity != null &&
        state.busyOperationKeys.contains(messageIdentity)) {
      return;
    }
    if (messageIdentity == null) {
      await _gateway.recallMessage(message);
      state = state.copyWith(feedbackMessage: _recallSuccessMessage);
      return;
    }

    final nextBusy = {...state.busyOperationKeys, messageIdentity};
    state = state.copyWith(busyOperationKeys: nextBusy);
    try {
      await _gateway.recallMessage(message);
      state = state.copyWith(feedbackMessage: _recallSuccessMessage);
    } finally {
      final clearedBusy = {...state.busyOperationKeys}..remove(messageIdentity);
      state = state.copyWith(busyOperationKeys: clearedBusy);
    }
  }

  Future<void> toggleReaction(WKMsg message, String emoji) async {
    await _gateway.toggleReaction(message, emoji);
    state = state.copyWith(feedbackMessage: _reactionSuccessMessage);
  }

  Future<void> togglePinned(WKMsg message) async {
    await _gateway.togglePinnedMessage(message);
    state = state.copyWith(feedbackMessage: _pinnedSuccessMessage);
  }

  void prepareForward(List<WKMsg> messages) {
    final payloads = buildForwardPayloads(messages);
    state = state.copyWith(
      forwardRequest: ChatForwardRequest(payloads: payloads),
      clearEditRequest: true,
    );
  }

  void prepareEdit(WKMsg message) {
    final messageId = message.messageID.trim();
    if (messageId.isEmpty) {
      return;
    }
    state = state.copyWith(
      editRequest: ChatMessageEditRequest(
        message: message,
        messageId: messageId,
        messageSeq: message.messageSeq,
        initialText: resolveVisibleTextMessage(message),
      ),
      clearForwardRequest: true,
    );
  }

  void clearFeedbackMessage() {
    if (state.feedbackMessage == null) {
      return;
    }
    state = state.copyWith(clearFeedbackMessage: true);
  }

  void clearTransientState() {
    state = state.copyWith(
      clearFeedbackMessage: true,
      clearForwardRequest: true,
      clearEditRequest: true,
    );
  }

  String? _messageIdentityOf(WKMsg message) {
    final messageId = message.messageID.trim();
    if (messageId.isNotEmpty) {
      return messageId;
    }
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      return clientMsgNo;
    }
    return null;
  }

  bool _containsAny(Set<String> haystack, Iterable<String> keys) {
    for (final key in keys) {
      if (haystack.contains(key)) {
        return true;
      }
    }
    return false;
  }

  bool _containsAnyKnownFavoriteKey(Iterable<String> keys) {
    for (final key in keys) {
      if (state.knownFavoriteKeys.contains(key) ||
          _favoriteRegistry.contains(key)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _markFavoriteKeysIfMissing(Iterable<String> keys) async {
    for (final key in keys) {
      if (state.knownFavoriteKeys.contains(key) ||
          _favoriteRegistry.contains(key)) {
        continue;
      }
      await _favoriteRegistry.markFavorited(key);
    }
  }
}
