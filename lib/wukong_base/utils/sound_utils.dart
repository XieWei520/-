enum SoundType { message, call, recording }

class WKPlaySound {
  static WKPlaySound? _instance;
  bool _isInitialized = false;

  WKPlaySound._();

  static WKPlaySound get instance {
    _instance ??= WKPlaySound._();
    return _instance!;
  }

  Future<void> init() async {
    _isInitialized = true;
  }

  Future<void> playSound(SoundType type, {String? assetPath}) async {
    await init();
  }

  Future<void> playMessageSound() async {
    await playSound(SoundType.message);
  }

  Future<void> playCallSound() async {
    await playSound(SoundType.call);
  }

  Future<void> playRecordingSound() async {
    await playSound(SoundType.recording);
  }

  Future<void> stop() async {}

  Future<void> dispose() async {
    _instance = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
