import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class ErrorLogsPage extends StatefulWidget {
  const ErrorLogsPage({super.key});

  @override
  State<ErrorLogsPage> createState() => _ErrorLogsPageState();
}

class _ErrorLogsPageState extends State<ErrorLogsPage> {
  final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm');
  List<_LogFileItem> _logs = const [];
  bool _isLoading = true;
  String? _crashDirectoryPath;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final crashDirectory = Directory(
        path.join(documentsDirectory.path, 'wkCrash'),
      );
      final items = <_LogFileItem>[];

      if (await crashDirectory.exists()) {
        final entities = await crashDirectory.list().toList();
        for (final entity in entities) {
          if (entity is! File) {
            continue;
          }
          final stat = await entity.stat();
          items.add(
            _LogFileItem(
              name: path.basename(entity.path),
              absolutePath: entity.path,
              sizeInBytes: stat.size,
              modifiedAt: stat.modified,
            ),
          );
        }
        items.sort(
          (left, right) => left.modifiedAt.compareTo(right.modifiedAt),
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _logs = items;
        _crashDirectoryPath = crashDirectory.path;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _logs = const [];
        _crashDirectoryPath = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _showActions(_LogFileItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('转发'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(
                    ClipboardData(text: item.absolutePath),
                  );
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日志路径已复制，可继续接入真正的转发能力')),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  '删除',
                  style: TextStyle(color: WKColors.danger),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _deleteLog(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteLog(_LogFileItem item) async {
    try {
      final file = File(item.absolutePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _loadLogs();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除日志失败：$error')));
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '开发日志',
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadLogs,
            child: ListView(
              padding: const EdgeInsets.only(top: 20),
              children: [
                if (_logs.isEmpty)
                  WKSettingsGroup(
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 18,
                        ),
                        child: Text(
                          '当前没有可显示的开发日志。',
                          style: TextStyle(
                            fontSize: 15,
                            color: WKColors.color999,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  WKSettingsGroup(
                    children: [
                      for (final log in _logs)
                        _LogFileCell(
                          item: log,
                          sizeLabel: _formatSize(log.sizeInBytes),
                          timeLabel: _timeFormat.format(log.modifiedAt),
                          onLongPress: () => _showActions(log),
                        ),
                    ],
                  ),
                WKSettingsDescription(
                  text: _crashDirectoryPath == null
                      ? '原版页面读取的是 wkCrash 目录。当前移植工程已经保持同样的目录约定，并支持长按删除。'
                      : '当前读取目录：$_crashDirectoryPath',
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _LogFileCell extends StatelessWidget {
  final _LogFileItem item;
  final String sizeLabel;
  final String timeLabel;
  final VoidCallback onLongPress;

  const _LogFileCell({
    required this.item,
    required this.sizeLabel,
    required this.timeLabel,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: WKColors.colorDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sizeLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: WKColors.color999,
                      ),
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: WKColors.color999,
                    ),
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

class _LogFileItem {
  final String name;
  final String absolutePath;
  final int sizeInBytes;
  final DateTime modifiedAt;

  const _LogFileItem({
    required this.name,
    required this.absolutePath,
    required this.sizeInBytes,
    required this.modifiedAt,
  });
}
