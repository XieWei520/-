import 'dart:async';

class ConversationReadEvent {
  final String channelId;
  final int channelType;
  final String fromUid;

  const ConversationReadEvent({
    required this.channelId,
    required this.channelType,
    required this.fromUid,
  });
}

class ConversationReadController {
  ConversationReadController({
    required this.channelId,
    required this.channelType,
    required this.currentUid,
    required this.markConversationRead,
    this.debounce = const Duration(milliseconds: 240),
  });

  final String channelId;
  final int channelType;
  final String currentUid;
  final Future<void> Function(List<String> messageIds) markConversationRead;
  final Duration debounce;

  Timer? _debounceTimer;
  List<String> _visibleMessageIds = const <String>[];
  String _visibleSignature = '';
  String _lastSubmittedSignature = '';
  bool _isMarking = false;
  bool _markQueued = false;
  bool _disposed = false;

  void onVisibleMessageIdsChanged(Iterable<String> messageIds) {
    final normalized = _normalizeMessageIds(messageIds);
    final signature = _signatureFor(normalized);
    _visibleMessageIds = normalized;
    _visibleSignature = signature;

    if (signature.isEmpty || signature == _lastSubmittedSignature) {
      return;
    }

    _markQueued = true;
    if (_isMarking || _disposed) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      unawaited(_drainMarks());
    });
  }

  Future<void> markRead() async {
    if (_visibleSignature.isEmpty) {
      return;
    }

    _markQueued = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _drainMarks();
  }

  Future<void> handleIncomingMessages(
    List<ConversationReadEvent> events,
  ) async {
    final shouldMarkRead = events.any((event) {
      return event.channelType == channelType &&
          event.channelId.trim() == channelId.trim() &&
          event.fromUid.trim() != currentUid.trim();
    });
    if (!shouldMarkRead) {
      return;
    }

    await markRead();
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  Future<void> _drainMarks() async {
    if (_isMarking || _disposed) {
      return;
    }

    _isMarking = true;
    try {
      while (_markQueued && !_disposed) {
        _markQueued = false;
        final messageIds = _visibleMessageIds;
        final signature = _visibleSignature;
        if (messageIds.isEmpty || signature == _lastSubmittedSignature) {
          continue;
        }
        await markConversationRead(messageIds);
        _lastSubmittedSignature = signature;
      }
    } finally {
      _isMarking = false;
      if (_markQueued && !_disposed) {
        _debounceTimer?.cancel();
        _debounceTimer = null;
        unawaited(_drainMarks());
      }
    }
  }

  static List<String> _normalizeMessageIds(Iterable<String> messageIds) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in messageIds) {
      final id = rawId.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      normalized.add(id);
    }
    return List<String>.unmodifiable(normalized);
  }

  static String _signatureFor(List<String> messageIds) {
    if (messageIds.isEmpty) {
      return '';
    }
    return messageIds.join('|');
  }
}
