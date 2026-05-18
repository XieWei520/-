import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/chat/chat_channel_identity.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('android fixed chats resolve stable titles', () {
    expect(
      androidFixedChatTitle(androidFileHelperId, WKChannelType.personal),
      '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b',
    );
    expect(
      androidFixedChatTitle(androidSystemTeamId, WKChannelType.personal),
      '\u7cfb\u7edf\u901a\u77e5',
    );
    expect(
      androidFixedChatTitle(androidFileHelperId, WKChannelType.group),
      isNull,
    );
    expect(
      isAndroidFixedChat(androidFileHelperId, WKChannelType.personal),
      isTrue,
    );
  });

  test('channel feature gates preserve fixed chat restrictions', () {
    expect(
      shouldHydrateRemoteFlameSettings(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
      ),
      isTrue,
    );
    expect(
      shouldHydrateRemoteFlameSettings(
        channelId: 'u_alice',
        channelType: WKChannelType.personal,
      ),
      isTrue,
    );
    expect(
      shouldHydrateRemoteFlameSettings(
        channelId: androidFileHelperId,
        channelType: WKChannelType.personal,
      ),
      isFalse,
    );
    expect(
      canShowPersonalCallActions(
        channelId: 'u_alice',
        channelType: WKChannelType.personal,
      ),
      isTrue,
    );
    expect(
      canShowPersonalCallActions(
        channelId: androidSystemTeamId,
        channelType: WKChannelType.personal,
      ),
      isFalse,
    );
    expect(canShowGroupCallAction(WKChannelType.group), isTrue);
    expect(canShowGroupCallAction(WKChannelType.personal), isFalse);
  });

  test(
    'buildParticipantFallbackChannel uses fixed title before input name',
    () {
      final fixed = buildParticipantFallbackChannel(
        channelId: androidFileHelperId,
        channelType: WKChannelType.personal,
        channelName: 'Server name',
      );

      expect(fixed?.channelID, androidFileHelperId);
      expect(fixed?.channelType, WKChannelType.personal);
      expect(fixed?.channelName, '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b');

      final personal = buildParticipantFallbackChannel(
        channelId: 'u_alice',
        channelType: WKChannelType.personal,
        channelName: 'Alice',
      );
      expect(personal?.channelName, 'Alice');

      final group = buildParticipantFallbackChannel(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        channelName: 'Group',
      );
      expect(group, isNull);
    },
  );

  test('buildParticipantFallbackChannel returns loaded channel unchanged', () {
    final loaded = WKChannel('g_demo', WKChannelType.group)
      ..channelName = 'Loaded Group';

    final fallback = buildParticipantFallbackChannel(
      channelId: 'g_demo',
      channelType: WKChannelType.group,
      channelName: 'Ignored',
      loadedChannel: loaded,
    );

    expect(fallback, same(loaded));
  });

  test('applyChannelUserIdentity maps display name avatar and category', () {
    final channel = WKChannel('u_alice', WKChannelType.personal)
      ..channelName = 'u_alice';
    final user = UserInfo(
      uid: 'u_alice',
      remark: 'Remark Alice',
      name: 'Name Alice',
      username: 'username_alice',
      avatar: 'https://example.com/a.png',
      category: 'customerService',
    );

    applyChannelUserIdentity(channel, user);

    expect(channel.channelName, 'Remark Alice');
    expect(channel.avatar, 'https://example.com/a.png');
    expect(channel.category, 'customer_service');
  });
}
