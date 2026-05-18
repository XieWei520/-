import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import 'launch_policy_models.dart';

typedef LaunchExternalUrl = Future<bool> Function(Uri uri);

Future<void> showForcedUpgradeDialog(
  BuildContext context, {
  required VersionPolicy policy,
  LaunchExternalUrl? launchExternalUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope<void>(
        canPop: false,
        child: AlertDialog(
          title: Text(policy.title.isEmpty ? '发现新版本' : policy.title),
          content: Text(
            policy.message.isEmpty ? '当前版本已不可用，请更新后继续使用。' : policy.message,
          ),
          actions: [
            TextButton(
              onPressed: () {
                final uri = Uri.tryParse(policy.updateUrl);
                if (uri == null || !uri.hasScheme) {
                  return;
                }
                final launcher =
                    launchExternalUrl ??
                    (Uri target) =>
                        launchUrl(target, mode: LaunchMode.externalApplication);
                launcher(uri);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showStartupNoticeDialog(
  BuildContext context, {
  required StartupNotice notice,
}) {
  final imageUrl = ApiConfig.resolveMediaUrl(notice.imageUrl);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(notice.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(notice.content),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}
