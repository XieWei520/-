import 'package:flutter/material.dart';

import '_system_account_detail_page.dart';

class SystemTeamPage extends StatelessWidget {
  final String? avatarUrl;
  final ValueChanged<String>? onOpenAvatarPreview;
  final VoidCallback? onSendMessage;

  const SystemTeamPage({
    super.key,
    this.avatarUrl,
    this.onOpenAvatarPreview,
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SystemAccountDetailPage(
      uid: 'u_10000',
      name: '系统通知',
      shortNo: '10000',
      functionDescription: '悟空IM团队官方账号',
      avatarUrl: avatarUrl,
      onOpenAvatarPreview: onOpenAvatarPreview,
      onSendMessage: onSendMessage,
    );
  }
}
