import 'dart:async';

typedef ProbeRunner = Future<void> Function(String reason);
typedef ProbeErrorHandler = void Function(Object error, StackTrace stackTrace);

class ProbeScheduler {
  ProbeScheduler({required ProbeRunner runProbe, ProbeErrorHandler? onError})
    : _runProbe = runProbe,
      _onError = onError;

  final ProbeRunner _runProbe;
  final ProbeErrorHandler? _onError;
  bool _running = false;
  bool _pending = false;

  bool get isRunning => _running;

  void request(String reason) {
    if (_running) {
      _pending = true;
      return;
    }
    unawaited(_drain(reason));
  }

  Future<void> _drain(String reason) async {
    _running = true;
    var nextReason = reason;
    try {
      while (true) {
        _pending = false;
        try {
          await _runProbe(nextReason);
        } catch (error, stackTrace) {
          _onError?.call(error, stackTrace);
        }
        if (!_pending) {
          break;
        }
        nextReason = 'pending';
      }
    } finally {
      _running = false;
    }
  }
}
