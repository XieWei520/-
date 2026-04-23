import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../service/api/login_bridge_api.dart';
import '../domain/auth_repository.dart';

@immutable
class DeviceSessionState {
  const DeviceSessionState({
    this.items = const <LoginBridgeDeviceRecord>[],
    this.isLoading = false,
    this.isQuittingAll = false,
    this.error,
  });

  final List<LoginBridgeDeviceRecord> items;
  final bool isLoading;
  final bool isQuittingAll;
  final String? error;

  DeviceSessionState copyWith({
    List<LoginBridgeDeviceRecord>? items,
    bool? isLoading,
    bool? isQuittingAll,
    String? error,
  }) {
    return DeviceSessionState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isQuittingAll: isQuittingAll ?? this.isQuittingAll,
      error: error,
    );
  }
}

class DeviceSessionController extends StateNotifier<DeviceSessionState> {
  DeviceSessionController({required DeviceSessionRepository repository})
    : _repository = repository,
      super(const DeviceSessionState());

  final DeviceSessionRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.loadDevices();
      state = state.copyWith(items: items, isLoading: false, error: null);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> remove(String deviceId) async {
    state = state.copyWith(error: null);
    try {
      await _repository.deleteDevice(deviceId);
      await load();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> quitAllPcWeb() async {
    state = state.copyWith(isQuittingAll: true, error: null);
    try {
      await _repository.quitPcWebSessions();
      await load();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      state = state.copyWith(isQuittingAll: false, error: state.error);
    }
  }
}
