import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/api_config.dart';
import '../../core/config/app_config.dart';
import '../../core/config/im_config.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/providers/runtime_capabilities_provider.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';

class HelpFeedbackPage extends ConsumerStatefulWidget {
  const HelpFeedbackPage({super.key});

  @override
  ConsumerState<HelpFeedbackPage> createState() => _HelpFeedbackPageState();
}

class _HelpFeedbackPageState extends ConsumerState<HelpFeedbackPage> {
  PackageInfo? _packageInfo;
  bool _isLoadingPackageInfo = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = packageInfo;
        _isLoadingPackageInfo = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingPackageInfo = false);
    }
  }

  String get _versionLabel {
    final packageInfo = _packageInfo;
    if (packageInfo == null) {
      return AppConfig.appVersion;
    }
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  String get _deviceFlagLabel {
    switch (IMConfig.currentDeviceFlag) {
      case IMConfig.deviceFlagWeb:
        return 'Web';
      case IMConfig.deviceFlagPC:
        return 'PC';
      case IMConfig.deviceFlagIPad:
        return 'iPad';
      default:
        return 'App';
    }
  }

  Future<void> _copyDiagnostics() async {
    final runtimeCapabilities = await ref.read(
      runtimeCapabilitiesProvider.future,
    );
    final diagnostics = [
      '应用: ${AppConfig.appName}',
      '版本: $_versionLabel',
      '平台: ${PlatformUtils.platformName}',
      '设备旗标: $_deviceFlagLabel (${IMConfig.currentDeviceFlag})',
      'API: ${ApiConfig.baseUrl}',
      'WS: ${ApiConfig.wsAddr}',
      '网页端登录地址: ${runtimeCapabilities.webLoginUrl.isEmpty ? '未返回' : runtimeCapabilities.webLoginUrl}',
      '网页端登录状态: ${runtimeCapabilities.webLoginStatusMessage}',
      '短编号修改: ${runtimeCapabilities.shortNoEditStatusMessage}',
      '手机号搜索: ${runtimeCapabilities.phoneSearchStatusMessage}',
      '环境: ${AppConfig.isDevelopment ? '开发环境' : '生产环境'}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: diagnostics));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('诊断信息已复制')));
  }

  Future<void> _copyFeedbackTemplate() async {
    final runtimeCapabilities = await ref.read(
      runtimeCapabilitiesProvider.future,
    );
    final template = [
      '问题描述：',
      '',
      '复现步骤：',
      '1.',
      '2.',
      '3.',
      '',
      '期望结果：',
      '',
      '实际结果：',
      '',
      '补充信息：',
      '- 版本: $_versionLabel',
      '- ƽ̨: ${PlatformUtils.platformName}',
      '- API: ${ApiConfig.baseUrl}',
      '- 网页端登录状态: ${runtimeCapabilities.webLoginStatusMessage}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: template));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('反馈模板已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final runtimeCapabilities = ref.watch(runtimeCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: const EdgeInsets.all(WKSpace.md),
        children: [
          _buildIntroCard(),
          const SizedBox(height: WKSpace.md),
          _buildActionsCard(runtimeCapabilities),
          const SizedBox(height: WKSpace.md),
          _buildFaqCard(runtimeCapabilities),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前支持', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: WKSpace.sm),
          Text(
            '这个页面不再是空入口。现在可以直接复制运行诊断信息、复制反馈模板，并查看当前联调环境下最常见的迁移阻塞说明。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: WKSpace.sm),
          Text(
            _isLoadingPackageInfo ? '正在读取版本信息...' : '当前版本：$_versionLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(AsyncValue<dynamic> runtimeCapabilities) {
    final webLoginStatus = runtimeCapabilities.maybeWhen(
      data: (value) => value.webLoginStatusMessage,
      orElse: () => '正在读取网页端登录状态',
    );

    return Container(
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('复制诊断信息'),
            subtitle: Text('包含版本、接口、长连接、设备旗标和当前网页端登录状态'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _copyDiagnostics,
          ),
          const Divider(indent: 64, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('复制反馈模板'),
            subtitle: const Text('生成一份可直接粘贴的问题反馈模板'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _copyFeedbackTemplate,
          ),
          const Divider(indent: 64, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('当前网页端登录状态'),
            subtitle: Text(webLoginStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(AsyncValue<dynamic> runtimeCapabilities) {
    final webLoginStatus = runtimeCapabilities.maybeWhen(
      data: (value) => value.webLoginStatusMessage,
      error: (_, _) => '暂时无法读取',
      orElse: () => '正在读取',
    );
    final phoneSearchStatus = runtimeCapabilities.maybeWhen(
      data: (value) => value.phoneSearchStatusMessage,
      error: (_, _) => '暂时无法读取',
      orElse: () => '正在读取',
    );
    final shortNoStatus = runtimeCapabilities.maybeWhen(
      data: (value) => value.shortNoEditStatusMessage,
      error: (_, _) => '暂时无法读取',
      orElse: () => '正在读取',
    );

    return Container(
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('常见联调问题', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: WKSpace.md),
          _FaqItem(
            title: '电脑端/网页端登录',
            body:
                '当前状态：$webLoginStatus\n如果网页能打开但还不能标绿，通常还差一次真实扫码确认和 `login_authcode` 收口回归。',
          ),
          const SizedBox(height: WKSpace.md),
          _FaqItem(
            title: '手机号搜索',
            body: '当前状态：$phoneSearchStatus\n页面提示会跟随后端运行时开关变化，不会再默认宣传一个未开放能力。',
          ),
          const SizedBox(height: WKSpace.md),
          _FaqItem(
            title: '短编号修改',
            body: '当前状态：$shortNoStatus\n我的资料页已经接入真实运行态能力，关闭时只会诚实提示，不会伪造提交成功。',
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String title;
  final String body;

  const _FaqItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: WKSpace.xs),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
