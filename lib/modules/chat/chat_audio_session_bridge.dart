import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

part 'chat_audio_session_bridge_stub.dart';
part 'chat_audio_session_bridge_mobile.dart';

enum ChatAudioSessionUseCase { record, playback }

abstract class ChatAudioSessionBridge {
  Future<void> activate(ChatAudioSessionUseCase useCase);

  Future<void> deactivate();

  Future<void> setSpeakerphone(bool enabled);
}

ChatAudioSessionBridge createChatAudioSessionBridge() {
  if (kIsWeb) {
    return const ChatAudioSessionBridgeStub();
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return const ChatAudioSessionBridgeMobile();
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return const ChatAudioSessionBridgeStub();
  }
}
