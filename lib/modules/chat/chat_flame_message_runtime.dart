import 'dart:async';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

typedef ChatFlameClock = DateTime Function();
typedef ChatFlameTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

abstract class ChatFlameMessageStore {
  Future<List<WKMsg>> getWithFlame();

  Future<void> updateViewedAt(String clientMsgNo, int viewedAtMs);

  Future<void> deleteWithClientMsgNo(String clientMsgNo);

  WKMsg? findByClientMsgNo(String clientMsgNo);
}

class WkImChatFlameMessageStore implements ChatFlameMessageStore {
  @override
  Future<List<WKMsg>> getWithFlame() {
    return WKIM.shared.messageManager.getWithFlame();
  }

  @override
  Future<void> deleteWithClientMsgNo(String clientMsgNo) {
    return WKIM.shared.messageManager.deleteWithClientMsgNo(clientMsgNo);
  }

  @override
  WKMsg? findByClientMsgNo(String clientMsgNo) {
    return null;
  }

  @override
  Future<void> updateViewedAt(String clientMsgNo, int viewedAtMs) async {
    await WKIM.shared.messageManager.updateViewedAt(viewedAtMs, clientMsgNo);
    final refreshed = await WKIM.shared.messageManager.getWithClientMsgNo(
      clientMsgNo,
    );
    if (refreshed == null) {
      return;
    }
    refreshed
      ..viewed = 1
      ..viewedAt = viewedAtMs;
    WKIM.shared.messageManager.setRefreshMsg(refreshed);
  }
}

class ChatFlameMessageRuntime {
  ChatFlameMessageRuntime({
    ChatFlameMessageStore? store,
    ChatFlameClock? now,
    ChatFlameTimerFactory? createTimer,
  }) : _store = store ?? WkImChatFlameMessageStore(),
       _now = now ?? DateTime.now,
       _createTimer = createTimer ?? _defaultCreateTimer;

  final ChatFlameMessageStore _store;
  final ChatFlameClock _now;
  final ChatFlameTimerFactory _createTimer;
  final Map<String, Timer> _deleteTimers = <String, Timer>{};

  Future<void> markVisibleMessages(Iterable<WKMsg> messages) async {
    for (final message in messages) {
      if (!_shouldAutoViewOnVisible(message)) {
        continue;
      }
      await markViewed(message);
    }
  }

  Future<void> markViewed(
    WKMsg message, {
    int? ttlSecondsOverride,
  }) async {
    if (!isFlameMessage(message)) {
      return;
    }

    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isEmpty) {
      return;
    }

    final nowMs = _now().millisecondsSinceEpoch;
    final int viewedAtMs;
    if (message.viewed == 1 || message.viewedAt > 0) {
      viewedAtMs = message.viewedAt > 0 ? message.viewedAt : nowMs;
      message
        ..viewed = 1
        ..viewedAt = viewedAtMs;
    } else {
      viewedAtMs = nowMs;
      message
        ..viewed = 1
        ..viewedAt = viewedAtMs;
      await _store.updateViewedAt(clientMsgNo, viewedAtMs);
    }

    _scheduleDelete(
      clientMsgNo: clientMsgNo,
      ttlSeconds: ttlSecondsOverride ?? flameSecondsOf(message),
      viewedAtMs: viewedAtMs,
    );
  }

  Future<void> sweepViewedMessages() async {
    final nowMs = _now().millisecondsSinceEpoch;
    final messages = await _store.getWithFlame();
    for (final message in messages) {
      if (!_shouldDeleteViewedMessage(message, nowMs)) {
        continue;
      }
      final clientMsgNo = message.clientMsgNO.trim();
      if (clientMsgNo.isEmpty) {
        continue;
      }
      _deleteTimers.remove(clientMsgNo)?.cancel();
      await _store.deleteWithClientMsgNo(clientMsgNo);
    }
  }

  void dispose() {
    for (final timer in _deleteTimers.values) {
      timer.cancel();
    }
    _deleteTimers.clear();
  }

  void _scheduleDelete({
    required String clientMsgNo,
    required int ttlSeconds,
    required int viewedAtMs,
  }) {
    _deleteTimers.remove(clientMsgNo)?.cancel();
    if (ttlSeconds <= 0 || viewedAtMs <= 0) {
      return;
    }

    final expireAtMs = viewedAtMs + (ttlSeconds * 1000);
    final delayMs = expireAtMs - _now().millisecondsSinceEpoch;
    if (delayMs <= 0) {
      unawaited(_store.deleteWithClientMsgNo(clientMsgNo));
      return;
    }

    _deleteTimers[clientMsgNo] = _createTimer(
      Duration(milliseconds: delayMs),
      () {
        _deleteTimers.remove(clientMsgNo);
        unawaited(_store.deleteWithClientMsgNo(clientMsgNo));
      },
    );
  }

  bool _shouldAutoViewOnVisible(WKMsg message) {
    if (!isFlameMessage(message)) {
      return false;
    }
    if (message.viewed == 1 || message.viewedAt > 0) {
      return true;
    }
    switch (message.contentType) {
      case WkMessageContentType.image:
      case WkMessageContentType.video:
      case WkMessageContentType.voice:
        return false;
      default:
        return true;
    }
  }

  bool _shouldDeleteViewedMessage(WKMsg message, int nowMs) {
    if (!isFlameMessage(message) || message.viewed != 1) {
      return false;
    }
    final flameSecond = flameSecondsOf(message);
    if (flameSecond == 0) {
      return true;
    }
    final viewedAtMs = message.viewedAt;
    if (viewedAtMs <= 0) {
      return true;
    }
    return nowMs - viewedAtMs > flameSecond * 1000;
  }

  static Timer _defaultCreateTimer(
    Duration duration,
    void Function() callback,
  ) {
    return Timer(duration, callback);
  }
}

bool isFlameMessage(WKMsg message) {
  if (message.flame == 1) {
    return true;
  }
  final localExtra = message.localExtraMap;
  if (localExtra is Map) {
    return _readInt(localExtra['flame']) == 1;
  }
  return false;
}

int flameSecondsOf(WKMsg message) {
  if (message.flameSecond > 0) {
    return message.flameSecond;
  }
  final localExtra = message.localExtraMap;
  if (localExtra is Map) {
    return _readInt(localExtra['flame_second'] ?? localExtra['flameSecond']);
  }
  return 0;
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
