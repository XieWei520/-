import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../dingtalk_monitor/dingtalk_monitor_center_page.dart';
import '../feishu_monitor/feishu_monitor_center_page.dart';
import '../juliang_monitor/juliang_monitor_center_page.dart';
import '../mengxia_monitor/mengxia_monitor_center_page.dart';
import '../robot_config/feishu_robot_credentials_page.dart';
import '../xiaoe_monitor/xiaoe_monitor_center_page.dart';

class VipManagementPage extends StatelessWidget {
  const VipManagementPage({
    super.key,
    this.feishuCenterBuilder,
    this.dingTalkCenterBuilder,
    this.mengxiaCenterBuilder,
    this.juliangCenterBuilder,
    this.xiaoeCenterBuilder,
    this.robotConfigBuilder,
  });

  final WidgetBuilder? feishuCenterBuilder;
  final WidgetBuilder? dingTalkCenterBuilder;
  final WidgetBuilder? mengxiaCenterBuilder;
  final WidgetBuilder? juliangCenterBuilder;
  final WidgetBuilder? xiaoeCenterBuilder;
  final WidgetBuilder? robotConfigBuilder;

  void _openFeishuCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: feishuCenterBuilder ?? (_) => FeishuMonitorCenterPage(),
      ),
    );
  }

  void _openDingTalkCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: dingTalkCenterBuilder ?? (_) => DingTalkMonitorCenterPage(),
      ),
    );
  }

  void _openMengxiaCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: mengxiaCenterBuilder ?? (_) => MengxiaMonitorCenterPage(),
      ),
    );
  }

  void _openJuliangCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: juliangCenterBuilder ?? (_) => JuliangMonitorCenterPage(),
      ),
    );
  }

  void _openXiaoeCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: xiaoeCenterBuilder ?? (_) => XiaoeMonitorCenterPage(),
      ),
    );
  }

  void _openRobotConfig(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: robotConfigBuilder ?? (_) => FeishuRobotCredentialsPage(),
      ),
    );
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
            key: const ValueKey('management-center-robot-config'),
            title: '机器人配置',
            description: '统一配置飞书开放平台 App ID 与 App Secret，本机保存后供群机器人接入使用。',
            status: '本机配置',
            icon: Icons.smart_toy_outlined,
            enabled: true,
            onTap: () => _openRobotConfig(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-feishu'),
            title: '飞书信息监控中心',
            description: '查看独立飞书监控壳程序状态，并从悟空 IM 内发起基础控制。',
            status: '正常',
            icon: Icons.forum_rounded,
            enabled: true,
            onTap: () => _openFeishuCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-dingtalk'),
            title: '钉钉信息监控中心',
            description: '连接本机 Windows 原生 DingTalk Host，配置来源到悟空 IM 群的自动转发规则。',
            status: '正常',
            icon: Icons.notifications_active_rounded,
            enabled: true,
            onTap: () => _openDingTalkCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-mengxia'),
            title: '萌侠信息转发中心',
            description: '人工登录萌侠无痕窗口后，实时监控已选择来源会话并转发到悟空 IM 目标群。',
            status: '正常',
            icon: Icons.hub_rounded,
            enabled: true,
            onTap: () => _openMengxiaCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-juliang'),
            title: '聚合信息转发中心',
            description: '每次启动无痕登录聚合面板，实时监控已配置来源会话并转发文本到悟空 IM 目标群。',
            status: '正常',
            icon: Icons.alt_route_rounded,
            enabled: true,
            onTap: () => _openJuliangCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-xiaoe'),
            title: '小鹅通信息转发中心',
            description:
                '从小鹅通 muti_index 打开后手动停留在圈子、课程互动或直播评论页，实时转发文本、图片和 20 MB 内文件。',
            status: '正常',
            icon: Icons.school_rounded,
            enabled: true,
            onTap: () => _openXiaoeCenter(context),
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
            '按平台管理消息监控与自动转发。飞书、钉钉和萌侠均通过独立本地监控程序接入，悟空 IM 只负责规则配置和最终群转发。',
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
