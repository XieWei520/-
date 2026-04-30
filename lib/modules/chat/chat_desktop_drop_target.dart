import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../widgets/wk_colors.dart';
import 'chat_media_action_service.dart';

typedef ChatDroppedFilesCallback =
    FutureOr<void> Function(List<ChatDroppedFileSelection> files);

class ChatDesktopDropTarget extends StatefulWidget {
  const ChatDesktopDropTarget({
    super.key,
    required this.child,
    required this.enabled,
    required this.onFilesDropped,
  });

  final Widget child;
  final bool enabled;
  final ChatDroppedFilesCallback onFilesDropped;

  @override
  State<ChatDesktopDropTarget> createState() => _ChatDesktopDropTargetState();
}

class _ChatDesktopDropTargetState extends State<ChatDesktopDropTarget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return DropTarget(
      key: const ValueKey<String>('chat-desktop-drop-target'),
      enable: widget.enabled,
      onDragEntered: (_) => _setHovering(true),
      onDragExited: (_) => _setHovering(false),
      onDragDone: _handleDropDone,
      child: Stack(
        children: [
          widget.child,
          if (_isHovering) const _ChatDesktopDropOverlay(),
        ],
      ),
    );
  }

  Future<void> _handleDropDone(DropDoneDetails details) async {
    _setHovering(false);
    final files = await mapDesktopDropItemsToChatFiles(details.files);
    if (files.isEmpty) {
      return;
    }
    await widget.onFilesDropped(files);
  }

  void _setHovering(bool value) {
    if (_isHovering == value) {
      return;
    }
    if (!mounted) {
      _isHovering = value;
      return;
    }
    setState(() {
      _isHovering = value;
    });
  }
}

class _ChatDesktopDropOverlay extends StatelessWidget {
  const _ChatDesktopDropOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          key: const ValueKey<String>('chat-desktop-drop-overlay'),
          decoration: BoxDecoration(
            color: WKColors.brand500.withValues(alpha: 0.08),
            border: Border.all(color: WKColors.brand500, width: 2),
          ),
          child: const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      color: WKColors.brand500,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      '\u677e\u5f00\u5373\u53ef\u53d1\u9001\u6587\u4ef6\u6216\u56fe\u7247',
                      style: TextStyle(
                        color: WKColors.brand500,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<List<ChatDroppedFileSelection>> mapDesktopDropItemsToChatFiles(
  List<DropItem> items,
) async {
  final selections = <ChatDroppedFileSelection>[];
  for (final item in items) {
    if (item is DropItemDirectory) {
      continue;
    }
    final localPath = item.path.trim();
    if (localPath.isEmpty) {
      continue;
    }
    int size;
    try {
      size = await item.length();
    } catch (_) {
      continue;
    }
    final rawName = item.name.trim();
    final fileName = path.basename(rawName.isNotEmpty ? rawName : localPath);
    selections.add(
      ChatDroppedFileSelection(
        localPath: localPath,
        name: fileName,
        size: size,
        mimeType: item.mimeType,
      ),
    );
  }
  return selections;
}
