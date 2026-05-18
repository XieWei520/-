import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../wukong_base/msg/msg_content_type.dart';
import 'im_word_sync_models.dart';
import 'im_word_sync_store.dart';

class ImWordRuntimeFilterService {
  const ImWordRuntimeFilterService({required this.wordStore});

  final ImWordSyncStore wordStore;

  Future<void> loadStoredWordCaches() {
    return wordStore.loadStoredWordCaches();
  }

  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() {
    return wordStore.loadSensitiveWordsSnapshot();
  }

  WKMsg? buildSensitiveWordTipMessageIfNeeded(
    WKMsg message, {
    required String currentUid,
  }) {
    if (message.contentType != WkMessageContentType.text) {
      return null;
    }
    final snapshot = wordStore.loadSensitiveWordsSnapshot();
    if (snapshot.isEmpty) {
      return null;
    }
    final text = message.messageContent?.displayText().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final containsSensitiveWord = snapshot.list.any(text.contains);
    if (!containsSensitiveWord) {
      return null;
    }

    final tip = WKMsg()
      ..channelID = message.channelID
      ..channelType = message.channelType
      ..fromUID = currentUid
      ..contentType = MsgContentType.sensitiveWord
      ..content = jsonEncode(<String, dynamic>{
        'content': snapshot.tips,
        'type': MsgContentType.sensitiveWord,
      })
      ..status = WKSendMsgResult.sendSuccess
      ..header.redDot = false;
    tip.setChannelInfo(message.getChannelInfo());
    return tip;
  }

  bool applyProhibitWordsToMessage(WKMsg message) {
    if (message.contentType != WkMessageContentType.text) {
      return false;
    }
    final words = wordStore.resolveProhibitWords();
    if (words.isEmpty) {
      return false;
    }

    final editedContent = message.wkMsgExtra?.messageContent;
    if (editedContent != null &&
        editedContent.displayText().trim().isNotEmpty) {
      final masked = _maskTextWithProhibitWords(
        editedContent.displayText(),
        words,
      );
      if (masked == editedContent.content) {
        return false;
      }
      editedContent.content = masked;
      return true;
    }

    final baseContent = message.messageContent;
    if (baseContent == null || baseContent.displayText().trim().isEmpty) {
      return false;
    }
    final masked = _maskTextWithProhibitWords(baseContent.displayText(), words);
    if (masked == baseContent.content) {
      return false;
    }
    baseContent.content = masked;
    return true;
  }

  String _maskTextWithProhibitWords(
    String source,
    List<ProhibitWordEntry> words,
  ) {
    var masked = source;
    for (final word in words) {
      final target = word.content.trim();
      if (target.isEmpty || !masked.contains(target)) {
        continue;
      }
      masked = masked.replaceAll(target, '*' * target.length);
    }
    return masked;
  }
}
