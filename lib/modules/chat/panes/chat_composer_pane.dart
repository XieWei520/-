import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_gif_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../../core/utils/platform_utils.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/providers/conversation_provider.dart';
import '../../../service/api/group_api.dart';
import '../../../service/api/robot_api.dart';
import '../../../service/api/user_api.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';
import '../../../widgets/wk_reference_assets.dart';
import '../../../widgets/wk_web_ui_tokens.dart';
import '../../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../../wk_endpoint/slots/chat_slots.dart';
import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import '../../../wukong_base/views/mention_suggestion.dart';
import '../../../wukong_robot/models/robot.dart';
import '../../../wukong_robot/robot_service.dart';
import '../chat_action_definition.dart';
import '../chat_action_dispatcher.dart';
import '../chat_call_navigation.dart';
import '../chat_channel_settings.dart';
import '../chat_composer_controller.dart';
import '../chat_desktop_drop_target.dart';
import '../chat_gif_panel_service.dart';
import '../chat_media_action_service.dart';
import '../chat_mentions_controller.dart';
import '../chat_scene_providers.dart';
import '../chat_text_sticker_conversion.dart';
import '../chat_typing_gateway.dart';
import '../chat_toolbar_slot_assembly.dart';
import '../chat_voice_action_service.dart';
import '../expression/chat_expression_models.dart';
import '../expression/chat_expression_registry.dart';
import '../message_content_preview.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_edit_preview_strip.dart';
import '../widgets/chat_expression_panel.dart';
import '../widgets/chat_reply_preview_strip.dart';
import '../widgets/chat_voice_press_hold_button.dart';
import '../widgets/chat_voice_record_overlay.dart';
import 'chat_composer_controls.dart';

const String _voiceTooltip = '\u8bed\u97f3\u901a\u8bdd';
const String _videoTooltip = '\u89c6\u9891\u901a\u8bdd';
const String _groupCallTooltip = '\u591a\u4eba\u901a\u8bdd';
const String _replyFallbackTitle = '\u5f15\u7528\u6d88\u606f';
const String _voicePermissionDeniedFeedback =
    '\u9700\u8981\u5141\u8bb8\u9ea6\u514b\u98ce\u6743\u9650\u540e\u624d\u80fd\u53d1\u9001\u8bed\u97f3';
const String _voiceTooShortFeedback = '\u5f55\u97f3\u65f6\u95f4\u592a\u77ed';
const String _voiceStartFailedFallback =
    '\u8bed\u97f3\u5f55\u5236\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
const String _sendFailureRetainedFeedback =
    '\u53d1\u9001\u5931\u8d25\uff0c\u6d88\u606f\u5df2\u4fdd\u7559\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5';

SnackBar _buildLiquidSnackBar(String message, {EdgeInsetsGeometry? margin}) {
  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: LiquidGlassColors.darkSurfaceSolid,
    margin: margin,
  );
}

class ChatComposerPane extends ConsumerStatefulWidget {
  const ChatComposerPane({
    super.key,
    required this.session,
    this.channel,
    this.robotMenus = const <RobotMenu>[],
    this.showCallActions = false,
    this.showGroupCallAction = false,
    this.webStyle = false,
    this.onAudioCallTap,
    this.onVideoCallTap,
    this.onGroupCallTap,
    this.onSubmitText,
  });

  final ChatSession session;
  final WKChannel? channel;
  final List<RobotMenu> robotMenus;
  final bool showCallActions;
  final bool showGroupCallAction;
  final bool webStyle;
  final VoidCallback? onAudioCallTap;
  final VoidCallback? onVideoCallTap;
  final VoidCallback? onGroupCallTap;
  final ValueChanged<String>? onSubmitText;

  @override
  ConsumerState<ChatComposerPane> createState() => _ChatComposerPaneState();
}

