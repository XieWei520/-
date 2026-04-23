import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/providers/auth_provider.dart';
import '../chat/chat_page.dart';

const String vipCustomerServiceUid = 'system_kefu';
const String vipRequiredMessage =
    '\u8BE5\u529F\u80FD\u4EC5\u9650\u5546\u5BB6\u53EF\u7528\uFF0C\u8BF7\u8054\u7CFB\u7BA1\u7406\u5458';

bool isVipUser(UserInfo? user) => user?.vipLevel == 1;

Future<void> openVipCustomerServiceChat(BuildContext context) async {
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const ChatPage(
        channelId: vipCustomerServiceUid,
        channelType: WKChannelType.personal,
        channelName: '管理员',
      ),
    ),
  );
}

Future<bool> guardVipFeature(BuildContext context) async {
  if (!context.mounted) {
    return false;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(authProvider).userInfo;
  if (isVipUser(user)) {
    return true;
  }
  final shouldContactAdmin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text(vipRequiredMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('联系管理员'),
        ),
      ],
    ),
  );
  if (shouldContactAdmin == true && context.mounted) {
    await openVipCustomerServiceChat(context);
  }
  return false;
}
