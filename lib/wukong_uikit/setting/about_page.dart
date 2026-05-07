import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/avatar_utils.dart';
import '../../service/api/common_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

const String _androidSystemTeamId = 'u_10000';
const String _androidSystemTeamName = '绯荤粺閫氱煡';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;
  AppVersionInfo? _newVersion;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final latestVersion = await CommonApi.instance.getAppNewVersion(
        packageInfo.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = packageInfo;
        _newVersion = latestVersion?.hasDownloadUrl == true
            ? latestVersion
            : null;
      });
    } catch (_) {}
  }

  String get _appName {
    final packageName = _packageInfo?.appName.trim() ?? '';
    if (packageName.isEmpty || packageName == 'wukong_im_app') {
      return AppConfig.appName;
    }
    return packageName;
  }

  String get _versionText =>
      'version ${_packageInfo?.version ?? AppConfig.appVersion}';

  String? get _systemTeamAvatarUrl => buildUserAvatarUrl(_androidSystemTeamId);

  Future<void> _openUrl(String url, String errorText) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorText)));
  }

  Future<void> _checkNewVersion() async {
    final version = _newVersion;
    if (version == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前已经是最新版本')));
      return;
    }
    await _openUrl(version.downloadUrl, '无法打开新版本下载地址');
  }

  Widget _buildCheckTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _newVersion == null ? 0 : 1,
          child: WKReferenceAssets.image(
            WKReferenceAssets.newVersion,
            width: 30,
            height: 20,
          ),
        ),
        const SizedBox(width: 6),
        WKReferenceAssets.image(
          WKReferenceAssets.arrowRight,
          width: 14,
          height: 14,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '关于$_appName',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 50),
                Center(
                  child: WKAvatar(
                    key: const ValueKey('about-system-team-avatar'),
                    url: _systemTeamAvatarUrl,
                    name: _androidSystemTeamName,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    _appName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _versionText,
                    style: const TextStyle(
                      fontSize: 18,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                WKSettingsGroup(
                  children: [
                    WKSettingsCell(
                      title: '用户协议',
                      onTap: () => _openUrl(
                        '${ApiConfig.baseUrl}/web/user_agreement.html',
                        '无法打开用户协议页面',
                      ),
                    ),
                    WKSettingsCell(
                      title: '隐私政策',
                      onTap: () => _openUrl(
                        '${ApiConfig.baseUrl}/web/privacy_policy.html',
                        '无法打开隐私政策页面',
                      ),
                    ),
                    const WKSectionGap(15),
                    WKSettingsCell(
                      title: '检查新版本',
                      showArrow: false,
                      trailing: _buildCheckTrailing(),
                      onTap: _checkNewVersion,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                _openUrl('https://beian.miit.gov.cn/#/home', '无法打开备案查询页面'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                key: const ValueKey<String>('about-legal-link'),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 20,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: WKColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ICP备案号 沪ICP备2026016828号 >',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: WKColors.color999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Padding(
            padding: EdgeInsets.only(bottom: 50),
            child: Text(
              'Copyright © 2024\n上海信必达网络科技有限公司 版权所有',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: WKColors.color999,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
