import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_item_loader.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    await StorageUtils.setUid('u_self');
    await DraftManager().clearAllDrafts();
  });

  test(
    'resolveConversationListItemData masks the last-message preview for chat-password conversations',
    () async {
      final conversation = _buildConversation(channelId: 'u_secure');
      conversation.setWkChannel(
        _buildProtectedChannel(channelId: 'u_secure', chatPwdOn: 1),
      );
      conversation.setWkMsg(
        WKMsg()
          ..channelID = 'u_secure'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('super secret preview'),
      );
      conversation.setReminderList(<WKReminder>[]);

      final data = await resolveConversationListItemData(
        ConversationListItemRequest(
          conversation: conversation,
          refreshToken: 0,
        ),
        currentUid: 'u_self',
      );

      expect(data.lastMsgContent, isNot('super secret preview'));
    },
  );

  test(
    'resolveConversationListItemData masks draft text for chat-password conversations',
    () async {
      await DraftManager().saveDraft(
        channelId: 'u_secure',
        channelType: WKChannelType.personal,
        content: 'hidden draft text',
      );

      final conversation = _buildConversation(channelId: 'u_secure');
      conversation.setWkChannel(
        _buildProtectedChannel(channelId: 'u_secure', chatPwdOn: 1),
      );
      conversation.setWkMsg(
        WKMsg()
          ..channelID = 'u_secure'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('visible fallback'),
      );
      conversation.setReminderList(<WKReminder>[]);

      final data = await resolveConversationListItemData(
        ConversationListItemRequest(
          conversation: conversation,
          refreshToken: 0,
        ),
        currentUid: 'u_self',
      );

      expect(data.isDraft, isTrue);
      expect(data.lastMsgContent, isNot('hidden draft text'));
    },
  );

  test(
    'resolveConversationListItemData keeps preferred customer service identity for personal conversations',
    () async {
      final conversation = _buildConversation(channelId: 'cs_001');
      conversation.setWkChannel(WKChannel('cs_001', WKChannelType.personal));
      conversation.setReminderList(<WKReminder>[]);

      final data = await resolveConversationListItemData(
        ConversationListItemRequest(
          conversation: conversation,
          preferredTitle: '售后客服',
          preferredCategory: 'customer_service',
          refreshToken: 0,
        ),
        currentUid: 'u_self',
      );

      expect(data.title, '售后客服');
      expect(data.category, 'customer_service');
    },
  );

  test(
    'resolveConversationListItemData fetches missing personal user info for customer-service inbox',
    () async {
      final conversation = _buildConversation(channelId: 'u_visitor');
      conversation.setWkChannel(WKChannel('u_visitor', WKChannelType.personal));
      conversation.setReminderList(<WKReminder>[]);

      final data = await resolveConversationListItemData(
        ConversationListItemRequest(
          conversation: conversation,
          refreshToken: 0,
        ),
        currentUid: 'cs_self',
        personalUserInfoLoader: (uid) async {
          expect(uid, 'u_visitor');
          return UserInfo(
            uid: uid,
            name: 'Visitor Alice',
            avatar: 'avatars/alice.png',
            vipLevel: 1,
            category: 'visitor',
          );
        },
      );

      expect(data.title, 'Visitor Alice');
      expect(data.avatarUrl, contains('avatars/alice.png'));
      expect(data.vipLevel, 1);
      expect(data.category, 'visitor');
    },
  );
}

WKUIConversationMsg _buildConversation({required String channelId}) {
  return WKUIConversationMsg()
    ..channelID = channelId
    ..channelType = WKChannelType.personal
    ..clientMsgNo = 'client_$channelId'
    ..lastMsgTimestamp = 1713000000;
}

WKChannel _buildProtectedChannel({
  required String channelId,
  required int chatPwdOn,
}) {
  return WKChannel(channelId, WKChannelType.personal)
    ..channelName = 'Secure Chat'
    ..remoteExtraMap = <String, dynamic>{'chat_pwd_on': chatPwdOn}
    ..localExtra = <String, dynamic>{'chat_pwd_on': chatPwdOn};
}
