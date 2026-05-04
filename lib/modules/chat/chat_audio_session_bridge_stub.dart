part of 'chat_audio_session_bridge.dart';

class ChatAudioSessionBridgeStub implements ChatAudioSessionBridge {
  const ChatAudioSessionBridgeStub();

  @override
  Future<void> activate(ChatAudioSessionUseCase useCase) async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> setSpeakerphone(bool enabled) async {}
}
