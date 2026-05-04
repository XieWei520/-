import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../modules/chat/chat_page.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_base/views/image_viewer.dart';

class SystemAccountDetailPage extends StatelessWidget {
  final String uid;
  final String name;
  final String shortNo;
  final String functionDescription;
  final String? avatarUrl;
  final ValueChanged<String>? onOpenAvatarPreview;
  final VoidCallback? onSendMessage;

  const SystemAccountDetailPage({
    super.key,
    required this.uid,
    required this.name,
    required this.shortNo,
    required this.functionDescription,
    this.avatarUrl,
    this.onOpenAvatarPreview,
    this.onSendMessage,
  });

  Future<void> _handleOpenAvatarPreview(BuildContext context) async {
    final payload = (avatarUrl?.trim().isNotEmpty ?? false)
        ? avatarUrl!.trim()
        : uid;
    if (onOpenAvatarPreview != null) {
      onOpenAvatarPreview!(payload);
      return;
    }
    if (payload == uid) {
      return;
    }
    await ImageViewerHelper.showImage(
      context,
      image: payload,
      heroTag: 'system-account-avatar-$uid',
      caption: name,
    );
  }

  void _handleSendMessage(BuildContext context) {
    if (onSendMessage != null) {
      onSendMessage!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: uid,
          channelType: WKChannelType.personal,
          channelName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '',
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            color: WKColors.surface,
            padding: const EdgeInsets.fromLTRB(15, 30, 15, 20),
            child: Row(
              children: [
                WKAvatar(
                  key: const ValueKey('system_account_avatar'),
                  url: avatarUrl,
                  name: name,
                  size: 70,
                  onTap: () => _handleOpenAvatarPreview(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: WKColors.colorDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            '悟空IM号：',
                            style: TextStyle(
                              fontSize: 16,
                              color: WKColors.color999,
                            ),
                          ),
                          Text(
                            shortNo,
                            style: const TextStyle(
                              fontSize: 16,
                              color: WKColors.color999,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            color: WKColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      '功能介绍',
                      style: TextStyle(
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    functionDescription,
                    style: const TextStyle(
                      fontSize: 16,
                      color: WKColors.color999,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: WKColors.surface,
            child: InkWell(
              onTap: () => _handleSendMessage(context),
              highlightColor: WKColors.screenBgSelected,
              splashColor: WKColors.screenBgSelected,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                alignment: Alignment.center,
                child: const Text(
                  '发消息',
                  style: TextStyle(
                    fontSize: 16,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
