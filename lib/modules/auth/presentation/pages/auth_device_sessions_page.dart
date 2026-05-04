import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthDeviceSessionsPage extends ConsumerWidget {
  const AuthDeviceSessionsPage({
    super.key,
    this.listKey,
    this.quitAllActionKey,
  });

  final Key? listKey;
  final Key? quitAllActionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceSessionControllerProvider);
    final controller = ref.read(deviceSessionControllerProvider.notifier);
    final shouldTerminateLocalSession = ref.read(
      quitAllShouldTerminateLocalSessionProvider,
    );
    final terminateLocalSession = ref.read(localSessionTerminatorProvider);
    final errorMessage = (state.error ?? '').trim();

    return AuthPageScaffold(
      leading: IconButton(
        key: const ValueKey<String>('auth-device-sessions-back'),
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: '返回',
      ),
      title: '登录设备管理',
      subtitle: '查看当前账号最近登录过的设备和会话',
      statusBanner: errorMessage.isEmpty
          ? null
          : AuthStatusBanner(
              key: const ValueKey<String>('auth-status-banner'),
              message: errorMessage,
              tone: AuthStatusBannerTone.error,
              leadingIcon: Icons.error_outline_rounded,
            ),
      body: Column(
        key: listKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('当前没有读取到其他已登录设备。', textAlign: TextAlign.center),
            )
          else
            ...state.items.map(
              (item) => Container(
                key: ValueKey('auth-device-${item.deviceId}'),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  title: Text(item.deviceName),
                  subtitle: Text(
                    [
                      if (item.deviceModel.trim().isNotEmpty) item.deviceModel,
                      if (item.lastLogin.trim().isNotEmpty) item.lastLogin,
                    ].join('\n'),
                  ),
                  trailing: item.self
                      ? const Text('当前设备')
                      : TextButton(
                          onPressed: () => controller.remove(item.deviceId),
                          child: const Text('移除'),
                        ),
                ),
              ),
            ),
        ],
      ),
      primaryAction: AuthActionButton(
        key: quitAllActionKey ?? const ValueKey<String>('auth-device-quit-all'),
        label: '退出全部电脑端/网页端登录',
        isLoading: state.isQuittingAll,
        onPressed: state.isQuittingAll
            ? null
            : () async {
                await controller.quitAllPcWeb();
                final latestState = ref.read(deviceSessionControllerProvider);
                if (!context.mounted ||
                    (latestState.error ?? '').trim().isNotEmpty) {
                  return;
                }
                if (shouldTerminateLocalSession) {
                  await terminateLocalSession();
                  return;
                }
                Navigator.of(context).maybePop(true);
              },
      ),
    );
  }
}
