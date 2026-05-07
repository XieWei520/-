import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/coordinators/command_dispatcher.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('CommandDispatcher', () {
    test(
      'plans command side effects without touching Riverpod or SDK state',
      () {
        const dispatcher = CommandDispatcher();

        final plan = dispatcher.plan(WKCMD()..cmd = ' syncMessageExtra ');

        expect(plan.normalizedCommand, 'syncMessageExtra');
        expect(plan.effects, contains(IMCommandSideEffect.syncMessageExtra));
        expect(plan.shouldNotifyVipExpired, isFalse);
      },
    );

    test(
      'extracts channel target from top-level and nested command payloads',
      () {
        const dispatcher = CommandDispatcher();

        final topLevel = dispatcher.resolveChannelTarget(
          WKCMD()
            ..cmd = 'syncMessageExtra'
            ..param = <String, dynamic>{
              'channel_id': 'ch1',
              'channel_type': WKChannelType.personal,
            },
        );
        expect(topLevel?.channelId, 'ch1');
        expect(topLevel?.channelType, WKChannelType.personal);

        final nested = dispatcher.resolveChannelTarget(
          WKCMD()
            ..cmd = 'syncMessageExtra'
            ..param = <String, dynamic>{
              'payload': <String, dynamic>{
                'channel_id': 'group1',
                'channel_type': WKChannelType.group,
              },
            },
        );
        expect(nested?.channelId, 'group1');
        expect(nested?.channelType, WKChannelType.group);
      },
    );

    test('isolates vip_expired as a notification plan flag', () {
      const dispatcher = CommandDispatcher();

      final plan = dispatcher.plan(WKCMD()..cmd = ' vip_expired ');

      expect(plan.effects, isEmpty);
      expect(plan.shouldNotifyVipExpired, isTrue);
    });
  });
}
