import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../core/platform/local_image_picker.dart';
import '../../data/models/group_dingtalk_robot_config.dart';
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

const String _groupDingTalkBotPageTitle = '钉钉机器人';

class GroupDingTalkBotPage extends StatefulWidget {
  final String groupNo;
  final String groupName;
  final GroupRobotAvatarPicker? pickDisplayAvatarImage;
  final GroupRobotAvatarUploader? uploadDisplayAvatarImage;
  final GroupRobotAvatarUploadPathBuilder? buildDisplayAvatarUploadPath;

  const GroupDingTalkBotPage({
    super.key,
    required this.groupNo,
    required this.groupName,
    this.pickDisplayAvatarImage,
    this.uploadDisplayAvatarImage,
    this.buildDisplayAvatarUploadPath,
  });

  @override
  State<GroupDingTalkBotPage> createState() => _GroupDingTalkBotPageState();
}

class _GroupDingTalkBotPageState extends State<GroupDingTalkBotPage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _officialWebhookUrlController =
      TextEditingController();
  final TextEditingController _officialSecretController =
      TextEditingController();

  bool _enabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  GroupRobotWebhookMode _webhookMode = GroupRobotWebhookMode.imGenerated;
  GroupDingTalkRobotConfig? _config;
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
      final config = await GroupApi.instance.getDingTalkRobotConfig(
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
      _showMessage('加载钉钉机器人配置失败：$error');
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
    final validationError = validateDingTalkOfficialWebhookUrl(
      mode: _webhookMode,
      webhookUrl: officialWebhookUrl,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    await _runBusyAction(() async {
      final saved = await GroupApi.instance.updateDingTalkRobotConfig(
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
        _showMessage('钉钉机器人已生成');
      }
    });
  }

  void _applySavedConfig(GroupDingTalkRobotConfig saved) {
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
    final saved = await GroupApi.instance.updateDingTalkRobotConfig(
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
      _showMessage('请先保存钉钉机器人配置');
      return;
    }
    await _runBusyAction(() async {
      await GroupApi.instance.testDingTalkRobotConfig(widget.groupNo);
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
        title: const Text('删除钉钉机器人'),
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
      await GroupApi.instance.deleteDingTalkRobotConfig(widget.groupNo);
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
      _showMessage('钉钉机器人已删除');
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
    return '/group/$normalizedGroupNo/robot/dingtalk_display_'
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
      title: _groupDingTalkBotPageTitle,
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
                          providerName: '钉钉',
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
                          if (config == null)
                            _buildCreateSection()
                          else ...[
                            _buildCredentialSection(
                              title: '回调地址',
                              value: config.webhookUrl,
                              subtitle: '将此地址配置到兼容钉钉机器人消息格式的第三方系统中。',
                              copyLabel: '回调地址',
                            ),
                            const Divider(height: 1, indent: 15, endIndent: 15),
                            _buildCredentialSection(
                              title: '加签密钥',
                              value: config.secret,
                              subtitle: '第三方系统发消息时，需按钉钉规则生成签名。',
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
                          providerName: '钉钉',
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
    final statusText = config == null
        ? '尚未生成钉钉机器人配置'
        : (config.enabled ? '已启用钉钉机器人' : '钉钉机器人已停用');

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
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(fontSize: 13, color: WKColors.color999),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSection() {
    return WKSettingsCell(
      title: '生成钉钉机器人',
      onTap: _isSaving ? null : _saveConfig,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isSaving ? null : () => _copyText(copyLabel, value),
              child: Text('复制$copyLabel'),
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
      return '1. 官方模式下，系统将以你填写的钉钉官方 Webhook 为主。\n'
          '2. 请确保 URL 包含 oapi.dingtalk.com 或 api.dingtalk.com。\n'
          '3. 当前版本中，官方 Webhook 消息不会回流同步到 IM 群聊。';
    }

    final buffer = StringBuffer()
      ..writeln('1. 生成 Webhook 与加签密钥后，第三方系统即可按钉钉机器人消息格式推送到当前群聊。')
      ..writeln('2. 当前版本支持 text、markdown、link、actionCard、feedCard 五种消息类型。');
    if (generated) {
      buffer.writeln('3. 重新生成 Webhook 或加签密钥后，旧配置会立即失效，需要同步更新第三方平台。');
    }
    return buffer.toString().trimRight();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
