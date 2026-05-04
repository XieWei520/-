import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wukong_base/views/mention_suggestion.dart';

typedef MentionSuggestionLoader = Future<List<MentionSuggestion>> Function();

@immutable
class MentionApplyResult {
  MentionApplyResult({
    required this.text,
    required this.cursorOffset,
    required List<String> mentionedUids,
  }) : mentionedUids = List<String>.unmodifiable(mentionedUids);

  final String text;
  final int cursorOffset;
  final List<String> mentionedUids;
}

@immutable
class ChatMentionsState {
  ChatMentionsState({
    this.isActive = false,
    this.query = '',
    this.triggerOffset = -1,
    List<MentionSuggestion> suggestions = const <MentionSuggestion>[],
    List<String> mentionedUids = const <String>[],
  }) : suggestions = List<MentionSuggestion>.unmodifiable(suggestions),
       mentionedUids = List<String>.unmodifiable(mentionedUids);

  final bool isActive;
  final String query;
  final int triggerOffset;
  final List<MentionSuggestion> suggestions;
  final List<String> mentionedUids;

  ChatMentionsState copyWith({
    bool? isActive,
    String? query,
    int? triggerOffset,
    List<MentionSuggestion>? suggestions,
    List<String>? mentionedUids,
  }) {
    return ChatMentionsState(
      isActive: isActive ?? this.isActive,
      query: query ?? this.query,
      triggerOffset: triggerOffset ?? this.triggerOffset,
      suggestions: suggestions ?? this.suggestions,
      mentionedUids: mentionedUids ?? this.mentionedUids,
    );
  }
}

class ChatMentionsController extends StateNotifier<ChatMentionsState> {
  ChatMentionsController({required MentionSuggestionLoader loadSuggestions})
    : _loadSuggestions = loadSuggestions,
      super(ChatMentionsState());

  final MentionSuggestionLoader _loadSuggestions;
  int _requestEpoch = 0;

  Future<void> updateFromText(String text, {required int cursorOffset}) async {
    final requestEpoch = ++_requestEpoch;

    if (cursorOffset <= 0 || cursorOffset > text.length) {
      _closeSuggestions();
      return;
    }

    final triggerOffset = text.lastIndexOf('@', cursorOffset - 1);
    if (triggerOffset == -1) {
      _closeSuggestions();
      return;
    }

    final query = text.substring(triggerOffset + 1, cursorOffset);
    if (_containsMentionTerminator(query)) {
      _closeSuggestions();
      return;
    }

    final allSuggestions = await _loadSuggestions();
    if (requestEpoch != _requestEpoch) {
      return;
    }

    final filtered = allSuggestions.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(query.toLowerCase());
    }).toList(growable: false);

    state = state.copyWith(
      isActive: true,
      query: query,
      triggerOffset: triggerOffset,
      suggestions: filtered,
    );
  }

  MentionApplyResult applySelection(
    String text, {
    required int cursorOffset,
    MentionSuggestion? suggestion,
  }) {
    final selectedSuggestion = suggestion ?? state.suggestions.first;
    final prefix = text.substring(0, state.triggerOffset);
    final suffix = text.substring(cursorOffset);
    final inserted = '@${selectedSuggestion.name} ';
    final nextText = '$prefix$inserted$suffix';
    final nextMentionedUids = <String>[
      ...state.mentionedUids,
      selectedSuggestion.id,
    ];

    state = state.copyWith(
      isActive: false,
      query: '',
      triggerOffset: -1,
      suggestions: const <MentionSuggestion>[],
      mentionedUids: nextMentionedUids,
    );

    return MentionApplyResult(
      text: nextText,
      cursorOffset: prefix.length + inserted.length,
      mentionedUids: nextMentionedUids,
    );
  }

  void clear() {
    _requestEpoch++;
    state = ChatMentionsState();
  }

  void _closeSuggestions() {
    state = state.copyWith(
      isActive: false,
      query: '',
      triggerOffset: -1,
      suggestions: const <MentionSuggestion>[],
    );
  }

  bool _containsMentionTerminator(String query) {
    return query.contains(RegExp(r'\s'));
  }
}
