part of 'chat_audio_session_bridge.dart';

class ChatAudioSessionBridgeMobile implements ChatAudioSessionBridge {
  const ChatAudioSessionBridgeMobile();

  static const MethodChannel _channel = MethodChannel(
    'wukong_im_app/chat_audio_session',
  );

  @override
  Future<void> activate(ChatAudioSessionUseCase useCase) async {
    try {
      await _channel.invokeMethod<void>('activate', <String, dynamic>{
        'useCase': useCase.name,
      });
    } on MissingPluginException {
      // Best-effort bridge: native hook may not be wired yet.
    } on PlatformException {
      // Best-effort bridge: native hook may not be wired yet.
    }
  }

  @override
  Future<void> deactivate() async {
    try {
      await _channel.invokeMethod<void>('deactivate');
    } on MissingPluginException {
      // Best-effort bridge: native hook may not be wired yet.
    } on PlatformException {
      // Best-effort bridge: native hook may not be wired yet.
    }
  }

  @override
  Future<void> setSpeakerphone(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } on MissingPluginException {
      // Best-effort routing: plugin may be absent on current runtime.
    } on PlatformException {
      // Best-effort routing: plugin may be absent on current runtime.
    }
  }
}
