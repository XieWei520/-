import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/service/im/im_command_effect_coordinator.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifies vip expiration handlers from a stable snapshot', () {
    final coordinator = _coordinator();
    var firstCount = 0;
    var secondCount = 0;

    coordinator.registerVipExpiredHandler(
      key: 'first',
      handler: () {
        firstCount += 1;
        coordinator.unregisterVipExpiredHandler('second');
      },
    );
    coordinator.registerVipExpiredHandler(
      key: 'second',
      handler: () {
        secondCount += 1;
      },
    );

    coordinator.handleCommand(WKCMD()..cmd = ' vip_expired ');
    coordinator.handleCommand(WKCMD()..cmd = 'vip_expired');

    expect(firstCount, 2);
    expect(secondCount, 1);
  });

  test('invalidates contact providers for friend commands', () {
    final invalidated = <ProviderOrFamily>[];
    final coordinator = _coordinator(invalidateProvider: invalidated.add);

    coordinator.handleCommand(WKCMD()..cmd = 'friendAccept');
    coordinator.handleCommand(WKCMD()..cmd = 'friendRequest');

    expect(
      invalidated.where((provider) => identical(provider, friendListProvider)),
      hasLength(1),
    );
    expect(
      invalidated.where(
        (provider) => identical(provider, friendRequestListProvider),
      ),
      hasLength(2),
    );
  });

  test('schedules sync side effects with raw command reasons', () async {
    final conversationReasons = <String?>[];
    final reminderReasons = <String?>[];
    final messageExtras = <_MessageExtraSync>[];
    final coordinator = _coordinator(
      syncConversationExtras: ({reason}) async {
        conversationReasons.add(reason);
      },
      syncReminders: ({reason}) async {
        reminderReasons.add(reason);
      },
      syncMessageExtras:
          ({required channelId, required channelType, reason}) async {
            messageExtras.add(
              _MessageExtraSync(
                channelId: channelId,
                channelType: channelType,
                reason: reason,
              ),
            );
          },
    );

    coordinator.handleCommand(WKCMD()..cmd = 'wk_sync_conversation_extra');
    coordinator.handleCommand(WKCMD()..cmd = 'wk_sync_reminders');
    coordinator.handleCommand(
      WKCMD()
        ..cmd = ' syncMessageExtra '
        ..param = <String, dynamic>{
          'channel_id': 'group-1',
          'channel_type': WKChannelType.group,
        },
    );
    await Future<void>.delayed(Duration.zero);

    expect(conversationReasons, <String?>['cmd:wk_sync_conversation_extra']);
    expect(reminderReasons, <String?>['cmd:wk_sync_reminders']);
    expect(messageExtras, <_MessageExtraSync>[
      const _MessageExtraSync(
        channelId: 'group-1',
        channelType: WKChannelType.group,
        reason: 'cmd: syncMessageExtra ',
      ),
    ]);
  });

  test('forwards every command to conversation activity handling', () async {
    final forwarded = <String>[];
    final coordinator = _coordinator(
      currentUidLoader: () => 'u_self',
      handleConversationActivity:
          (cmd, {required currentUid, required channelLookup}) async {
            forwarded.add('${cmd.cmd}:$currentUid:${channelLookup != null}');
          },
    );

    coordinator.handleCommand(WKCMD()..cmd = 'wk_typing');
    await Future<void>.delayed(Duration.zero);

    expect(forwarded, <String>['wk_typing:u_self:true']);
  });
}

ImCommandEffectCoordinator _coordinator({
  void Function(ProviderOrFamily provider)? invalidateProvider,
  String Function()? currentUidLoader,
  ImCommandConversationActivityHandler? handleConversationActivity,
  ImCommandSimpleSyncTask? syncConversationExtras,
  ImCommandSimpleSyncTask? syncReminders,
  ImCommandMessageExtraSyncTask? syncMessageExtras,
}) {
  return ImCommandEffectCoordinator(
    invalidateProvider: invalidateProvider,
    currentUidLoader: currentUidLoader ?? () => 'u_self',
    channelLookup: (channelId, channelType) async => null,
    handleConversationActivity:
        handleConversationActivity ??
        (cmd, {required currentUid, required channelLookup}) async {},
    syncConversationExtras: syncConversationExtras ?? ({reason}) async {},
    syncReminders: syncReminders ?? ({reason}) async {},
    syncMessageExtras:
        syncMessageExtras ??
        ({required channelId, required channelType, reason}) async {},
  );
}

class _MessageExtraSync {
  const _MessageExtraSync({
    required this.channelId,
    required this.channelType,
    required this.reason,
  });

  final String channelId;
  final int channelType;
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is _MessageExtraSync &&
        other.channelId == channelId &&
        other.channelType == channelType &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(channelId, channelType, reason);
}
