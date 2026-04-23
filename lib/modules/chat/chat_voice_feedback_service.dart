enum ChatVoiceFeedbackEvent {
  recordStarted,
  enterCancelZone,
  leaveCancelZone,
  sendReady,
  tooShort,
  sendFailed,
}

abstract class ChatVoiceFeedbackDriver {
  Future<void> lightImpact();

  Future<void> selectionClick();

  Future<void> playSendCue();

  Future<void> playErrorCue();
}

class ChatVoiceFeedbackService {
  const ChatVoiceFeedbackService({required ChatVoiceFeedbackDriver driver})
    : _driver = driver;

  factory ChatVoiceFeedbackService.noop() {
    return const ChatVoiceFeedbackService(
      driver: _NoopChatVoiceFeedbackDriver(),
    );
  }

  final ChatVoiceFeedbackDriver _driver;

  Future<void> handle(ChatVoiceFeedbackEvent event) {
    return switch (event) {
      ChatVoiceFeedbackEvent.recordStarted => _driver.lightImpact(),
      ChatVoiceFeedbackEvent.enterCancelZone => _driver.selectionClick(),
      ChatVoiceFeedbackEvent.leaveCancelZone => _driver.selectionClick(),
      ChatVoiceFeedbackEvent.sendReady => _driver.playSendCue(),
      ChatVoiceFeedbackEvent.tooShort => _driver.playErrorCue(),
      ChatVoiceFeedbackEvent.sendFailed => _driver.playErrorCue(),
    };
  }
}

class _NoopChatVoiceFeedbackDriver implements ChatVoiceFeedbackDriver {
  const _NoopChatVoiceFeedbackDriver();

  @override
  Future<void> lightImpact() => Future<void>.value();

  @override
  Future<void> playErrorCue() => Future<void>.value();

  @override
  Future<void> playSendCue() => Future<void>.value();

  @override
  Future<void> selectionClick() => Future<void>.value();
}
