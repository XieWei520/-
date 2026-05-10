import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../core/platform/local_image_picker.dart';
import '../../data/models/group_feishu_robot_config.dart';
import '../../service/api/file_api.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'group_robot_identity_section.dart';
import 'group_robot_webhook_mode.dart';
import 'group_robot_webhook_mode_section.dart';

typedef GroupRobotAvatarPicker = Future<String?> Function();
typedef GroupRobotAvatarUploader =
    Future<String> Function(String filePath, String uploadPath);
typedef GroupRobotAvatarUploadPathBuilder =
    String Function(String groupNo, String fileExtension);

const String _groupFeishuBotPageTitle = '飞书机器人';

class GroupFeishuBotPage extends StatefulWidget {
  final String groupNo;
  final String groupName;
  final GroupRobotAvatarPicker? pickDisplayAvatarImage;
  final GroupRobotAvatarUploader? uploadDisplayAvatarImage;
  final GroupRobotAvatarUploadPathBuilder? buildDisplayAvatarUploadPath;

  const GroupFeishuBotPage({
    super.key,
    required this.groupNo,
    required this.groupName,
    this.pickDisplayAvatarImage,
    this.uploadDisplayAvatarImage,
    this.buildDisplayAvatarUploadPath,
  });

  @override
  State<GroupFeishuBotPage> createState() => _GroupFeishuBotPageState();
}

