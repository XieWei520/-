import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_coordinator.dart';
import 'package:wukong_im_app/modules/chat/chat_call_entry_service.dart';

void main() {
  test(
    'runPersonalCall handles the start decision and releases busy state',
    () async {
      final service = _FakeChatCallEntryService((
        callType, {
        required channelId,
        required channelType,
      }) async {
        return ChatCallEntryDecision.start(callType);
      });
      final coordinator = ChatCallEntryCoordinator(service: service);
      ChatCallEntryDecision? handledDecision;

      await coordinator.runPersonalCall(
        CallType.audio,
        channelId: 'u_audio',
        channelType: 1,
        handleDecision: (decision) async {
          handledDecision = decision;
        },
      );

      expect(handledDecision, isNotNull);
      expect(handledDecision!.shouldStart, isTrue);
      expect(handledDecision!.callType, CallType.audio);
      expect(coordinator.isOpeningCallPage, isFalse);
      expect(service.calls, <String>['audio:u_audio:1']);
    },
  );

  test('runPersonalCall suppresses duplicate requests while busy', () async {
    final gate = Completer<void>();
    final service = _FakeChatCallEntryService((
      callType, {
      required channelId,
      required channelType,
    }) async {
      await gate.future;
      return ChatCallEntryDecision.start(callType);
    });
    final coordinator = ChatCallEntryCoordinator(service: service);
    final handledTypes = <CallType>[];

    final first = coordinator.runPersonalCall(
      CallType.video,
      channelId: 'u_video',
      channelType: 1,
      handleDecision: (decision) async {
        handledTypes.add(decision.callType!);
      },
    );
    await coordinator.runPersonalCall(
      CallType.video,
      channelId: 'u_video',
      channelType: 1,
      handleDecision: (decision) async {
        handledTypes.add(decision.callType!);
      },
    );
    gate.complete();
    await first;

    expect(handledTypes, <CallType>[CallType.video]);
    expect(service.calls, <String>['video:u_video:1']);
    expect(coordinator.isOpeningCallPage, isFalse);
  });

  test('runGroupCall ignores concurrent group call opens', () async {
    final gate = Completer<void>();
    final events = <String>[];
    final coordinator = ChatCallEntryCoordinator(
      service: _FakeChatCallEntryService((
        callType, {
        required channelId,
        required channelType,
      }) async {
        throw StateError('unused');
      }),
    );

    final first = coordinator.runGroupCall(() async {
      events.add('first');
      await gate.future;
    });
    final second = coordinator.runGroupCall(() async {
      events.add('second');
    });

    await second;
    gate.complete();
    await first;

    expect(events, <String>['first']);
    expect(coordinator.isOpeningCallPage, isFalse);
  });
}

class _FakeChatCallEntryService implements ChatCallEntryService {
  _FakeChatCallEntryService(this.onPrepare);

  final Future<ChatCallEntryDecision> Function(
    CallType callType, {
    required String channelId,
    required int channelType,
  })
  onPrepare;
  final List<String> calls = <String>[];

  @override
  Future<ChatCallEntryDecision> prepareOutgoingCall(
    CallType callType, {
    required String channelId,
    required int channelType,
  }) {
    calls.add('${callType.name}:$channelId:$channelType');
    return onPrepare(callType, channelId: channelId, channelType: channelType);
  }
}
