import 'dart:async';

/// Recall status enum
enum RecallStatus {
  idle,
  recalling,
  recalled,
  failed,
}

/// Recall result
class RecallResult {
  final bool success;
  final String? errorMessage;
  final String messageId;

  RecallResult({
    required this.success,
    this.errorMessage,
    required this.messageId,
  });
}

/// Message recall manager
class RecallManager {
  static final RecallManager _instance = RecallManager._internal();
  factory RecallManager() => _instance;
  RecallManager._internal();

  // Recall time limit (seconds) - typically 2 minutes (120 seconds)
  static const int recallTimeLimit = 120;

  // Stream controller for recall updates
  final _recallUpdatesController = StreamController<RecallUpdate>.broadcast();
  Stream<RecallUpdate> get recallUpdates => _recallUpdatesController.stream;

  // Active recall operations
  final Set<String> _recallingMessages = {};

  /// Check if a message can be recalled
  bool canRecall(int messageTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - messageTimestamp) <= recallTimeLimit;
  }

  /// Get remaining time for recall
  int getRemainingRecallTime(int messageTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = now - messageTimestamp;
    return (recallTimeLimit - elapsed).clamp(0, recallTimeLimit);
  }

  /// Check if currently recalling
  bool isRecalling(String messageId) {
    return _recallingMessages.contains(messageId);
  }

  /// Recall a message
  Future<RecallResult> recallMessage(String messageId, String channelId, int channelType) async {
    if (_recallingMessages.contains(messageId)) {
      return RecallResult(
        success: false,
        errorMessage: '正在撤回中',
        messageId: messageId,
      );
    }

    _recallingMessages.add(messageId);
    _notifyRecallStart(messageId, channelId, channelType);

    try {
      // TODO: Call API to recall message
      // final response = await MessageApi.recallMessage(messageId, channelId, channelType);
      // if (response.success) {
      //   return RecallResult(success: true, messageId: messageId);
      // } else {
      //   return RecallResult(success: false, errorMessage: response.message, messageId: messageId);
      // }

      // For demo
      await Future.delayed(const Duration(milliseconds: 500));

      final result = RecallResult(
        success: true,
        messageId: messageId,
      );

      _recallingMessages.remove(messageId);
      _notifyRecallComplete(messageId, channelId, channelType, true);

      return result;
    } catch (e) {
      _recallingMessages.remove(messageId);
      _notifyRecallComplete(messageId, channelId, channelType, false, e.toString());
      return RecallResult(
        success: false,
        errorMessage: e.toString(),
        messageId: messageId,
      );
    }
  }

  /// Cancel recall operation
  void cancelRecall(String messageId) {
    _recallingMessages.remove(messageId);
  }

  void _notifyRecallStart(String messageId, String channelId, int channelType) {
    _recallUpdatesController.add(RecallUpdate(
      type: RecallUpdateType.start,
      messageId: messageId,
      channelId: channelId,
      channelType: channelType,
    ));
  }

  void _notifyRecallComplete(String messageId, String channelId, int channelType, bool success, [String? error]) {
    _recallUpdatesController.add(RecallUpdate(
      type: RecallUpdateType.complete,
      messageId: messageId,
      channelId: channelId,
      channelType: channelType,
      success: success,
      errorMessage: error,
    ));
  }

  void dispose() {
    _recallUpdatesController.close();
  }
}

/// Recall update event
class RecallUpdate {
  final RecallUpdateType type;
  final String messageId;
  final String channelId;
  final int channelType;
  final bool? success;
  final String? errorMessage;

  RecallUpdate({
    required this.type,
    required this.messageId,
    required this.channelId,
    required this.channelType,
    this.success,
    this.errorMessage,
  });
}

/// Recall update type
enum RecallUpdateType {
  start,
  complete,
}
