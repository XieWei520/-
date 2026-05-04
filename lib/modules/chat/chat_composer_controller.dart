import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wukong_base/msg/draft_manager.dart';

@immutable
class ChatComposerSubmissionPayload {
  const ChatComposerSubmissionPayload({
    required this.text,
    this.replyMessageId,
    this.replyPreview,
    this.editMessageId,
    this.editMessageSeq,
    this.editPreview,
  });

  final String text;
  final String? replyMessageId;
  final String? replyPreview;
  final String? editMessageId;
  final int? editMessageSeq;
  final String? editPreview;
}

@immutable
class ChatComposerState {
  const ChatComposerState({
    this.text = '',
    this.pendingReplyMessageId,
    this.pendingReplyPreview,
    this.pendingEditMessageId,
    this.pendingEditMessageSeq,
    this.pendingEditPreview,
    this.showVoiceInput = false,
    this.showFacePanel = false,
    this.showFunctionPanel = false,
    this.showFlamePanel = false,
    this.showRobotMenuPanel = false,
    this.activeExpressionCategoryId = 'emoji:0',
    this.expressionSearchQuery = '',
  });

  final String text;
  final String? pendingReplyMessageId;
  final String? pendingReplyPreview;
  final String? pendingEditMessageId;
  final int? pendingEditMessageSeq;
  final String? pendingEditPreview;
  final bool showVoiceInput;
  final bool showFacePanel;
  final bool showFunctionPanel;
  final bool showFlamePanel;
  final bool showRobotMenuPanel;
  final String activeExpressionCategoryId;
  final String expressionSearchQuery;

  ChatComposerState copyWith({
    String? text,
    String? pendingReplyMessageId,
    bool clearReply = false,
    String? pendingReplyPreview,
    String? pendingEditMessageId,
    int? pendingEditMessageSeq,
    String? pendingEditPreview,
    bool clearEdit = false,
    bool? showVoiceInput,
    bool? showFacePanel,
    bool? showFunctionPanel,
    bool? showFlamePanel,
    bool? showRobotMenuPanel,
    String? activeExpressionCategoryId,
    String? expressionSearchQuery,
  }) {
    return ChatComposerState(
      text: text ?? this.text,
      pendingReplyMessageId: clearReply
          ? null
          : (pendingReplyMessageId ?? this.pendingReplyMessageId),
      pendingReplyPreview: clearReply
          ? null
          : (pendingReplyPreview ?? this.pendingReplyPreview),
      pendingEditMessageId: clearEdit
          ? null
          : (pendingEditMessageId ?? this.pendingEditMessageId),
      pendingEditMessageSeq: clearEdit
          ? null
          : (pendingEditMessageSeq ?? this.pendingEditMessageSeq),
      pendingEditPreview: clearEdit
          ? null
          : (pendingEditPreview ?? this.pendingEditPreview),
      showVoiceInput: showVoiceInput ?? this.showVoiceInput,
      showFacePanel: showFacePanel ?? this.showFacePanel,
      showFunctionPanel: showFunctionPanel ?? this.showFunctionPanel,
      showFlamePanel: showFlamePanel ?? this.showFlamePanel,
      showRobotMenuPanel: showRobotMenuPanel ?? this.showRobotMenuPanel,
      activeExpressionCategoryId:
          activeExpressionCategoryId ?? this.activeExpressionCategoryId,
      expressionSearchQuery:
          expressionSearchQuery ?? this.expressionSearchQuery,
    );
  }
}

class ChatComposerController extends StateNotifier<ChatComposerState> {
  static const Duration _saveDebounce = Duration(milliseconds: 300);

  ChatComposerController({
    required this.channelId,
    required this.channelType,
    DraftStore? draftStore,
  }) : _draftStore = draftStore ?? DraftManager(),
       super(const ChatComposerState());

  final String channelId;
  final int channelType;
  final DraftStore _draftStore;
  Timer? _saveTimer;
  bool _isPersisting = false;
  bool _isDisposed = false;
  bool _persistQueued = false;
  ChatComposerState? _disposedState;
  String _lastSavedSignature = '';

  Future<void> initialize() async {
    final draft = _draftStore.getDraft(channelId, channelType);
    if (draft == null) {
      return;
    }

    state = ChatComposerState(
      text: draft.content,
      pendingReplyMessageId: draft.replyMsgId,
      pendingReplyPreview: draft.replyContent,
    );
    _lastSavedSignature = draft.contentSignature;
  }

  bool get isVoiceInputVisible => state.showVoiceInput;

  void updateText(String text) {
    state = state.copyWith(text: text);
    _scheduleSave();
  }

  void setPendingReply({required String messageId, String? preview}) {
    state = state.copyWith(
      pendingReplyMessageId: messageId,
      pendingReplyPreview: preview,
      clearEdit: true,
    );
    _scheduleSave();
  }

  void clearPendingReply() {
    state = state.copyWith(clearReply: true);
    _scheduleSave();
  }

