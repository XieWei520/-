import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/providers/auth_provider.dart';
import '../../service/api/user_api.dart';
import '../chat/chat_page.dart';
import '../customer_service/customer_service_identity.dart';

const String vipCustomerServiceUid = 'system_kefu';
const String vipRequiredMessage =
    '\u8BE5\u529F\u80FD\u4EC5\u9650\u5546\u5BB6\u53EF\u7528\uFF0C\u8BF7\u8054\u7CFB\u7BA1\u7406\u5458';

bool isVipUser(UserInfo? user) => user?.vipLevel == 1;

typedef VipCustomerServicesLoader =
    Future<List<CustomerServiceAccount>> Function();

CustomerServiceAccount? selectVipCustomerService(
  Iterable<CustomerServiceAccount> services,
) {
  for (final service in services) {
    if (service.uid.trim().isNotEmpty) {
      return service;
    }
  }
  return null;
}

Future<CustomerServiceAccount?> resolveVipCustomerService({
  VipCustomerServicesLoader? loader,
}) async {
  final services = await (loader ?? UserApi.instance.getCustomerServices)();
  return selectVipCustomerService(services);
}

Future<void> openVipCustomerServiceChat(
  BuildContext context, {
  VipCustomerServicesLoader? customerServicesLoader,
}) async {
  CustomerServiceAccount? service;
  try {
    service = await resolveVipCustomerService(loader: customerServicesLoader);
  } catch (_) {
    service = null;
  }
  if (!context.mounted) {
    return;
  }
  final serviceUid = service?.uid.trim() ?? '';
  final serviceName = service?.name.trim() ?? '';
  final channelId = serviceUid.isNotEmpty ? serviceUid : vipCustomerServiceUid;
  final channelName = serviceName.isNotEmpty ? serviceName : '默认客服';
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        channelId: channelId,
        channelType: WKChannelType.personal,
        channelName: channelName,
        channelCategory: customerServiceCategory,
      ),
    ),
  );
}

Future<bool> guardVipFeature(
  BuildContext context, {
  VipCustomerServicesLoader? customerServicesLoader,
}) async {
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
    await openVipCustomerServiceChat(
      context,
      customerServicesLoader: customerServicesLoader,
    );
  }
  return false;
}
