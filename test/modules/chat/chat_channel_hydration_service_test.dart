import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/chat/chat_channel_hydration_service.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'hydrates group flame settings and member count into channel extras',
    () async {
      final service = ChatChannelHydrationService(
        groupInfoLoader: (_, {cancelToken}) async => GroupInfo(
          groupNo: 'g_demo',
          flame: 1,
          flameSecond: 20,
          memberCount: 32,
        ),
        userInfoLoader: (_, {cancelToken}) async => throw StateError('unused'),
      );
      final channel = WKChannel('g_demo', WKChannelType.group)
        ..remoteExtraMap = <String, dynamic>{'existing': 'kept'}
        ..localExtra = <String, dynamic>{};

      final result = await service.hydrateRemoteChannel(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        currentChannel: channel,
      );
      final hydrated = result.channel;

      expect(result.didHydrate, isTrue);
      expect(hydrated, same(channel));
      expect(hydrated?.remoteExtraMap['existing'], 'kept');
      expect(hydrated?.remoteExtraMap['flame'], 1);
      expect(hydrated?.remoteExtraMap['flame_second'], 20);
      expect(hydrated?.remoteExtraMap['member_count'], 32);
      expect(hydrated?.localExtra['flame'], 1);
      expect(hydrated?.localExtra['flame_second'], 20);
    },
  );

  test(
    'hydrates personal identity and flame settings into a fallback channel',
    () async {
      final service = ChatChannelHydrationService(
        groupInfoLoader: (_, {cancelToken}) async => throw StateError('unused'),
        userInfoLoader: (_, {cancelToken}) async => UserInfo(
          uid: 'u_alice',
          remark: 'Remark Alice',
          name: 'Name Alice',
          avatar: 'https://example.com/alice.png',
          category: 'customerService',
          flame: 1,
          flameSecond: 30,
        ),
      );

      final result = await service.hydrateRemoteChannel(
        channelId: 'u_alice',
        channelType: WKChannelType.personal,
      );
      final hydrated = result.channel;

      expect(result.didHydrate, isTrue);
      expect(hydrated?.channelID, 'u_alice');
      expect(hydrated?.channelType, WKChannelType.personal);
      expect(hydrated?.channelName, 'Remark Alice');
      expect(hydrated?.avatar, 'https://example.com/alice.png');
      expect(hydrated?.category, 'customer_service');
      expect(hydrated?.remoteExtraMap['flame'], 1);
      expect(hydrated?.remoteExtraMap['flame_second'], 30);
    },
  );

  test('returns current channel when remote loading fails', () async {
    final current = WKChannel('u_fail', WKChannelType.personal)
      ..channelName = 'Cached Alice';
    final service = ChatChannelHydrationService(
      groupInfoLoader: (_, {cancelToken}) async => throw StateError('unused'),
      userInfoLoader: (_, {cancelToken}) async => throw DioException(
        requestOptions: RequestOptions(path: '/users/u_fail'),
      ),
    );

    final result = await service.hydrateRemoteChannel(
      channelId: 'u_fail',
      channelType: WKChannelType.personal,
      currentChannel: current,
    );
    final hydrated = result.channel;

    expect(result.didHydrate, isFalse);
    expect(hydrated, same(current));
    expect(hydrated?.channelName, 'Cached Alice');
  });
}
