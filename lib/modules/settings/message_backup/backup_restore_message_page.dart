import 'package:flutter/material.dart';

import '../settings_surface_widgets.dart';
import 'backup_restore_message_service.dart';

enum BackupRestoreMessageMode { backup, restore }

class BackupRestoreMessagePage extends StatefulWidget {
  const BackupRestoreMessagePage({super.key, required this.mode, this.service});

  final BackupRestoreMessageMode mode;
  final BackupRestoreMessageService? service;

  @override
  State<BackupRestoreMessagePage> createState() =>
      _BackupRestoreMessagePageState();
}

class _BackupRestoreMessagePageState extends State<BackupRestoreMessagePage> {
  bool _isRunning = false;
  BackupRestoreMessageResult? _result;
  String? _errorMessage;

  BackupRestoreMessageService get _service =>
      widget.service ?? BackupRestoreMessageService();

  String get _pageTitle {
    switch (widget.mode) {
      case BackupRestoreMessageMode.backup:
        return '消息备份';
      case BackupRestoreMessageMode.restore:
        return '消息恢复';
    }
  }

  String get _heroTitle {
    switch (widget.mode) {
      case BackupRestoreMessageMode.backup:
        return '备份本地消息';
      case BackupRestoreMessageMode.restore:
        return '恢复备份文件';
    }
  }

  String get _heroSubtitle {
    switch (widget.mode) {
      case BackupRestoreMessageMode.backup:
        return '导出当前账号本地消息 JSON，并上传到与 Android 一致的备份接口。';
      case BackupRestoreMessageMode.restore:
        return '下载服务端备份文件，并将消息与会话导入本地 SQLite。';
    }
  }

  String get _buttonLabel {
    switch (widget.mode) {
      case BackupRestoreMessageMode.backup:
        return '开始备份';
      case BackupRestoreMessageMode.restore:
        return '开始恢复';
    }
  }

  IconData get _heroIcon {
    switch (widget.mode) {
      case BackupRestoreMessageMode.backup:
        return Icons.backup_outlined;
      case BackupRestoreMessageMode.restore:
        return Icons.restore_page_outlined;
    }
  }

  Future<void> _runAction() async {
    if (_isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final result = switch (widget.mode) {
        BackupRestoreMessageMode.backup => await _service.backup(),
        BackupRestoreMessageMode.restore => await _service.restore(),
      };
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: _pageTitle,
      loading: _isRunning,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsHero(
            icon: _heroIcon,
            title: _heroTitle,
            subtitle: _heroSubtitle,
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: '操作',
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(_buttonLabel),
                subtitle: Text(
                  widget.mode == BackupRestoreMessageMode.backup
                      ? '生成本地 JSON 后上传到 message/backup。'
                      : '下载 recovery JSON 后导入本地 SQLite。',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('message-backup-start-button'),
                    onPressed: _isRunning ? null : _runAction,
                    icon: Icon(_heroIcon),
                    label: Text(_buttonLabel),
                  ),
                ),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            SettingsSection(
              title: '结果',
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(
                    widget.mode == BackupRestoreMessageMode.backup
                        ? '备份完成'
                        : '恢复完成',
                  ),
                  subtitle: Text(
                    widget.mode == BackupRestoreMessageMode.backup
                        ? '${_result!.localPath}\n导出消息数：${_result!.exportedCount}'
                        : '${_result!.localPath}\n'
                              '导入消息数：${_result!.importedCount}，'
                              '跳过重复：${_result!.skippedCount}，'
                              '重建会话：${_result!.conversationCount}',
                  ),
                ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            SettingsSection(
              title: '错误',
              children: [
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('执行失败'),
                  subtitle: Text(_errorMessage!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
