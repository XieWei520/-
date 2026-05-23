import '../../data/models/call.dart';
import 'chat_call_entry_service.dart';

typedef ChatCallDecisionHandler =
    Future<void> Function(ChatCallEntryDecision decision);

class ChatCallEntryCoordinator {
  ChatCallEntryCoordinator({required ChatCallEntryService service})
    : _service = service;

  final ChatCallEntryService _service;
  bool _isOpeningCallPage = false;

  bool get isOpeningCallPage => _isOpeningCallPage;

  Future<void> runPersonalCall(
    CallType callType, {
    required String channelId,
    required int channelType,
    required ChatCallDecisionHandler handleDecision,
  }) async {
    if (_isOpeningCallPage) {
      return;
    }
    _isOpeningCallPage = true;
    try {
      final decision = await _service.prepareOutgoingCall(
        callType,
        channelId: channelId,
        channelType: channelType,
      );
      await handleDecision(decision);
    } finally {
      _isOpeningCallPage = false;
    }
  }

  Future<void> runGroupCall({
    required String channelId,
    required int channelType,
    required ChatCallDecisionHandler handleDecision,
  }) async {
    if (_isOpeningCallPage) {
      return;
    }
    _isOpeningCallPage = true;
    try {
      final decision = await _service.prepareOutgoingCall(
        CallType.video,
        channelId: channelId,
        channelType: channelType,
      );
      await handleDecision(decision);
    } finally {
      _isOpeningCallPage = false;
    }
  }
}
