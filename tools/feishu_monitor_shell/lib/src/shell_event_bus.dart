import 'dart:async';

enum ShellEventType {
  snapshotUpdated('snapshot_updated'),
  captureStateChanged('capture_state_changed'),
  runtimeReloadRequested('runtime_reload_requested'),
  shellError('shell_error');

  const ShellEventType(this.wireName);

  final String wireName;
}

class ShellEvent {
  const ShellEvent({
    required this.type,
    required this.reason,
    required this.updatedAt,
    this.recentEventsCount = 0,
    this.observedConversationsCount = 0,
    this.error = '',
  });

  final ShellEventType type;
  final String reason;
  final DateTime updatedAt;
  final int recentEventsCount;
  final int observedConversationsCount;
  final String error;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.wireName,
      'reason': reason,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'recent_events': recentEventsCount,
      'observed_conversations': observedConversationsCount,
      'error': error,
    };
  }
}

class ShellEventBus {
  final StreamController<ShellEvent> _controller =
      StreamController<ShellEvent>.broadcast();

  Stream<ShellEvent> get stream => _controller.stream;

  void publish(ShellEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> close() => _controller.close();
}
