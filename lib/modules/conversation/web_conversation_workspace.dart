import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';

import '../../data/models/chat_session.dart';
import '../../widgets/wk_conversation_item.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../chat/chat_page.dart';
import 'conversation_list_page.dart';

@visibleForTesting
bool shouldUseWebConversationWorkspace({
  required bool isWeb,
  required double viewportWidth,
}) {
  return isWeb && WKWebBreakpoints.useDesktopWorkbench(viewportWidth);
}

@visibleForTesting
bool shouldUseDesktopConversationWorkspace({
  required bool isWeb,
  required TargetPlatform platform,
  required double viewportWidth,
}) {
  return WKWebBreakpoints.useDesktopWorkbench(viewportWidth) &&
      (isWeb || _isDesktopPlatform(platform));
}

bool _isDesktopPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class WebConversationWorkspaceSelection {
  const WebConversationWorkspaceSelection({
    required this.session,
    this.channelName,
    this.channelCategory,
    this.initialVipLevel = 0,
  });

  final ChatSession session;
  final String? channelName;
  final String? channelCategory;
  final int initialVipLevel;

  String get key => '${session.channelId}:${session.channelType}';
}

@visibleForTesting
Widget buildConversationWorkbenchPaneForSelection(
  WebConversationWorkspaceSelection? selection,
) {
  return ConversationWorkbenchPanel(selection: selection);
}

class WebConversationWorkspace extends StatefulWidget {
  const WebConversationWorkspace({super.key});

  @override
  State<WebConversationWorkspace> createState() =>
      _WebConversationWorkspaceState();
}

class _WebConversationWorkspaceState extends State<WebConversationWorkspace> {
  WebConversationWorkspaceSelection? _selection;
  bool _workbenchExpanded = true;

  void _openConversation(
    WKUIConversationMsg conversation,
    ConversationPreferredInfo? preferredInfo,
    WKConversationItemData displayData,
  ) {
    final displayTitle = displayData.title.trim();
    setState(() {
      _selection = WebConversationWorkspaceSelection(
        session: ChatSession(
          channelId: conversation.channelID,
          channelType: conversation.channelType,
        ),
        channelName:
            preferredInfo?.title ??
            (displayTitle.isEmpty || displayTitle == conversation.channelID
                ? null
                : displayTitle),
        channelCategory: preferredInfo?.category ?? displayData.category,
        initialVipLevel: displayData.vipLevel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        if (!shouldUseDesktopConversationWorkspace(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
          viewportWidth: viewportWidth,
        )) {
          return const ConversationListPage();
        }
        final selection = _selection;
        return WebConversationWorkspaceScaffold(
          showRightContext: WKWebBreakpoints.useDesktopWorkbench(viewportWidth),
          workbenchExpanded: _workbenchExpanded,
          onWorkbenchExpandedChanged: (expanded) {
            setState(() => _workbenchExpanded = expanded);
          },
          listPane: ConversationListPage(
            embedded: true,
            selectedConversationKey: selection?.key,
            onOpenConversation: _openConversation,
          ),
          chatPane: selection == null
              ? const _EmptyConversationPane()
              : ChatPage(
                  key: ValueKey<String>('web-chat-${selection.key}'),
                  channelId: selection.session.channelId,
                  channelType: selection.session.channelType,
                  channelName: selection.channelName,
                  channelCategory: selection.channelCategory,
                  initialVipLevel: selection.initialVipLevel,
                ),
          rightContextPane: buildConversationWorkbenchPaneForSelection(
            selection,
          ),
        );
      },
    );
  }
}

class WebConversationWorkspaceScaffold extends StatelessWidget {
  const WebConversationWorkspaceScaffold({
    super.key,
    required this.listPane,
    required this.chatPane,
    this.rightContextPane,
    this.showRightContext = false,
    this.workbenchExpanded = true,
    this.onWorkbenchExpandedChanged,
  });

  final Widget listPane;
  final Widget chatPane;
  final Widget? rightContextPane;
  final bool showRightContext;
  final bool workbenchExpanded;
  final ValueChanged<bool>? onWorkbenchExpandedChanged;

