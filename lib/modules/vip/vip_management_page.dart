import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../monitor/feishu_monitor_center_page.dart';

class VipManagementPage extends StatelessWidget {
  const VipManagementPage({super.key});

  void _openFeishuCenter(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FeishuMonitorCenterPage()));
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title 即将上线')));
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '管理系统',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _ManagementHeader(),
          const SizedBox(height: WKSpace.md),
          _ManagementCenterCard(
            key: const ValueKey('management-center-feishu'),
            title: '飞书信息监控中心',
            description: '同步飞书 Web 群消息到悟空 IM 群',
            status: '可用',
            icon: Icons.forum_rounded,
            enabled: true,
            onTap: () => _openFeishuCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-dingtalk'),
            title: '钉钉信息监控中心',
            description: '同步钉钉群、机器人消息到悟空 IM 群',
            status: '即将上线',
            icon: Icons.notifications_active_rounded,
            enabled: false,
            onTap: () => _showComingSoon(context, '钉钉信息监控中心'),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-xiaoe'),
            title: '小鹅通信息监控中心',
            description: '监控课程、订单、通知并转发到悟空 IM 群',
            status: '即将上线',
            icon: Icons.school_rounded,
            enabled: false,
            onTap: () => _showComingSoon(context, '小鹅通信息监控中心'),
          ),
        ],
      ),
    );
  }
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '信息监控服务',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          SizedBox(height: WKSpace.xs),
          Text(
            '按平台管理消息监控与自动转发，当前优先支持飞书 Web 群转发到悟空 IM 群。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCenterCard extends StatelessWidget {
  const _ManagementCenterCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final String status;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = enabled ? WKColors.success : WKColors.color999;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(WKSpace.lg),
          decoration: BoxDecoration(
            color: WKColors.surface,
            borderRadius: BorderRadius.circular(WKRadius.lg),
            boxShadow: WKShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? WKColors.brand50 : WKColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(WKRadius.lg),
                ),
                child: Icon(
                  icon,
                  color: enabled ? WKColors.brand500 : WKColors.color999,
                ),
              ),
              const SizedBox(width: WKSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: WKSpace.xxs),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WKSpace.sm,
                      vertical: WKSpace.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(WKRadius.pill),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: WKSpace.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: WKColors.color999,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
