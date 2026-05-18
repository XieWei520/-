import 'dart:collection';

import 'package:wukongimfluttersdk/db/const.dart';

import '../entity/cmd.dart';

/// Command manager that distributes server commands to listeners.
class WKCMDManager {
  WKCMDManager._privateConstructor() {
    _cmdListeners = HashMap<String, Function(WKCMD)>();
  }

  static final WKCMDManager _instance = WKCMDManager._privateConstructor();
  static WKCMDManager get shared => _instance;

  late final HashMap<String, Function(WKCMD)> _cmdListeners;

  void handleCMD(dynamic json) {
    final String cmd = WKDBConst.readString(json, 'cmd');
    dynamic param = json['param'];

    // Some server command payloads place metadata on the top-level envelope
    // instead of under `param`. Preserve that context for downstream listeners.
    if (param == null && json is Map) {
      final fallbackParam = Map<String, dynamic>.from(json);
      fallbackParam.remove('cmd');
      fallbackParam.remove('param');
      param = fallbackParam;
    }

    if (param is Map) {
      if (!param.containsKey('channel_id')) {
        param['channel_id'] = json['channel_id'];
        param['channel_type'] = json['channel_type'];
      }
    }

    final wkcmd = WKCMD()
      ..cmd = cmd
      ..param = param;
    _notifyListeners(wkcmd);
  }

  void _notifyListeners(WKCMD wkcmd) {
    _cmdListeners.forEach((key, listener) {
      listener(wkcmd);
    });
  }

  void addOnCmdListener(String key, Function(WKCMD) listener) {
    _cmdListeners[key] = listener;
  }

  void removeCmdListener(String key) {
    _cmdListeners.remove(key);
  }
}