  static const double _workbenchToggleStripWidth = 44;
  static const double _workbenchMinWidth = 260;
  static const double _workbenchDividerWidth = 3;
  static const double _chatPaneCompactMinWidth = 240;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final listWidth = _resolveConversationListWidth(workspaceWidth);
        final rightContextWidth = _resolveRightContextWidth(
          workspaceWidth,
          listWidth,
        );
        final canUseRightContext =
            showRightContext &&
            rightContextPane != null &&
            rightContextWidth != null;
        final showExpandedRightContext =
            canUseRightContext && workbenchExpanded;

        return Container(
          key: const ValueKey<String>('web-conversation-workspace'),
          color: WKWebColors.pageWarm,
          child: Row(
            children: [
              SizedBox(
                key: const ValueKey<String>('web-conversation-list-pane'),
                width: listWidth,
                child: listPane,
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: WKWebColors.borderWarm,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      right: _reservedRightContextWidth(
                        canUseRightContext: canUseRightContext,
                        showExpandedRightContext: showExpandedRightContext,
                        rightContextWidth: rightContextWidth,
                      ),
                      child: KeyedSubtree(
                        key: const ValueKey<String>(
                          'web-conversation-chat-pane',
                        ),
                        child: chatPane,
                      ),
                    ),
                    if (canUseRightContext)
                      Positioned(
                        top: 0,
                        right: showExpandedRightContext ? rightContextWidth : 0,
                        bottom: 0,
                        width: _workbenchToggleStripWidth,
                        child: _ConversationWorkbenchToggleRail(
                          expanded: showExpandedRightContext,
                          onPressed: () => onWorkbenchExpandedChanged?.call(
                            !showExpandedRightContext,
                          ),
                        ),
                      ),
                    if (showExpandedRightContext)
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: rightContextWidth,
                        child: KeyedSubtree(
                          key: const ValueKey<String>(
                            'web-conversation-right-pane',
                          ),
                          child: rightContextPane!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _resolveConversationListWidth(double workspaceWidth) {
    if (!workspaceWidth.isFinite || workspaceWidth <= 0) {
      return WKWebSizes.conversationListWidth;
    }
    final scaledWidth = workspaceWidth * 0.36;
    final maxWidth =
        workspaceWidth <=
            WKWebSizes.conversationListMinWidth + WKWebSizes.chatPaneMinWidth
        ? workspaceWidth * 0.42
        : WKWebSizes.conversationListWidth;
    final boundedMax = maxWidth.clamp(
      WKWebSizes.conversationListMinWidth,
      WKWebSizes.conversationListWidth,
    );
    return scaledWidth
        .clamp(WKWebSizes.conversationListMinWidth, boundedMax)
        .toDouble();
  }

  double? _resolveRightContextWidth(double workspaceWidth, double listWidth) {
    if (!workspaceWidth.isFinite) {
      return WKWebSizes.chatRightContextWidth;
    }
    final availableRightContextWidth =
        workspaceWidth -
        listWidth -
        _resolveChatPaneMinWidth(workspaceWidth) -
        _workbenchToggleStripWidth -
        _workbenchDividerWidth;
    if (availableRightContextWidth < _workbenchMinWidth) {
      return null;
    }
    return math
        .min(WKWebSizes.chatRightContextWidth, availableRightContextWidth)
        .clamp(_workbenchMinWidth, WKWebSizes.chatRightContextWidth)
        .toDouble();
  }

  double _reservedRightContextWidth({
    required bool canUseRightContext,
    required bool showExpandedRightContext,
    required double? rightContextWidth,
  }) {
    if (!canUseRightContext) {
      return 0;
    }
    return _workbenchToggleStripWidth +
        (showExpandedRightContext ? rightContextWidth ?? 0 : 0);
  }

  double _resolveChatPaneMinWidth(double workspaceWidth) {
    if (!workspaceWidth.isFinite || workspaceWidth <= 0) {
      return WKWebSizes.chatPaneMinWidth;
    }
    return math.min(
      WKWebSizes.chatPaneMinWidth,
      math.max(_chatPaneCompactMinWidth, workspaceWidth * 0.24),
    );
  }
}

class _ConversationWorkbenchToggleRail extends StatelessWidget {
  const _ConversationWorkbenchToggleRail({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKWebColors.surface,
      padding: const EdgeInsets.only(top: WKSpace.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: Tooltip(
          message: expanded ? '收起会话工作台' : '展开会话工作台',
          child: IconButton(
            key: const ValueKey<String>('conversation-workbench-toggle'),
            onPressed: onPressed,
            icon: Icon(
              expanded
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
            ),
            color: WKWebColors.action,
            style: IconButton.styleFrom(
              backgroundColor: WKWebColors.actionSoft,
              hoverColor: WKWebColors.borderWarm,
              fixedSize: const Size(32, 32),
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WKWebRadius.control),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversationPane extends StatelessWidget {
  const _EmptyConversationPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WKWebPanel(
        padding: const EdgeInsets.all(WKSpace.xl),
        child: Text(
          '选择一个会话开始聊天',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: WKWebColors.textSecondary),
        ),
      ),
    );
  }
}

class ConversationWorkbenchPanel extends StatelessWidget {
  const ConversationWorkbenchPanel({super.key, this.selection});

  final WebConversationWorkspaceSelection? selection;

  String get _displayName {
    final name = selection?.channelName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final id = selection?.session.channelId.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return '选择会话后显示详情';
  }

  String get _avatarText {
    final value = _displayName.trim();
    if (value.isEmpty || value == '选择会话后显示详情') {
      return '会';
    }
    return value.characters.first.toUpperCase();
  }

  String get _statusText {
    final status = selection?.channelCategory?.trim();
    if (status != null && status.isNotEmpty) {
      return status;
    }
    return '暂无会话状态';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('conversation-workbench-panel'),
      color: WKWebColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: WKSpace.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WKWebColors.borderWarm)),
            ),
            child: Text(
              '会话工作台',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: WKWebColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(WKSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkbenchSection(
                    key: const ValueKey<String>(
                      'conversation-workbench-members-section',
                    ),
                    title: '成员',
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: WKWebColors.actionSoft,
                            borderRadius: BorderRadius.circular(
                              WKWebRadius.avatar,
                            ),
                          ),
                          child: Text(
                            _avatarText,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.title,
                              color: WKWebColors.action,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: WKSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: WKFontFamily.primary,
                                  color: WKWebColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selection == null ? '暂无选中会话' : '当前会话',
                                style: const TextStyle(
                                  fontFamily: WKFontFamily.primary,
                                  color: WKWebColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _WorkbenchSection(
                    key: const ValueKey<String>(
                      'conversation-workbench-status-section',
                    ),
                    title: '置顶 / 公告',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkbenchPill(text: _statusText),
                        const SizedBox(height: WKSpace.xs),
                        const _WorkbenchPill(text: '暂无群公告'),
                      ],
                    ),
                  ),
                  const _WorkbenchSection(
                    key: ValueKey<String>(
                      'conversation-workbench-files-section',
                    ),
                    title: '文件与图片',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkbenchFileEntry(text: '暂无最近图片'),
                        SizedBox(height: WKSpace.xs),
                        _WorkbenchFileEntry(text: '暂无最近文件'),
                      ],
                    ),
                  ),
                  const _WorkbenchSection(
                    key: ValueKey<String>(
                      'conversation-workbench-actions-section',
                    ),
                    title: '快捷操作',
                    child: Wrap(
                      spacing: WKSpace.xs,
                      runSpacing: WKSpace.xs,
                      children: [
                        _WorkbenchActionChip(label: '查找'),
                        _WorkbenchActionChip(label: '置顶'),
                        _WorkbenchActionChip(label: '免打扰'),
                        _WorkbenchActionChip(label: '设置'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchSection extends StatelessWidget {
  const _WorkbenchSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              color: WKWebColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          child,
        ],
      ),
    );
  }
}

class _WorkbenchPill extends StatelessWidget {
  const _WorkbenchPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      decoration: BoxDecoration(
        color: WKWebColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.pill),
        border: Border.all(color: WKWebColors.borderWarm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _WorkbenchFileEntry extends StatelessWidget {
  const _WorkbenchFileEntry({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      decoration: BoxDecoration(
        color: WKWebColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
        border: Border.all(color: WKWebColors.borderWarm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WorkbenchActionChip extends StatelessWidget {
  const _WorkbenchActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WKWebColors.actionSoft,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.action,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
