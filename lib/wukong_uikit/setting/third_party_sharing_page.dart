import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class ThirdPartySharingPage extends StatefulWidget {
  const ThirdPartySharingPage({super.key});

  @override
  State<ThirdPartySharingPage> createState() => _ThirdPartySharingPageState();
}

class _ThirdPartySharingPageState extends State<ThirdPartySharingPage> {
  Future<void> _openUrl(String url, {String? errorMessage}) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage ?? '无法打开当前页面')));
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '第三方信息共享清单',
      body: ListView(
        padding: const EdgeInsets.only(top: 20),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            decoration: BoxDecoration(
              color: WKColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '原版这里进入的是内嵌 WebView 清单页。当前 Flutter 版本先保留同样的二级页面层级和白底排版，并支持外部打开线上清单页面。',
              style: TextStyle(
                fontSize: 15,
                color: WKColors.color999,
                height: 1.5,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 15, 15, 5),
            child: Text(
              '页面入口',
              style: TextStyle(fontSize: 14, color: WKColors.color999),
            ),
          ),
          WKSettingsGroup(
            children: [
              WKSettingsCell(
                title: '打开完整清单',
                onTap: () => _openUrl(
                  '${ApiConfig.baseUrl}/web/sdkinfo.html',
                  errorMessage: '无法打开第三方信息共享清单页面',
                ),
              ),
              const WKSectionGap(10),
              WKSettingsCell(
                title: '隐私政策',
                onTap: () =>
                    _openUrl('${ApiConfig.baseUrl}/web/privacy_policy.html'),
              ),
              WKSettingsCell(
                title: '用户协议',
                onTap: () =>
                    _openUrl('${ApiConfig.baseUrl}/web/user_agreement.html'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 15, 15, 5),
            child: Text(
              '当前工程接入项',
              style: TextStyle(fontSize: 14, color: WKColors.color999),
            ),
          ),
          WKSettingsGroup(
            children: const [
              _SharingInfoCell(title: '定位服务', value: '地理位置与地图展示'),
              _SharingInfoCell(title: '相机/相册', value: '头像、图片和扫码能力'),
              _SharingInfoCell(title: '音视频通话', value: '实时音视频连接'),
              _SharingInfoCell(title: '消息推送', value: '系统通知与离线提醒'),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SharingInfoCell extends StatelessWidget {
  final String title;
  final String value;

  const _SharingInfoCell({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, color: WKColors.colorDark),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, color: WKColors.color999),
            ),
          ),
        ],
      ),
    );
  }
}