class _GroupFeishuBotPageState extends State<GroupFeishuBotPage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _officialWebhookUrlController =
      TextEditingController();
  final TextEditingController _officialSecretController =
      TextEditingController();

  bool _enabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  GroupRobotWebhookMode _webhookMode = GroupRobotWebhookMode.imGenerated;
  GroupFeishuRobotConfig? _config;
  String _displayAvatar = '';
  Timer? _identitySaveDebounce;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _officialWebhookUrlController.dispose();
    _officialSecretController.dispose();
    _identitySaveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await GroupApi.instance.getFeishuRobotConfig(
        widget.groupNo,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _enabled = config?.enabled ?? true;
        _displayAvatar = config?.displayAvatar ?? '';
        _webhookMode = GroupRobotWebhookModeX.fromApiValue(config?.webhookMode);
        _isLoading = false;
      });
      _displayNameController.text = config?.displayName ?? '';
      _officialWebhookUrlController.text = config?.officialWebhookUrl ?? '';
      _officialSecretController.text = config?.officialSecret ?? '';
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载飞书机器人配置失败：$error');
    }
  }

  Future<void> _saveConfig({
    bool regenerateWebhook = false,
    bool regenerateSecret = false,
  }) async {
    _identitySaveDebounce?.cancel();
    _identitySaveDebounce = null;
    final officialWebhookUrl = _officialWebhookUrlController.text.trim();
    final officialSecret = _officialSecretController.text.trim();
    final validationError = validateFeishuOfficialWebhookUrl(
      mode: _webhookMode,
      webhookUrl: officialWebhookUrl,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    await _runBusyAction(() async {
      final saved = await GroupApi.instance.updateFeishuRobotConfig(
        widget.groupNo,
        enabled: _enabled,
        regenerateWebhook: regenerateWebhook,
        regenerateSecret: regenerateSecret,
        webhookMode: _webhookMode.apiValue,
        officialWebhookUrl: _webhookMode == GroupRobotWebhookMode.official
            ? officialWebhookUrl
            : null,
        officialSecret: _webhookMode == GroupRobotWebhookMode.official
            ? officialSecret
            : null,
        displayName: _displayNameController.text.trim(),
        displayAvatar: _displayAvatar.trim(),
      );
      if (!mounted) {
        return;
      }
      _applySavedConfig(saved);

      if (regenerateWebhook || regenerateSecret) {
        _showMessage('机器人凭证已更新');
      } else if (_webhookMode == GroupRobotWebhookMode.official) {
        _showMessage('官方 Webhook 配置已保存');
      } else if (saved.webhookUrl.isNotEmpty) {
        _showMessage('配置已保存');
      } else {
        _showMessage('飞书机器人已生成');
      }
    });
  }

  void _applySavedConfig(GroupFeishuRobotConfig saved) {
    if (!mounted) {
      return;
    }
    setState(() {
      _config = saved;
      _enabled = saved.enabled;
      _displayAvatar = saved.displayAvatar;
      _webhookMode = GroupRobotWebhookModeX.fromApiValue(saved.webhookMode);
    });
    _displayNameController.text = saved.displayName;
    _officialWebhookUrlController.text = saved.officialWebhookUrl;
    _officialSecretController.text = saved.officialSecret;
  }

  Future<void> _persistDisplayIdentity({String? successMessage}) async {
    final saved = await GroupApi.instance.updateFeishuRobotConfig(
      widget.groupNo,
      enabled: _enabled,
      displayName: _displayNameController.text.trim(),
      displayAvatar: _displayAvatar.trim(),
    );
    if (!mounted) {
      return;
    }
    _applySavedConfig(saved);
    if (successMessage != null) {
      _showMessage(successMessage);
    }
  }

  Future<void> _saveDisplayIdentity({String? successMessage}) async {
    await _runBusyAction(
      () => _persistDisplayIdentity(successMessage: successMessage),
    );
  }

  void _scheduleDisplayIdentitySave(String _) {
    _identitySaveDebounce?.cancel();
    _identitySaveDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      _identitySaveDebounce = null;
      unawaited(_saveDisplayIdentity());
    });
  }

  Future<void> _testConfig() async {
    if ((_config?.groupNo ?? '').isEmpty) {
      _showMessage('请先保存飞书机器人配置');
      return;
    }
    await _runBusyAction(() async {
      await GroupApi.instance.testFeishuRobotConfig(widget.groupNo);
      if (!mounted) {
        return;
      }
      _showMessage('测试消息已发送到当前群聊');
      await _loadConfig();
    });
  }

  Future<void> _deleteConfig() async {
    if (_config == null) {
      _showMessage('当前没有可删除的配置');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除飞书机器人'),
        content: const Text('删除后，当前 Webhook 与加签密钥会立即失效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _runBusyAction(() async {
      await GroupApi.instance.deleteFeishuRobotConfig(widget.groupNo);
      if (!mounted) {
        return;
      }
      setState(() {
        _config = null;
        _enabled = true;
        _displayAvatar = '';
        _webhookMode = GroupRobotWebhookMode.imGenerated;
      });
      _displayNameController.clear();
      _officialWebhookUrlController.clear();
      _officialSecretController.clear();
      _showMessage('飞书机器人已删除');
    });
  }

  Future<void> _uploadDisplayAvatar() async {
    final picker = widget.pickDisplayAvatarImage ?? _pickDisplayAvatarImage;
    final selectedPath = (await picker())?.trim() ?? '';
    if (selectedPath.isEmpty) {
      return;
    }

    await _runBusyAction(() async {
      final extension = path
          .extension(selectedPath)
          .replaceFirst('.', '')
          .trim();
      final safeExtension = extension.isEmpty ? 'png' : extension.toLowerCase();
      final buildUploadPath =
          widget.buildDisplayAvatarUploadPath ??
          _defaultDisplayAvatarUploadPath;
      final uploadPath = buildUploadPath(widget.groupNo, safeExtension);
      final uploader =
          widget.uploadDisplayAvatarImage ?? _uploadAvatarByFileApi;
      final uploadedUrl = (await uploader(selectedPath, uploadPath)).trim();
      if (uploadedUrl.isEmpty) {
        throw Exception('上传头像失败：返回地址为空');
      }
      if (!mounted) {
        return;
      }
      setState(() => _displayAvatar = uploadedUrl);
      await _persistDisplayIdentity(successMessage: '机器人展示头像已保存');
    });
  }

  Future<String?> _pickDisplayAvatarImage() async {
    return pickSingleLocalImagePath(imageQuality: 85, maxWidth: 1024);
  }

  Future<String> _uploadAvatarByFileApi(String filePath, String uploadPath) {
    return FileApi.instance.uploadCommonImage(
      filePath: filePath,
      uploadPath: uploadPath,
    );
  }

  String _defaultDisplayAvatarUploadPath(String groupNo, String fileExtension) {
    final normalizedGroupNo = groupNo.trim().isEmpty ? 'group' : groupNo.trim();
    return '/group/$normalizedGroupNo/robot/feishu_display_'
        '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
  }

  Future<void> _clearDisplayAvatar() async {
    if (_isSaving) {
      return;
    }
    if (_displayAvatar.trim().isEmpty) {
      _showMessage('当前没有可清空的头像');
      return;
    }
    setState(() => _displayAvatar = '');
    await _saveDisplayIdentity(successMessage: '机器人展示头像已清空');
  }

  Future<void> _copyText(String label, String value) async {
    if (value.trim().isEmpty) {
      _showMessage('$label为空');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showMessage('已复制$label');
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return WKSubPageScaffold(
      title: _groupFeishuBotPageTitle,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    WKSettingsGroup(
                      children: [
                        _buildSummarySection(),
                        const Divider(height: 1, indent: 15, endIndent: 15),
                        GroupRobotWebhookModeSection(
                          providerName: '飞书',
                          mode: _webhookMode,
                          onModeChanged: _isSaving
                              ? null
                              : (mode) => setState(() => _webhookMode = mode),
                          officialWebhookController:
                              _officialWebhookUrlController,
                          officialSecretController: _officialSecretController,
                          isBusy: _isSaving,
                        ),
                        if (_webhookMode ==
                            GroupRobotWebhookMode.imGenerated) ...[
                          const Divider(height: 1, indent: 15, endIndent: 15),
                          if (config == null) ...[
                            _buildCreateSection(),
                          ] else ...[
                            _buildCredentialSection(
                              title: '回调地址',
                              value: config.webhookUrl,
                              subtitle: '将此地址配置到支持飞书机器人回调协议的第三方系统中。',
                              copyLabel: '回调地址',
                            ),
                            const Divider(height: 1, indent: 15, endIndent: 15),
                            _buildCredentialSection(
                              title: '加签密钥',
                              value: config.secret,
                              subtitle: '第三方系统发消息时需按飞书规则计算签名。',
                              copyLabel: '加签密钥',
                            ),
                          ],
                        ],
                      ],
                    ),
                    const WKSectionGap(10),
                    WKSettingsGroup(
                      children: [
                        GroupRobotIdentitySection(
                          providerName: '飞书',
                          displayNameController: _displayNameController,
                          displayAvatar: _displayAvatar,
                          isBusy: _isSaving,
                          onDisplayNameChanged: _scheduleDisplayIdentitySave,
                          onUploadAvatar: _uploadDisplayAvatar,
                          onClearAvatar: () => unawaited(_clearDisplayAvatar()),
                        ),
                      ],
                    ),
                    if (config != null ||
                        _webhookMode == GroupRobotWebhookMode.official) ...[
                      const WKSectionGap(10),
                      WKSettingsGroup(
                        children: [
                          WKSettingsSwitchCell(
                            title: '启用机器人',
                            value: _enabled,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() => _enabled = value),
                          ),
                          WKSettingsCell(
                            key: const ValueKey('group-robot-save-config-cell'),
                            title: '保存当前配置',
                            onTap: _isSaving ? null : _saveConfig,
                          ),
                          if (_webhookMode ==
                                  GroupRobotWebhookMode.imGenerated &&
                              config != null) ...[
                            WKSettingsCell(
                              title: '重新生成加签密钥',
                              onTap: _isSaving
                                  ? null
                                  : () => _saveConfig(regenerateSecret: true),
                            ),
                            WKSettingsCell(
                              title: '重新生成 Webhook',
                              onTap: _isSaving
                                  ? null
                                  : () => _saveConfig(regenerateWebhook: true),
                            ),
                            WKSettingsCell(
                              title: '发送测试消息',
                              onTap: _isSaving ? null : _testConfig,
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (config != null) ...[
                      const WKSectionGap(10),
                      WKSettingsGroup(
                        children: [
                          WKSettingsCell(
                            title: '删除机器人',
                            centerTitle: true,
                            showArrow: false,
                            titleColor: WKColors.danger,
                            onTap: _isSaving ? null : _deleteConfig,
                          ),
                        ],
                      ),
                    ],
                    const WKSectionGap(10),
                    WKSettingsDescription(
                      text: _buildTipsText(
                        generated: config != null,
                        mode: _webhookMode,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
                if (_isSaving)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummarySection() {
    final config = _config;
    final resolvedGroupName = widget.groupName.trim().isEmpty
        ? widget.groupNo
        : widget.groupName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resolvedGroupName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '群号：${widget.groupNo}',
            style: const TextStyle(fontSize: 14, color: WKColors.color999),
          ),
          const SizedBox(height: 10),
          const Text(
            '用于将第三方系统按飞书机器人格式推送的消息接入当前 IM 群聊。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: config == null ? '未生成' : '已生成',
                color: config == null ? WKColors.color999 : WKColors.brand500,
              ),
              _StatusChip(
                label: config == null
                    ? '未启用'
                    : (config.enabled ? '已启用' : '已停用'),
                color: config == null
                    ? WKColors.color999
                    : (config.enabled
                          ? const Color(0xFF1C9C5E)
                          : WKColors.danger),
              ),
              _StatusChip(
                label: config?.secretSet == true ? '已配置加签' : '未配置加签',
                color: config?.secretSet == true
                    ? const Color(0xFF148A8A)
                    : WKColors.color999,
              ),
              _StatusChip(
                label: config?.appSecretSet == true ? '已配置飞书应用' : '未配置飞书应用',
                color: config?.appSecretSet == true
                    ? const Color(0xFF4B62D4)
                    : WKColors.color999,
              ),
            ],
          ),
          if ((config?.lastPushAt ?? 0) > 0) ...[
            const SizedBox(height: 14),
            Text(
              '最近收消息：${_formatTimestamp(config!.lastPushAt)}',
              style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
            ),
          ],
          if ((config?.lastError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '最近错误：${config!.lastError}',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: WKColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '生成接入配置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '生成后，系统会为当前群创建一组可接入第三方系统的 Webhook 与加签密钥。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveConfig,
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('立即生成'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialSection({
    required String title,
    required String value,
    required String subtitle,
    required String copyLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isSaving ? null : () => _copyText(copyLabel, value),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('复制'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WKColors.homeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EBF1)),
            ),
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
                color: WKColors.colorDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildTipsText({
    required bool generated,
    required GroupRobotWebhookMode mode,
  }) {
    if (mode == GroupRobotWebhookMode.official) {
      return '1. 官方模式下，系统将以你填写的飞书官方 Webhook 为主。\n'
          '2. 请确保 URL 包含 open.feishu.cn，并按需填写签名密钥。\n'
          '3. 当前版本中，官方 Webhook 消息不会回流同步到 IM 群聊。';
    }

    final buffer = StringBuffer()
      ..writeln('1. 这里生成的是当前群的接入 Webhook，不是飞书后台现成地址。')
      ..writeln('2. 将页面中的 Webhook 与加签密钥复制到第三方平台，按飞书机器人协议推送即可。')
      ..writeln('3. 同时兼容飞书 V1 的 {title,text} 与 V2 的 {msg_type,content} 消息体。');

    if (generated) {
      buffer.writeln('4. 重新生成 Webhook 或加签密钥后，旧配置会立即失效，需要同步更新第三方平台。');
    }
    return buffer.toString().trimRight();
  }

  String _formatTimestamp(int value) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
