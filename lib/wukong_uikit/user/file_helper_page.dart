import 'package:flutter/material.dart';

import '_system_account_detail_page.dart';

class FileHelperPage extends StatelessWidget {
  final String? avatarUrl;
  final ValueChanged<String>? onOpenAvatarPreview;
  final VoidCallback? onSendMessage;

  const FileHelperPage({
    super.key,
    this.avatarUrl,
    this.onOpenAvatarPreview,
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SystemAccountDetailPage(
      uid: 'fileHelper',
      name: '文件传输助手',
      shortNo: '20000',
      functionDescription: '登录电脑版，向我发消息，可以在手机与电脑间传输文字、图片、音频、视频等文件。',
      avatarUrl: avatarUrl,
      onOpenAvatarPreview: onOpenAvatarPreview,
      onSendMessage: onSendMessage,
    );
  }
}