  void setPendingEdit({
    required String messageId,
    required int messageSeq,
    required String initialText,
  }) {
    state = state.copyWith(
      text: initialText,
      clearReply: true,
      pendingEditMessageId: messageId,
      pendingEditMessageSeq: messageSeq,
      pendingEditPreview: initialText,
      showVoiceInput: false,
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
    );
  }

  void clearPendingEdit({bool clearText = false}) {
    state = state.copyWith(text: clearText ? '' : state.text, clearEdit: true);
  }

  void toggleFacePanel({String? initialCategoryId}) {
    state = state.copyWith(
      showVoiceInput: false,
      showFacePanel: !state.showFacePanel,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
      activeExpressionCategoryId:
          initialCategoryId ?? state.activeExpressionCategoryId,
    );
  }

  void selectExpressionCategory(String categoryId) {
    state = state.copyWith(
      showFacePanel: true,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
      activeExpressionCategoryId: categoryId,
      expressionSearchQuery: categoryId == 'gif'
          ? state.expressionSearchQuery
          : '',
    );
  }

  void updateExpressionSearchQuery(String query) {
    state = state.copyWith(expressionSearchQuery: query);
  }

  void toggleFunctionPanel() {
    state = state.copyWith(
      showVoiceInput: false,
      showFacePanel: false,
      showFunctionPanel: !state.showFunctionPanel,
      showFlamePanel: false,
      showRobotMenuPanel: false,
    );
  }

  void toggleVoiceInput() {
    state = state.copyWith(
      showVoiceInput: !state.showVoiceInput,
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
    );
  }

  void toggleFlamePanel() {
    state = state.copyWith(
      showVoiceInput: false,
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: !state.showFlamePanel,
      showRobotMenuPanel: false,
    );
  }

  void toggleRobotMenuPanel() {
    state = state.copyWith(
      showVoiceInput: false,
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: !state.showRobotMenuPanel,
    );
  }

  void hidePanels() {
    if (!state.showFacePanel &&
        !state.showFunctionPanel &&
        !state.showFlamePanel &&
        !state.showRobotMenuPanel) {
      return;
    }
    state = state.copyWith(
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
    );
  }

  ChatComposerSubmissionPayload buildSubmissionPayload() {
    return ChatComposerSubmissionPayload(
      text: state.text.trim(),
      replyMessageId: state.pendingReplyMessageId,
      replyPreview: state.pendingReplyPreview,
      editMessageId: state.pendingEditMessageId,
      editMessageSeq: state.pendingEditMessageSeq,
      editPreview: state.pendingEditPreview,
    );
  }

  void markSubmitSucceeded() {
    state = state.copyWith(
      text: '',
      clearReply: true,
      clearEdit: true,
      showVoiceInput: false,
      showFacePanel: false,
      showFunctionPanel: false,
      showFlamePanel: false,
      showRobotMenuPanel: false,
      expressionSearchQuery: '',
    );
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_isDisposed) {
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      unawaited(_persist());
    });
  }

  void _scheduleRetry() {
    if (_isDisposed || (_saveTimer?.isActive ?? false)) {
      return;
    }

    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    if (_isPersisting) {
      _persistQueued = true;
      return;
    }

    _isPersisting = true;
    try {
      while (true) {
        _persistQueued = false;
        final draftState = _persistableState;
        final signature = _signatureFor(draftState);
        if (signature == _lastSavedSignature) {
          if (!_persistQueued) {
            return;
          }
          continue;
        }

        var saveSucceeded = false;
        try {
          await _draftStore.saveDraft(
            channelId: channelId,
            channelType: channelType,
            content: draftState.text,
            replyMsgId: draftState.pendingReplyMessageId,
            replyContent: draftState.pendingReplyPreview,
          );
          _lastSavedSignature = signature;
          saveSucceeded = true;
        } catch (_) {
          // Keep the last successful signature so a later change or retry can persist.
        }

        final currentSignature = _stateSignature;
        if (saveSucceeded) {
          if (_persistQueued || currentSignature != _lastSavedSignature) {
            continue;
          }
          return;
        }

        if (_persistQueued || currentSignature != signature) {
          continue;
        }
        _scheduleRetry();
        return;
      }
    } finally {
      _isPersisting = false;
      if (_persistQueued && _stateSignature != _lastSavedSignature) {
        _persistQueued = false;
        unawaited(_persist());
      }
    }
  }

  String get _stateSignature => _signatureFor(_persistableState);

  ChatComposerState get _persistableState => _disposedState ?? state;

  String _signatureFor(ChatComposerState composerState) =>
      draftContentSignature(
        content: composerState.text,
        replyMsgId: composerState.pendingReplyMessageId,
        replyContent: composerState.pendingReplyPreview,
      );

  @override
  void dispose() {
    _isDisposed = true;
    _disposedState = state;
    final hasPendingSave =
        (_saveTimer?.isActive ?? false) ||
        _stateSignature != _lastSavedSignature;
    _saveTimer?.cancel();
    _saveTimer = null;
    if (hasPendingSave) {
      _persistQueued = true;
      unawaited(_persist());
    }
    super.dispose();
  }
}
