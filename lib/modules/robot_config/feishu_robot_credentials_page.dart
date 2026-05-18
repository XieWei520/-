import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'feishu_robot_credentials.dart';

class FeishuRobotCredentialsPage extends StatefulWidget {
  FeishuRobotCredentialsPage({super.key, FeishuRobotCredentialsStore? store})
    : store = store ?? SharedPreferencesFeishuRobotCredentialsStore();

  final FeishuRobotCredentialsStore store;

  @override
  State<FeishuRobotCredentialsPage> createState() =>
      _FeishuRobotCredentialsPageState();
}

class _FeishuRobotCredentialsPageState
    extends State<FeishuRobotCredentialsPage> {
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _appSecretController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _secretVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _appSecretController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final credentials = await widget.store.load();
    if (!mounted) {
      return;
    }
    _appIdController.text = credentials.appId;
    _appSecretController.text = credentials.appSecret;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final credentials = FeishuRobotCredentials(
      appId: _appIdController.text,
      appSecret: _appSecretController.text,
    ).normalize();
    if (credentials.appId.isEmpty) {
      _showMessage('请填写飞书 App ID');
      return;
    }
    if (credentials.appSecret.isEmpty) {
      _showMessage('请填写飞书 App Secret');
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await widget.store.save(credentials);
      if (!mounted) {
        return;
      }
      _appIdController.text = credentials.appId;
      _appSecretController.text = credentials.appSecret;
      _showMessage('飞书机器人配置已保存到本机');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '飞书机器人配置',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _RobotConfigHeader(isConfigured: _hasConfiguredCredentials),
                const SizedBox(height: WKSpace.md),
                _ConfigCard(
                  child: Column(
                    children: [
                      _ConfigTextField(
                        key: const ValueKey('feishu-robot-app-id-field'),
                        controller: _appIdController,
                        label: 'App ID',
                        hintText: '例如 cli_xxxxxxxxxxxxxxxx',
                        enabled: !_saving,
                      ),
                      const SizedBox(height: WKSpace.md),
                      TextField(
                        key: const ValueKey('feishu-robot-app-secret-field'),
                        controller: _appSecretController,
                        enabled: !_saving,
                        obscureText: !_secretVisible,
                        decoration: InputDecoration(
                          labelText: 'App Secret',
                          hintText: '填写飞书开放平台 App Secret',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _secretVisible ? '隐藏密钥' : '显示密钥',
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() {
                                      _secretVisible = !_secretVisible;
                                    });
                                  },
                            icon: Icon(
                              _secretVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WKSpace.md),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    key: const ValueKey('feishu-robot-save-button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('保存到本机'),
                  ),
                ),
                const SizedBox(height: WKSpace.sm),
                const WKSettingsDescription(
                  text:
                      '该配置只保存在当前客户端，用于统一管理飞书开放平台 App ID 与 App Secret；每个群内仍只配置群级机器人开关、Webhook 与展示身份。',
                ),
              ],
            ),
    );
  }

  bool get _hasConfiguredCredentials {
    return _appIdController.text.trim().isNotEmpty &&
        _appSecretController.text.trim().isNotEmpty;
  }
}

class _RobotConfigHeader extends StatelessWidget {
  const _RobotConfigHeader({required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    final statusColor = isConfigured ? WKColors.success : WKColors.warning;
    return Container(
      width: double.infinity,
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
              color: WKColors.brand50,
              borderRadius: BorderRadius.circular(WKRadius.md),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: WKColors.brand500,
            ),
          ),
          const SizedBox(width: WKSpace.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '飞书开放平台凭据',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: WKColors.colorDark,
                  ),
                ),
                SizedBox(height: WKSpace.xxs),
                Text(
                  '统一保存 App ID 与 App Secret',
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    color: WKColors.color999,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WKSpace.sm),
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
              isConfigured ? '已配置' : '未配置',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  const _ConfigTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
