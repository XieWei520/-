import 'dart:async';

import 'call_state_machine.dart';

final CallStore sharedCallStore = CallStore(machine: const CallStateMachine());

class CallStore {
  CallStore({required CallStateMachine machine, CallSessionState? initialState})
    : _machine = machine,
      _state = initialState ?? const CallSessionState.idle();

  final CallStateMachine _machine;
  final StreamController<CallSessionState> _stateController =
      StreamController<CallSessionState>.broadcast();
  final StreamController<CallEvent> _eventController =
      StreamController<CallEvent>.broadcast();

  CallSessionState _state;
  bool _isDisposed = false;

  CallSessionState get state => _state;
  Stream<CallSessionState> get stream => _stateController.stream;
  Stream<CallEvent> get events => _eventController.stream;

  bool apply(CallEvent event) {
    if (_isDisposed) {
      return false;
    }
    final accepted = _machine.accepts(_state, event);
    if (!accepted) {
      return false;
    }

    final next = _machine.reduce(_state, event);
    _eventController.add(event);
    if (next != _state) {
      _state = next;
      _stateController.add(next);
    } else {
      _state = next;
    }
    return true;
  }

  void reset() {
    if (_isDisposed) {
      return;
    }
    _state = const CallSessionState.idle();
    _stateController.add(_state);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _stateController.close();
    await _eventController.close();
  }
}
