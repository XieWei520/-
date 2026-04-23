import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'chat_keyword_search_controller.dart';
import 'search_providers.dart';

const Object _errorSentinel = Object();
const int _defaultPageSize = 20;

@immutable
class ChatMemberSearchState {
  const ChatMemberSearchState({
    this.members = const <SearchMemberHit>[],
    this.selectedMember,
    this.results = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoadingMembers = false,
    this.isLoadingResults = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final List<SearchMemberHit> members;
  final SearchMemberHit? selectedMember;
  final List<SearchMessageHit> results;
  final int page;
  final bool isLoadingMembers;
  final bool isLoadingResults;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  bool get showingResults => selectedMember != null;

  ChatMemberSearchState copyWith({
    List<SearchMemberHit>? members,
    Object? selectedMember = _memberSentinel,
    List<SearchMessageHit>? results,
    int? page,
    bool? isLoadingMembers,
    bool? isLoadingResults,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatMemberSearchState(
      members: members ?? this.members,
      selectedMember: identical(selectedMember, _memberSentinel)
          ? this.selectedMember
          : selectedMember as SearchMemberHit?,
      results: results ?? this.results,
      page: page ?? this.page,
      isLoadingMembers: isLoadingMembers ?? this.isLoadingMembers,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _errorSentinel)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }
}

const Object _memberSentinel = Object();

final chatMemberSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMemberSearchController, ChatMemberSearchState, ChatSearchTarget>((
      ref,
      target,
    ) {
      final controller = ChatMemberSearchController(
        channelId: target.channelId,
        channelType: target.channelType,
        repository: ref.read(searchRepositoryProvider),
      );
      unawaited(controller.loadMembers());
      return controller;
    });

class ChatMemberSearchController extends StateNotifier<ChatMemberSearchState> {
  ChatMemberSearchController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatMemberSearchState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;
  int _requestVersion = 0;

  Future<void> loadMembers() async {
    state = state.copyWith(
      isLoadingMembers: true,
      error: null,
      loadMoreError: null,
    );

    try {
      final members = await _repository.loadMembers(
        channelId: channelId,
        channelType: channelType,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        members: members,
        isLoadingMembers: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoadingMembers: false,
        error: error.toString(),
      );
    }
  }

  Future<void> openMember(SearchMemberHit member) async {
    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      selectedMember: member,
      results: const <SearchMessageHit>[],
      page: 1,
      isLoadingResults: true,
      isLoadingMore: false,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );

    try {
      final results = await _repository.searchMessagesByMember(
        channelId: channelId,
        channelType: channelType,
        memberUid: member.uid,
        keyword: '',
        page: 1,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        results: results,
        page: 2,
        isLoadingResults: false,
        hasMore: results.length >= _defaultPageSize,
        loadMoreError: null,
      );
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        isLoadingResults: false,
        hasMore: false,
        error: error.toString(),
        loadMoreError: null,
      );
    }
  }

  Future<void> loadMoreResults({bool isRetry = false}) async {
    final member = state.selectedMember;
    if (member == null ||
        state.isLoadingResults ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    if (!isRetry && state.loadMoreError != null) {
      return;
    }

    final requestVersion = _requestVersion;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final results = await _repository.searchMessagesByMember(
        channelId: channelId,
        channelType: channelType,
        memberUid: member.uid,
        keyword: '',
        page: state.page,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        results: <SearchMessageHit>[...state.results, ...results],
        page: state.page + 1,
        isLoadingMore: false,
        hasMore: results.length >= _defaultPageSize,
        loadMoreError: null,
      );
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: error.toString(),
      );
    }
  }

  Future<void> retryResults() async {
    final member = state.selectedMember;
    if (member == null) {
      await loadMembers();
      return;
    }
    await openMember(member);
  }

  void backToMembers() {
    _requestVersion += 1;
    state = state.copyWith(
      selectedMember: null,
      results: const <SearchMessageHit>[],
      page: 1,
      isLoadingResults: false,
      isLoadingMore: false,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );
  }
}