class _ChatComposerPaneState extends ConsumerState<ChatComposerPane> {
  final TextEditingController _textController = TextEditingController();
  late final ChatTextStickerConversion _textStickerConversion;
  ChatVoiceActionService? _voiceService;
  int _lastTypingReportAtSeconds = 0;
  WKChannel? _channel;
  double? _flameSliderValue;
  Robot? _activeInlineRobot;
  String? _robotInlinePlaceholder;
  List<RobotInlineQueryResult> _robotGifResults =
      const <RobotInlineQueryResult>[];
  List<ChatGifPanelResult> _panelGifResults = const <ChatGifPanelResult>[];
  String? _panelGifErrorText;
  Future<ChatExpressionRegistrySnapshot>? _expressionRegistryFuture;
  int _robotInlineRequestToken = 0;
  bool _isSubmittingComposer = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _textStickerConversion = ChatTextStickerConversion();
  }

  @override
  void didUpdateWidget(covariant ChatComposerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != oldWidget.channel && widget.channel != null) {
      _channel = widget.channel;
      _flameSliderValue = null;
    }
    if (widget.session != oldWidget.session) {
      _clearRobotInlineState();
      _panelGifResults = const <ChatGifPanelResult>[];
      _panelGifErrorText = null;
      _expressionRegistryFuture = null;
    }
  }

  @override
  void dispose() {
    final voiceService = _voiceService;
    if (voiceService != null &&
        _isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      unawaited(voiceService.cancelRecording());
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composerState = ref.watch(chatComposerProvider(widget.session));
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    final mentionsState = ref.watch(
      chatMentionsControllerProvider(widget.session),
    );
    final mentionsController = ref.read(
      chatMentionsControllerProvider(widget.session).notifier,
    );
    final voiceService = ref.watch(chatVoiceActionServiceProvider);
    _voiceService = voiceService;
    final registry = ref.read(slotRegistryProvider);
    final slotContext = ChatToolbarSlotContext(
      isGroup: widget.session.channelType == WKChannelType.group,
      showVoiceInput: composerState.showVoiceInput,
      showEmojiPanel: composerState.showFacePanel,
      showFunctionPanel: composerState.showFunctionPanel,
      isMobile: PlatformUtils.isMobile,
      isDesktop: PlatformUtils.isDesktop,
      isWeb: PlatformUtils.isWeb,
    );
    final toolbarItems = resolveChatToolbarItems(registry, slotContext);
    final functionItems = resolveChatFunctionItems(registry, slotContext);
    final currentChannel = _channel ?? widget.channel;
    final flameEnabled = isChannelFlameEnabled(currentChannel);

    _syncText(composerState.text);

    final composer = Stack(
      children: [
        ChatComposer(
          header: _buildComposerHeader(composerState, composerController),
          robotInlineHeader: _buildRobotInlineHeader(
            composerState,
            mentionsState,
            composerController,
            mentionsController,
          ),
          webStyle: widget.webStyle,
          showToolbarRow: true,
          inputRow: _buildComposerInputRow(
            composerState: composerState,
            composerController: composerController,
            mentionsController: mentionsController,
            voiceService: voiceService,
            flameEnabled: flameEnabled,
          ),
          toolbarRow: _buildComposerToolbarRow(
            composerState: composerState,
            composerController: composerController,
            mentionsController: mentionsController,
            toolbarItems: toolbarItems,
          ),
          panel: _buildPanel(
            composerState,
            functionItems,
            currentChannel,
            composerController,
            mentionsController,
          ),
        ),
        ValueListenableBuilder<ChatVoiceRecordingState>(
          valueListenable: voiceService.recordingStateListenable,
          builder: (context, voiceState, _) {
            return ChatVoiceRecordOverlay(state: voiceState);
          },
        ),
      ],
    );
    return ChatDesktopDropTarget(
      enabled: PlatformUtils.isDesktop,
      onFilesDropped: (files) => _handleDroppedFiles(files, composerController),
      child: composer,
    );
  }

  Widget? _buildComposerHeader(
    ChatComposerState composerState,
    ChatComposerController composerController,
  ) {
    if (composerState.pendingEditMessageId != null) {
      return ChatEditPreviewStrip(
        previewText: composerState.pendingEditPreview?.trim().isNotEmpty == true
            ? composerState.pendingEditPreview!.trim()
            : composerState.text.trim(),
        onClose: () {
          composerController.clearPendingEdit(clearText: true);
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
        },
      );
    }
    if (composerState.pendingReplyMessageId != null) {
      return ChatReplyPreviewStrip(
        previewText:
            composerState.pendingReplyPreview?.trim().isNotEmpty == true
            ? composerState.pendingReplyPreview!.trim()
            : _replyFallbackTitle,
        onClose: () {
          composerController.clearPendingReply();
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
        },
      );
    }
    return null;
  }

  Widget? _buildRobotInlineHeader(
    ChatComposerState composerState,
    ChatMentionsState mentionsState,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final headers = <Widget>[];
    if (!composerState.showVoiceInput &&
        mentionsState.isActive &&
        mentionsState.suggestions.isNotEmpty) {
      headers.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MentionSuggestionOverlay(
              suggestions: mentionsState.suggestions,
              selectedIndex: 0,
              onSelected: (suggestion) {
                final selectionBaseOffset =
                    _textController.selection.baseOffset;
                final cursorOffset = selectionBaseOffset < 0
                    ? _textController.text.length
                    : selectionBaseOffset;
                final result = mentionsController.applySelection(
                  _textController.text,
                  cursorOffset: cursorOffset,
                  suggestion: suggestion,
                );
                _applyComposerValue(
                  TextEditingValue(
                    text: result.text,
                    selection: TextSelection.collapsed(
                      offset: result.cursorOffset,
                    ),
                  ),
                  composerController,
                  mentionsController,
                  reportTyping: false,
                );
              },
            ),
          ),
        ),
      );
    }
    if (!composerState.showVoiceInput &&
        _robotGifResults.isEmpty &&
        _robotInlinePlaceholder?.trim().isNotEmpty == true) {
      final tokens = LiquidGlassTokens.of(context);
      headers.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey<String>('chat-robot-placeholder'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tokens.border),
              ),
              child: Text(
                _robotInlinePlaceholder!.trim(),
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (headers.isEmpty) {
      return null;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: headers);
  }

  Widget _buildComposerInputRow({
    required ChatComposerState composerState,
    required ChatComposerController composerController,
    required ChatMentionsController mentionsController,
    required ChatVoiceActionService voiceService,
    required bool flameEnabled,
  }) {
    final canSend =
        composerState.text.trim().isNotEmpty && !_isSubmittingComposer;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileWarmStyle =
            PlatformUtils.isMobile && constraints.maxWidth < 420;
        final compact =
            constraints.maxWidth.isFinite && constraints.maxWidth < 360;
        final gap = compact ? 6.0 : 8.0;
        final actionExtent = isMobileWarmStyle
            ? mobileComposerActionButtonExtent
            : compact
            ? 42.0
            : composerActionButtonExtent;
        final iconExtent = isMobileWarmStyle
            ? mobileComposerActionIconExtent
            : compact
            ? 22.0
            : composerActionIconExtent;
        final sendWidth = isMobileWarmStyle
            ? mobileComposerSendButtonWidth
            : actionExtent;
        final sendHeight = actionExtent;
        final inputRadius = BorderRadius.circular(isMobileWarmStyle ? 14 : 24);
        final tokens = LiquidGlassTokens.of(context);
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final mobileWarmSurfaceColor = isDarkTheme
            ? tokens.surface
            : WKWebColors.surface;
        final mobileWarmBorderColor = isDarkTheme
            ? tokens.border
            : WKWebColors.borderWarm;
        final mobileWarmFocusedBorderColor = isDarkTheme
            ? tokens.borderStrong
            : WKWebColors.action;
        late final Widget inlineActionButton;
        if (isMobileWarmStyle) {
          inlineActionButton = isDarkTheme
              ? SizedBox(
                  width: actionExtent,
                  height: actionExtent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mobileWarmSurfaceColor,
                      borderRadius: BorderRadius.circular(WKWebRadius.control),
                      border: Border.all(
                        color: mobileWarmBorderColor,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        key: const ValueKey<String>('chat-compose-plus-button'),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: actionExtent,
                          height: actionExtent,
                        ),
                        onPressed: composerController.toggleFunctionPanel,
                        icon: WKReferenceAssets.image(
                          WKReferenceAssets.chatAdd,
                          width: iconExtent,
                          height: iconExtent,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                )
              : ComposerToolbarButton(
                  key: const ValueKey<String>('chat-compose-plus-button'),
                  asset: WKReferenceAssets.chatAdd,
                  extent: actionExtent,
                  artworkExtent: iconExtent,
                  fit: BoxFit.contain,
                  warmStyle: true,
                  onTap: composerController.toggleFunctionPanel,
                );
        } else if (flameEnabled) {
          inlineActionButton = ComposerToolbarButton(
            key: const ValueKey<String>('chat-flame-toggle-button'),
            asset: WKReferenceAssets.flameSmall,
            extent: actionExtent,
            artworkExtent: iconExtent,
            fit: BoxFit.contain,
            onTap: composerController.toggleFlamePanel,
          );
        } else {
          inlineActionButton = ComposerToolbarButton(
            key: const ValueKey<String>('chat-compose-rich-text-button'),
            asset: WKReferenceAssets.chatRichEdit,
            extent: actionExtent,
            artworkExtent: iconExtent,
            fit: BoxFit.contain,
            onTap: () => unawaited(
              _executeChatAction(
                ChatActionId.composeRichText,
                composerController,
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: composerState.showVoiceInput
                  ? ValueListenableBuilder<ChatVoiceRecordingState>(
                      valueListenable: voiceService.recordingStateListenable,
                      builder: (context, voiceState, _) {
                        return ChatVoicePressHoldButton(
                          key: const ValueKey<String>(
                            'chat-voice-record-button',
                          ),
                          isRecording: _isVoiceSessionActive(voiceState),
                          onHoldStart: _startVoiceRecording,
                          onCancelZoneChanged: voiceService.setCancelCandidate,
                          onHoldRelease: (isInCancelZone) =>
                              _finishVoiceRecording(
                                composerController,
                                shouldSend: !isInCancelZone,
                              ),
                          onHoldAbort: _cancelVoiceRecording,
                        );
                      },
                    )
                  : CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          shift: true,
                        ): () => _insertTextAtCursor(
                          '\n',
                          composerController,
                          mentionsController,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.numpadEnter,
                          shift: true,
                        ): () => _insertTextAtCursor(
                          '\n',
                          composerController,
                          mentionsController,
                        ),
                        const SingleActivator(LogicalKeyboardKey.enter): () =>
                            _handleKeyboardSend(
                              composerController,
                              mentionsController,
                            ),
                        const SingleActivator(
                          LogicalKeyboardKey.numpadEnter,
                        ): () => _handleKeyboardSend(
                          composerController,
                          mentionsController,
                        ),
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: isMobileWarmStyle ? actionExtent : 0,
                        ),
                        child: TextField(
                          key: const ValueKey<String>('chat-input-field'),
                          controller: _textController,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontFamily: WKFontFamily.primary,
                                fontFamilyFallback:
                                    WKTypography.fontFamilyFallback,
                              ),
                          onTap: composerController.hidePanels,
                          onChanged: (value) => _handleTextChanged(
                            value,
                            composerController,
                            mentionsController,
                          ),
                          decoration: InputDecoration(
                            hintText: '\u8f93\u5165\u6d88\u606f',
                            isDense: isMobileWarmStyle,
                            border: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? BorderSide(
                                      color: mobileWarmBorderColor,
                                      width: 1.2,
                                    )
                                  : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? BorderSide(
                                      color: mobileWarmBorderColor,
                                      width: 1.2,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? BorderSide(
                                      color: mobileWarmFocusedBorderColor,
                                      width: 1.4,
                                    )
                                  : BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isMobileWarmStyle
                                ? mobileWarmSurfaceColor
                                : WKColors.surfaceSoft,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isMobileWarmStyle
                                  ? 16
                                  : compact
                                  ? 12
                                  : 16,
                              vertical: isMobileWarmStyle ? 14 : 8,
                            ),
                          ),
                          maxLines: isMobileWarmStyle ? 3 : 4,
                          minLines: 1,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: gap),
            inlineActionButton,
            if (!composerState.showVoiceInput) ...[
              SizedBox(width: gap),
              ComposerSendButton(
                enabled: canSend,
                width: sendWidth,
                height: sendHeight,
                iconExtent: iconExtent,
                warmStyle: isMobileWarmStyle,
                liquidStyle: isMobileWarmStyle || widget.webStyle,
                onTap: canSend
                    ? () => _handleSendPressed(
                        composerController,
                        mentionsController,
                      )
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  void _handleKeyboardSend(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    if (_isSubmittingComposer || _textController.text.trim().isEmpty) {
      return;
    }
    unawaited(_handleSendPressed(composerController, mentionsController));
  }

  Widget _buildComposerToolbarRow({
    required ChatComposerState composerState,
    required ChatComposerController composerController,
    required ChatMentionsController mentionsController,
    required List<ChatToolBarMenu> toolbarItems,
  }) {
    final toolbarButtons = <Widget>[];
    var insertedCallButtons = false;

    void addButton(Widget button) {
      if (toolbarButtons.isNotEmpty) {
        toolbarButtons.add(const SizedBox(width: 8));
      }
      toolbarButtons.add(button);
    }

    void addCallButtons() {
      if (insertedCallButtons) {
        return;
      }
      insertedCallButtons = true;
      if (widget.showCallActions &&
          widget.onAudioCallTap != null &&
          widget.onVideoCallTap != null) {
        addButton(
          ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-call-audio-button'),
            decorationKey: const ValueKey<String>('chat-call-audio-decoration'),
            tooltip: _voiceTooltip,
            asset: WKReferenceAssets.chatCallVoice,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF36E6B3), Color(0xFF16A76C)],
            ),
            onTap: widget.onAudioCallTap!,
          ),
        );
        addButton(
          ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-call-video-button'),
            decorationKey: const ValueKey<String>('chat-call-video-decoration'),
            tooltip: _videoTooltip,
            asset: WKReferenceAssets.chatCallVideo,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8C7BFF), Color(0xFFFF6FB1)],
            ),
            onTap: widget.onVideoCallTap!,
          ),
        );
      }
      if (widget.showGroupCallAction && widget.onGroupCallTap != null) {
        addButton(
          ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-group-call-button'),
            decorationKey: const ValueKey<String>('chat-call-group-decoration'),
            tooltip: _groupCallTooltip,
            asset: WKReferenceAssets.chatCallVideo,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
            ),
            onTap: widget.onGroupCallTap!,
          ),
        );
      }
    }

    for (var index = 0; index < toolbarItems.length; index++) {
      final item = toolbarItems[index];
      if (item.sid == 'wk_chat_toolbar_more') {
        addCallButtons();
      }
      addButton(
        ComposerToolbarButton(
          key: ValueKey<String>('chat-toolbar-${item.sid}'),
          asset: item.icon ?? '',
          onTap: () => unawaited(
            _handleToolbarTap(item, composerController, mentionsController),
          ),
        ),
      );
      if (item.sid == 'wk_chat_toolbar_album') {
        addCallButtons();
      }
    }

    addCallButtons();

    if (widget.robotMenus.isNotEmpty) {
      addButton(
        ComposerToolbarButton(
          key: const ValueKey<String>('chat-robot-menu-button'),
          asset: composerState.showRobotMenuPanel
              ? WKReferenceAssets.chatMenuClose
              : WKReferenceAssets.chatMenu,
          onTap: composerController.toggleRobotMenuPanel,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: toolbarButtons),
      ),
    );
  }

  void _syncText(String nextText) {
    if (_textController.text == nextText) {
      return;
    }
    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _handleTextChanged(
    String value,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    composerController.updateText(value);
    final selectionBaseOffset = _textController.selection.baseOffset;
    final cursorOffset = selectionBaseOffset < 0
        ? value.length
        : selectionBaseOffset;
    unawaited(
      mentionsController.updateFromText(value, cursorOffset: cursorOffset),
    );
    unawaited(_handleRobotInlineInput(value));
    _reportTypingIfNeeded(value);
  }

  void _applyComposerValue(
    TextEditingValue value,
    ChatComposerController composerController,
    ChatMentionsController mentionsController, {
    bool reportTyping = true,
  }) {
    _textController.value = value;
    composerController.updateText(value.text);
    final selectionBaseOffset = value.selection.baseOffset;
    final cursorOffset = selectionBaseOffset < 0
        ? value.text.length
        : selectionBaseOffset;
    unawaited(
      mentionsController.updateFromText(value.text, cursorOffset: cursorOffset),
    );
    unawaited(_handleRobotInlineInput(value.text));
    if (reportTyping) {
      _reportTypingIfNeeded(value.text);
    }
  }

  void _insertEmoji(
    String emoji,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    _insertTextAtCursor(emoji, composerController, mentionsController);
  }

  void _insertTextAtCursor(
    String insertedText,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final currentValue = _textController.value;
    final selection = currentValue.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, currentValue.text.length).toInt()
        : currentValue.text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, currentValue.text.length).toInt()
        : currentValue.text.length;
    final replaceStart = start < end ? start : end;
    final replaceEnd = start < end ? end : start;
    final nextText = currentValue.text.replaceRange(
      replaceStart,
      replaceEnd,
      insertedText,
    );
    _applyComposerValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: replaceStart + insertedText.length,
        ),
      ),
      composerController,
      mentionsController,
    );
  }

  void _deletePreviousComposerCharacter(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final currentValue = _textController.value;
    final selection = currentValue.selection;
    if (!selection.isValid) {
      return;
    }

    final start = selection.start.clamp(0, currentValue.text.length).toInt();
    final end = selection.end.clamp(0, currentValue.text.length).toInt();
    final replaceStart = start < end ? start : end;
    final replaceEnd = start < end ? end : start;

    if (replaceStart != replaceEnd) {
      final nextText = currentValue.text.replaceRange(
        replaceStart,
        replaceEnd,
        '',
      );
      _applyComposerValue(
        TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: replaceStart),
        ),
        composerController,
        mentionsController,
      );
      return;
    }

    if (replaceStart == 0) {
      return;
    }

    final prefix = currentValue.text.substring(0, replaceStart);
    final previousCharacter = prefix.characters.last;
    final deletionStart = replaceStart - previousCharacter.length;
    final nextText = currentValue.text.replaceRange(
      deletionStart,
      replaceStart,
      '',
    );
    _applyComposerValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: deletionStart),
      ),
      composerController,
      mentionsController,
    );
  }

  void _reportTypingIfNeeded(String value) {
    if (value.isEmpty) {
      return;
    }
    final nowSeconds = ref.read(chatTypingNowProvider)();
    if (nowSeconds - _lastTypingReportAtSeconds < 5) {
      return;
    }
    _lastTypingReportAtSeconds = nowSeconds;
    unawaited(_sendTypingIfAllowed());
  }

  Future<void> _sendTypingIfAllowed() async {
    try {
      await ref
          .read(chatTypingGatewayProvider)
          .sendIfAllowed(
            channelId: widget.session.channelId,
            channelType: widget.session.channelType,
          );
    } catch (_) {
      // Android silently ignores typing report failures.
    }
  }

  Future<void> _handleRobotInlineInput(String value) async {
    final directive = _RobotInlineDirective.parse(value);
    if (directive == null) {
      _clearRobotInlineState();
      return;
    }

    final requestToken = ++_robotInlineRequestToken;
    Robot? robot = _activeInlineRobot;
    final normalizedUsername = directive.username.toLowerCase();
    if (robot == null || robot.username.toLowerCase() != normalizedUsername) {
      robot = _findRobotByUsername(normalizedUsername);
      if (robot == null) {
        final synced = await RobotService.instance.syncRobots(
          targets: <RobotSyncTarget>[
            RobotSyncTarget(username: normalizedUsername),
          ],
          forceRefresh: true,
        );
        if (!mounted || requestToken != _robotInlineRequestToken) {
          return;
        }
        for (final candidate in synced) {
          if (candidate.username.toLowerCase() == normalizedUsername) {
            robot = candidate;
            break;
          }
        }
      }
    }

    if (!mounted || requestToken != _robotInlineRequestToken) {
      return;
    }

    if (robot == null) {
      _clearRobotInlineState();
      return;
    }

    if (directive.isGifQuery && directive.query.isNotEmpty) {
      final results = await RobotService.instance.searchGifs(
        query: directive.query,
        username: robot.username,
        channelId: widget.session.channelId,
        channelType: widget.session.channelType,
      );
      if (!mounted || requestToken != _robotInlineRequestToken) {
        return;
      }
      setState(() {
        _activeInlineRobot = robot;
        _robotInlinePlaceholder = null;
        _robotGifResults = List<RobotInlineQueryResult>.unmodifiable(results);
      });
      return;
    }

    setState(() {
      _activeInlineRobot = robot;
      _robotInlinePlaceholder =
          directive.hasSeparator && directive.query.isEmpty
          ? robot?.placeholder?.trim()
          : null;
      _robotGifResults = const <RobotInlineQueryResult>[];
    });
  }

  Robot? _findRobotByUsername(String username) {
    for (final robot in RobotService.instance.getAllRobots()) {
      if (robot.username.toLowerCase() == username) {
        return robot;
      }
    }
    return null;
  }

  void _clearRobotInlineState() {
    _robotInlineRequestToken += 1;
    if (_activeInlineRobot == null && _robotGifResults.isEmpty) {
      return;
    }
    setState(() {
      _activeInlineRobot = null;
      _robotInlinePlaceholder = null;
      _robotGifResults = const <RobotInlineQueryResult>[];
    });
  }

  Future<void> _handleToolbarTap(
    ChatToolBarMenu item,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) async {
    switch (item.sid) {
      case 'wk_chat_toolbar_emoji':
        composerController.toggleFacePanel(initialCategoryId: 'emoji:0');
        break;
      case 'wk_chat_toolbar_mention':
        if (composerController.isVoiceInputVisible) {
          final voiceService = _voiceService;
          final voiceState = voiceService?.recordingStateListenable.value;
          if (voiceState != null && _isVoiceSessionActive(voiceState)) {
            await _cancelVoiceRecording();
          }
          composerController.toggleVoiceInput();
        }
        _insertTextAtCursor('@', composerController, mentionsController);
        break;
      case 'wk_chat_toolbar_more':
        composerController.toggleFunctionPanel();
        break;
      case 'wk_chat_toolbar_album':
        await _sendPickedContent(
          await ref
              .read(chatMediaActionServiceProvider)
              .pickImage(
                context,
                channelId: widget.session.channelId,
                channelType: widget.session.channelType,
              ),
          composerController,
        );
        break;
      case 'wk_chat_toolbar_voice':
        final voiceService = _voiceService;
        final voiceState = voiceService?.recordingStateListenable.value;
        if (voiceState == null) {
          composerController.toggleVoiceInput();
          break;
        }
        if (_isVoiceSessionActive(voiceState)) {
          await _cancelVoiceRecording();
        }
        composerController.toggleVoiceInput();
        break;
    }
    item.onChecked?.call(!item.isSelected);
  }

  Future<void> _handleFunctionTap(
    String sid,
    ChatComposerController composerController,
  ) async {
    switch (sid) {
      case 'chooseImg':
        await _executeChatAction(ChatActionId.chooseImage, composerController);
        return;
      case 'chooseFile':
        await _executeChatAction(ChatActionId.chooseFile, composerController);
        return;
      case 'sendLocation':
        await _executeChatAction(ChatActionId.sendLocation, composerController);
        return;
      case 'chooseCard':
        await _executeChatAction(ChatActionId.chooseCard, composerController);
        return;
      case 'composeRichText':
        await _executeChatAction(
          ChatActionId.composeRichText,
          composerController,
        );
        return;
      case 'groupCall':
        await pushGroupCallPicker(
          context: context,
          ref: ref,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
          channelName: _channel?.channelName.trim().isNotEmpty == true
              ? _channel!.channelName.trim()
              : null,
        );
        return;
    }
  }

  Future<void> _executeChatAction(
    ChatActionId id,
    ChatComposerController composerController,
  ) async {
    final result = await ref
        .read(chatActionDispatcherProvider)
        .dispatch(
          id,
          ChatActionDispatchContext(
            context: context,
            channelId: widget.session.channelId,
            channelType: widget.session.channelType,
          ),
        );

    if (result is ChatActionMessageResult) {
      await _sendPickedContent(result.content, composerController);
    }
  }

  Future<void> _sendPickedContent(
    WKMessageContent? content,
    ChatComposerController composerController,
  ) async {
    if (content == null) {
      return;
    }
    _applyPendingReplyToContent(content);
    await ref
        .read(chatSceneGatewayProvider(widget.session))
        .sendMessageContent(
          content,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
        );
    composerController.hidePanels();
    composerController.clearPendingReply();
    ref
        .read(chatSceneControllerProvider(widget.session).notifier)
        .restoreNormal();
  }

  Future<void> _handleDroppedFiles(
    List<ChatDroppedFileSelection> files,
    ChatComposerController composerController,
  ) async {
    if (files.isEmpty) {
      return;
    }
    try {
      for (final file in files) {
        final content = await ref
            .read(chatMediaActionServiceProvider)
            .buildDroppedFile(file);
        await _sendPickedContent(content, composerController);
      }
    } catch (_) {
      _showSendFailureFeedback();
    }
  }

  Future<void> _handleSendPressed(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) async {
    if (_isSubmittingComposer) {
      return;
    }
    final payload = composerController.buildSubmissionPayload();
    if (payload.text.isEmpty) {
      return;
    }

    final onSubmitText = widget.onSubmitText;
    if (onSubmitText != null &&
        payload.editMessageId?.trim().isNotEmpty != true) {
      onSubmitText(payload.text);
      composerController.markSubmitSucceeded();
      mentionsController.clear();
      ref
          .read(chatSceneControllerProvider(widget.session).notifier)
          .restoreNormal();
      return;
    }

    _setComposerSubmitting(true);
    try {
      final editMessageId = payload.editMessageId?.trim() ?? '';
      if (editMessageId.isEmpty) {
        final handledByTextSticker = await _textStickerConversion.tryHandle(
          text: payload.text,
          replyMessageId: payload.replyMessageId,
          conversationContext: widget.session,
        );
        if (handledByTextSticker) {
          composerController.markSubmitSucceeded();
          mentionsController.clear();
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
          return;
        }
      }

      final content = WKTextContent(payload.text);
      final mentionedUids = _normalizedMentionedUids(
        ref.read(chatMentionsControllerProvider(widget.session)).mentionedUids,
      );
      if (mentionedUids.isNotEmpty) {
        content.mentionInfo = WKMentionInfo()..uids = mentionedUids;
      }

      if (editMessageId.isNotEmpty) {
        final editableMessage = _findEditableMessage(
          editMessageId,
          payload.editMessageSeq,
        );
        if (editableMessage == null) {
          return;
        }
        await ref
            .read(chatSceneGatewayProvider(widget.session))
            .editMessage(editableMessage, content);
      } else {
        _applyPendingReplyToContent(content, payload: payload);

        await ref
            .read(chatSceneGatewayProvider(widget.session))
            .sendMessageContent(
              content,
              channelId: widget.session.channelId,
              channelType: widget.session.channelType,
            );
      }

      composerController.markSubmitSucceeded();
      mentionsController.clear();
      ref
          .read(chatSceneControllerProvider(widget.session).notifier)
          .restoreNormal();
    } catch (_) {
      _showSendFailureFeedback();
    } finally {
      _setComposerSubmitting(false);
    }
  }

  void _setComposerSubmitting(bool value) {
    if (_isSubmittingComposer == value) {
      return;
    }
    if (!mounted) {
      _isSubmittingComposer = value;
      return;
    }
    setState(() {
      _isSubmittingComposer = value;
    });
  }

  void _showSendFailureFeedback() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(_buildLiquidSnackBar(_sendFailureRetainedFeedback));
  }

  Future<void> _startVoiceRecording() async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    if (_isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      return;
    }
    final started = await voiceService.startRecording();
    if (!mounted) {
      return;
    }
    if (started) {
      return;
    }

    final state = voiceService.recordingStateListenable.value;
    final message = switch (state.phase) {
      ChatVoiceRecordingPhase.permissionDenied =>
        state.errorMessage?.trim().isNotEmpty == true
            ? state.errorMessage!.trim()
            : _voicePermissionDeniedFeedback,
      ChatVoiceRecordingPhase.sendFailed =>
        state.errorMessage?.trim().isNotEmpty == true
            ? state.errorMessage!.trim()
            : _voiceStartFailedFallback,
      _ => null,
    };
    if (message != null) {
      _showVoiceFeedback(message);
    }
  }

  Future<void> _finishVoiceRecording(
    ChatComposerController composerController, {
    required bool shouldSend,
  }) async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    final currentState = voiceService.recordingStateListenable.value;
    if (!_isVoiceSessionActive(currentState)) {
      // Failed starts already surfaced feedback in _startVoiceRecording.
      return;
    }
    final result = await voiceService.stopRecording(shouldSend: shouldSend);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ChatVoiceReadyResult():
        await _sendPickedContent(result.content, composerController);
        return;
      case ChatVoiceDiscardedResult():
        if (result.reason == ChatVoiceDiscardReason.tooShort) {
          _showVoiceFeedback(_voiceTooShortFeedback);
        } else if (result.reason == ChatVoiceDiscardReason.permissionDenied) {
          _showVoiceFeedback(_voicePermissionDeniedFeedback);
        }
        return;
      case ChatVoiceStopFailure():
        _showVoiceFeedback(
          result.message.trim().isNotEmpty
              ? result.message.trim()
              : _voiceStartFailedFallback,
        );
        return;
    }
  }

  Future<void> _cancelVoiceRecording() async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    if (!_isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      return;
    }
    await voiceService.cancelRecording();
  }

  void _showVoiceFeedback(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(_buildLiquidSnackBar(message.trim()));
  }

  bool _isVoiceSessionActive(ChatVoiceRecordingState state) {
    return state.phase == ChatVoiceRecordingPhase.recording ||
        state.phase == ChatVoiceRecordingPhase.cancelCandidate ||
        state.phase == ChatVoiceRecordingPhase.stopping;
  }

  void _applyPendingReplyToContent(
    WKMessageContent content, {
    ChatComposerSubmissionPayload? payload,
  }) {
    final replyPayload = payload ?? composerStatePayload;
    final replyReference = replyPayload.replyMessageId?.trim() ?? '';
    if (replyReference.isEmpty) {
      return;
    }
    final replyMessage = _findReplyMessage(replyReference);
    if (replyMessage != null) {
      content.reply = buildReplyForMessage(
        replyMessage,
        currentUid: WKIM.shared.options.uid ?? '',
      );
      return;
    }
    content.reply = WKReply()
      ..rootMid = replyReference
      ..messageId = replyReference
      ..payload = WKTextContent(
        replyPayload.replyPreview?.trim().isNotEmpty == true
            ? replyPayload.replyPreview!.trim()
            : _replyFallbackTitle,
      );
  }

  ChatComposerSubmissionPayload get composerStatePayload => ref
      .read(chatComposerProvider(widget.session).notifier)
      .buildSubmissionPayload();

  WKMsg? _findReplyMessage(String reference) {
    for (final item in ref.read(chatViewportProvider(widget.session)).items) {
      final message = item.message;
      if (message.messageID.trim() == reference ||
          message.clientMsgNO.trim() == reference ||
          item.identity == reference ||
          item.identity == 'mid:$reference' ||
          item.identity == 'cid:$reference') {
        return message;
      }
    }
    return null;
  }

  WKMsg? _findEditableMessage(String messageId, int? messageSeq) {
    final normalizedMessageId = messageId.trim();
    for (final item in ref.read(chatViewportProvider(widget.session)).items) {
      final message = item.message;
      if (message.messageID.trim() == normalizedMessageId) {
        return message;
      }
      if (messageSeq != null &&
          messageSeq > 0 &&
          message.messageSeq == messageSeq) {
        return message;
      }
    }
    return null;
  }

  List<String> _normalizedMentionedUids(List<String> mentionedUids) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final uid in mentionedUids) {
      final trimmed = uid.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  Widget _buildPanel(
    ChatComposerState composerState,
    List<ChatFunctionMenu> functionItems,
    WKChannel? channel,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    if (_robotGifResults.isNotEmpty) {
      return _buildRobotGifPanel(composerController);
    }

    if (composerState.showFlamePanel == true &&
        isChannelFlameEnabled(channel)) {
      return _buildFlamePanel(channel, composerController);
    }

    if (composerState.showRobotMenuPanel == true &&
        widget.robotMenus.isNotEmpty) {
      return _buildRobotMenuPanel(composerController);
    }

    if (composerState.showFunctionPanel == true) {
      return _buildFunctionPanel(functionItems);
    }

    if (composerState.showFacePanel == true) {
      return _buildExpressionPanel(
        composerState,
        composerController,
        mentionsController,
      );
    }

    return const SizedBox.shrink(key: ValueKey<String>('panel-none'));
  }

  Widget _buildExpressionPanel(
    ChatComposerState composerState,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final expressionRegistry = ref.read(chatExpressionRegistryProvider);
    return FutureBuilder<ChatExpressionRegistrySnapshot>(
      future: _expressionRegistryFuture ??= expressionRegistry.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'expression load error: ${snapshot.error}',
                key: const ValueKey<String>('chat-expression-panel-error'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        return ChatExpressionPanel(
          snapshot: snapshot.data!,
          activeCategoryId: composerState.activeExpressionCategoryId,
          gifResults: _panelGifResults,
          gifErrorText: _panelGifErrorText,
          onCategorySelected: (categoryId) {
            composerController.selectExpressionCategory(categoryId);
            if (categoryId != 'gif') {
              setState(() {
                _panelGifResults = const <ChatGifPanelResult>[];
                _panelGifErrorText = null;
              });
            }
          },
          onRecentSelected: (recent) => unawaited(
            _handleRecentSelection(
              composerController,
              mentionsController,
              expressionRegistry,
              recent,
            ),
          ),
          onEmojiSelected: (entry) => unawaited(
            _handlePanelEmojiTap(
              composerController,
              mentionsController,
              expressionRegistry,
              entry,
            ),
          ),
          onStickerSelected: (_, sticker) => unawaited(
            _handleStickerTap(composerController, expressionRegistry, sticker),
          ),
          onGifQueryChanged: (query) =>
              unawaited(_handlePanelGifQueryChanged(query, composerController)),
          onGifSelected: (result) => unawaited(
            _handlePanelGifTap(composerController, expressionRegistry, result),
          ),
          onBackspaceTap: () => _deletePreviousComposerCharacter(
            composerController,
            mentionsController,
          ),
        );
      },
    );
  }

  Future<void> _handleStickerTap(
    ChatComposerController composerController,
    ChatExpressionRegistry registry,
    ChatStickerDefinition sticker,
  ) async {
    final content = WKStickerContent(
      packId: sticker.packId,
      stickerId: sticker.stickerId,
      packVersion: 1,
      title: sticker.title,
      mimeType: sticker.mimeType,
      width: sticker.width,
      height: sticker.height,
      loopCount: sticker.loopCount,
      previewKey: sticker.previewKey,
      animationKey: sticker.animationKey,
      fallbackText: sticker.fallbackText,
    );
    await _sendPickedContent(content, composerController);
    await registry.rememberSticker(sticker);
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handlePanelGifTap(
    ChatComposerController composerController,
    ChatExpressionRegistry registry,
    ChatGifPanelResult result,
  ) async {
    final content = WKGifContent(width: result.width, height: result.height)
      ..url = result.url;
    await _sendPickedContent(content, composerController);
    await registry.rememberGif(
      title: result.title,
      url: result.url,
      width: result.width,
      height: result.height,
    );
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handlePanelEmojiTap(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
    ChatExpressionRegistry registry,
    AndroidEmojiEntry entry,
  ) async {
    _insertEmoji(entry.tag, composerController, mentionsController);
    await registry.rememberEmoji(entry);
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handleRecentSelection(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
    ChatExpressionRegistry registry,
    ChatExpressionRecentRecord recent,
  ) async {
    switch (recent.kind) {
      case ChatExpressionKind.emoji:
        _insertEmoji(recent.itemId, composerController, mentionsController);
        await registry.rememberRecent(recent);
        _refreshExpressionRegistry(registry);
        return;
      case ChatExpressionKind.sticker:
        await _handleStickerTap(
          composerController,
          registry,
          ChatStickerDefinition(
            packId: recent.categoryId.replaceFirst('sticker:', ''),
            stickerId: recent.itemId,
            title: recent.itemId,
            previewKey: recent.previewKey,
            animationKey: recent.animationKey,
            mimeType: 'image/webp',
            width: recent.width,
            height: recent.height,
            loopCount: 0,
            fallbackText: recent.displayText,
          ),
        );
        return;
      case ChatExpressionKind.gif:
        await _handlePanelGifTap(
          composerController,
          registry,
          ChatGifPanelResult(
            url: recent.gifUrl,
            width: recent.width,
            height: recent.height,
            title: recent.itemId,
          ),
        );
        return;
    }
  }

  Future<void> _handlePanelGifQueryChanged(
    String query,
    ChatComposerController composerController,
  ) async {
    composerController.updateExpressionSearchQuery(query);
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _panelGifResults = const <ChatGifPanelResult>[];
        _panelGifErrorText = null;
      });
      return;
    }

    try {
      final results = await ref
          .read(chatGifPanelServiceProvider)
          .search(normalizedQuery, session: widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _panelGifResults = results;
        _panelGifErrorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _panelGifResults = const <ChatGifPanelResult>[];
        _panelGifErrorText =
            '\u52a8\u56fe\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
      });
    }
  }

  void _refreshExpressionRegistry(ChatExpressionRegistry registry) {
    if (!mounted) {
      return;
    }
    setState(() {
      _expressionRegistryFuture = registry.load();
    });
  }

  Widget _buildRobotGifPanel(ChatComposerController composerController) {
    final tokens = LiquidGlassTokens.of(context);
    return Container(
      key: const ValueKey<String>('chat-robot-gif-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surfaceSolid,
        border: Border(top: BorderSide(color: tokens.border, width: 1)),
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: _robotGifResults.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final result = _robotGifResults[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey<String>('chat-robot-gif-item-$index'),
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  unawaited(_handleRobotGifTap(result, composerController)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.border),
                ),
                child: Center(
                  child: Text(
                    result.contentUrl?.trim().isNotEmpty == true
                        ? '\u52a8\u56fe'
                        : '...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRobotGifTap(
    RobotInlineQueryResult result,
    ChatComposerController composerController,
  ) async {
    final gifUrl = result.contentUrl?.trim() ?? '';
    if (gifUrl.isEmpty) {
      return;
    }
    final content = WKGifContent(
      width: _readRobotGifDimension(result.extraData['width']),
      height: _readRobotGifDimension(result.extraData['height']),
    )..url = gifUrl;
    await _sendPickedContent(content, composerController);
    _textController.clear();
    composerController.updateText('');
    _clearRobotInlineState();
  }

  Widget _buildRobotMenuPanel(ChatComposerController composerController) {
    final tokens = LiquidGlassTokens.of(context);
    return Container(
      key: const ValueKey<String>('panel-robot-menu'),
      width: double.infinity,
      color: tokens.surfaceSolid,
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: widget.robotMenus.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: tokens.border),
        itemBuilder: (context, index) {
          final menu = widget.robotMenus[index];
          return ListTile(
            key: ValueKey<String>(
              'chat-robot-menu-item-${menu.robotId}-${menu.cmd}',
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            title: Text(
              menu.remark.trim().isNotEmpty ? menu.remark.trim() : menu.cmd,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.text,
              ),
            ),
            subtitle: menu.remark.trim().isNotEmpty
                ? Text(
                    menu.cmd,
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  )
                : null,
            onTap: () =>
                unawaited(_handleRobotMenuTap(menu, composerController)),
          );
        },
      ),
    );
  }

  Future<void> _handleRobotMenuTap(
    RobotMenu menu,
    ChatComposerController composerController,
  ) async {
    final content = WKTextContent(menu.cmd)..robotID = menu.robotId;
    final entity = WKMsgEntity()
      ..offset = 0
      ..length = menu.cmd.length
      ..type = 'bot_command';
    content.entities = <WKMsgEntity>[entity];

    await ref
        .read(chatSceneGatewayProvider(widget.session))
        .sendMessageContent(
          content,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
          channelName: _channel?.channelName.trim().isNotEmpty == true
              ? _channel!.channelName.trim()
              : null,
        );
    composerController.hidePanels();
    ref
        .read(chatSceneControllerProvider(widget.session).notifier)
        .restoreNormal();
  }

  Widget _buildFlamePanel(
    WKChannel? channel,
    ChatComposerController composerController,
  ) {
    final tokens = LiquidGlassTokens.of(context);
    final flameSecond = channelFlameSecond(channel);
    final sliderValue =
        _flameSliderValue ?? sliderValueForFlameSecond(flameSecond);
    return Container(
      key: const ValueKey<String>('chat-flame-panel'),
      width: double.infinity,
      color: tokens.surfaceSolid,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    WKReferenceAssets.image(
                      WKReferenceAssets.flameSmall,
                      width: 16,
                      height: 16,
                      tint: tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        flameDescription(flameSecond),
                        key: const ValueKey<String>('chat-flame-description'),
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    inactiveTrackColor: tokens.textSecondary.withValues(
                      alpha: 0.2,
                    ),
                    activeTrackColor: WKColors.brand500,
                    thumbColor: WKColors.brand500,
                    overlayColor: WKColors.brand500.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    key: const ValueKey<String>('chat-flame-duration-slider'),
                    value: sliderValue,
                    min: 0,
                    max: (chatFlameSecondOptions.length - 1).toDouble(),
                    divisions: chatFlameSecondOptions.length - 1,
                    onChanged: (value) {
                      setState(() {
                        _flameSliderValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      final flameSecond = flameSecondForSliderValue(value);
                      unawaited(_updateFlameSecond(flameSecond));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: const ValueKey<String>('chat-flame-enabled-switch'),
            value: isChannelFlameEnabled(channel),
            onChanged: (value) =>
                unawaited(_updateFlameEnabled(value, composerController)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFlameEnabled(
    bool enabled,
    ChatComposerController composerController,
  ) async {
    try {
      if (widget.session.channelType == WKChannelType.personal) {
        await UserApi.instance.updateUserSetting(
          widget.session.channelId,
          'flame',
          enabled ? 1 : 0,
        );
      } else {
        await GroupApi.instance.updateGroupSetting(
          widget.session.channelId,
          'flame',
          enabled ? 1 : 0,
        );
      }

      final channel =
          _channel ??
          widget.channel ??
          WKChannel(widget.session.channelId, widget.session.channelType);
      applyChannelFlameSettings(
        channel,
        flame: enabled ? 1 : 0,
        flameSecond: channelFlameSecond(channel),
      );
      WKIM.shared.channelManager.addOrUpdateChannel(channel);
      if (!mounted) {
        return;
      }
      setState(() {
        _channel = channel;
        _flameSliderValue = null;
      });
      if (!enabled) {
        composerController.hidePanels();
      }
    } catch (error) {
      _showFlameFeedback(error);
    }
  }

  Future<void> _updateFlameSecond(int flameSecond) async {
    try {
      if (widget.session.channelType == WKChannelType.personal) {
        await UserApi.instance.updateUserSetting(
          widget.session.channelId,
          'flame_second',
          flameSecond,
        );
      } else {
        await GroupApi.instance.updateGroupSetting(
          widget.session.channelId,
          'flame_second',
          flameSecond,
        );
      }

      final channel =
          _channel ??
          widget.channel ??
          WKChannel(widget.session.channelId, widget.session.channelType);
      applyChannelFlameSettings(channel, flame: 1, flameSecond: flameSecond);
      WKIM.shared.channelManager.addOrUpdateChannel(channel);
      if (!mounted) {
        return;
      }
      setState(() {
        _channel = channel;
        _flameSliderValue = null;
      });
    } catch (error) {
      _showFlameFeedback(error);
    }
  }

  void _showFlameFeedback(Object error) {
    if (!mounted) {
      return;
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(_buildLiquidSnackBar(message));
  }

  Widget _buildFunctionPanel(List<ChatFunctionMenu> items) {
    final tokens = LiquidGlassTokens.of(context);
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    return Container(
      key: const ValueKey<String>('panel-more'),
      width: double.infinity,
      color: tokens.surfaceSolid,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in items)
            ComposerFunctionItem(
              key: ValueKey<String>('chat-function-${item.sid}'),
              sid: item.sid,
              asset: item.icon ?? '',
              label: item.text?.trim().isNotEmpty == true
                  ? item.text!.trim()
                  : item.sid,
              textColor: tokens.text,
              onTap: () {
                final onClick = item.onClick;
                if (onClick != null) {
                  onClick(item.sid);
                  return;
                }
                unawaited(_handleFunctionTap(item.sid, composerController));
              },
            ),
        ],
      ),
    );
  }
}

int _readRobotGifDimension(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw) ?? 0;
  }
  return 0;
}

class _RobotInlineDirective {
  const _RobotInlineDirective({
    required this.username,
    required this.query,
    required this.hasSeparator,
  });

  final String username;
  final String query;
  final bool hasSeparator;

  bool get isGifQuery => username == 'gif';

  static _RobotInlineDirective? parse(String rawText) {
    final text = rawText.trimLeft();
    if (!text.startsWith('@')) {
      return null;
    }

    final firstSpaceIndex = text.indexOf(' ');
    final usernamePart = firstSpaceIndex >= 0
        ? text.substring(1, firstSpaceIndex)
        : text.substring(1);
    final username = usernamePart.trim().toLowerCase();
    if (username.isEmpty) {
      return null;
    }

    final query = firstSpaceIndex >= 0
        ? text.substring(firstSpaceIndex + 1).replaceAll(' ', '')
        : '';
    return _RobotInlineDirective(
      username: username,
      query: query,
      hasSeparator: firstSpaceIndex >= 0,
    );
  }
}
