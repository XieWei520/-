import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../service/api/search_api.dart';
import '../domain/search_models.dart';
import '../domain/search_repository.dart';

const Object _errorSentinel = Object();
const int _defaultPageSize = 20;

@immutable
class GlobalSearchState {
  const GlobalSearchState({
    this.keyword = '',
    this.users = const <SearchMemberHit>[],
    this.groups = const <SearchMessageHit>[],
    this.messages = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final List<SearchMemberHit> users;
  final List<SearchMessageHit> groups;
  final List<SearchMessageHit> messages;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  bool get hasKeyword => keyword.trim().isNotEmpty;

  GlobalSearchState copyWith({
    String? keyword,
    List<SearchMemberHit>? users,
    List<SearchMessageHit>? groups,
    List<SearchMessageHit>? messages,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return GlobalSearchState(
      keyword: keyword ?? this.keyword,
      users: users ?? this.users,
      groups: groups ?? this.groups,
      messages: messages ?? this.messages,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _errorSentinel)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }
}

class GlobalSearchController extends StateNotifier<GlobalSearchState> {
  GlobalSearchController({
    SearchRepository? repository,
    SearchApi? api,
    Duration debounce = const Duration(milliseconds: 250),
  }) : _repository = repository,
       _api = api ?? SearchApi.instance,
       _debounceDuration = debounce,
       super(const GlobalSearchState());

  final SearchRepository? _repository;
  final SearchApi _api;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  int _requestVersion = 0;

  void updateKeyword(String value) {
    _debounceTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _requestVersion += 1;
      state = GlobalSearchState(keyword: value);
      return;
    }

    if (_repository == null) {
      throw StateError(
        'GlobalSearchController requires a SearchRepository for paged search.',
      );
    }

    state = state.copyWith(
      keyword: value,
      users: const <SearchMemberHit>[],
      groups: const <SearchMessageHit>[],
      messages: const <SearchMessageHit>[],
      page: 1,
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );

    final requestVersion = ++_requestVersion;
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(
        _loadFirstPage(
          keyword: trimmed,
          displayKeyword: value,
          requestVersion: requestVersion,
        ),
      );
    });
  }

  Future<void> loadMore({bool isRetry = false}) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError(
        'GlobalSearchController requires a SearchRepository for paged search.',
      );
    }

    final trimmedKeyword = state.keyword.trim();
    if (trimmedKeyword.isEmpty ||
        state.isLoading ||
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
      final snapshot = await repository.searchGlobal(
        keyword: trimmedKeyword,
        page: state.page,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        messages: <SearchMessageHit>[...state.messages, ...snapshot.messages],
        page: state.page + 1,
        isLoadingMore: false,
        hasMore: snapshot.messages.length >= _defaultPageSize,
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

  void retry() {
    updateKeyword(state.keyword);
  }

  Future<void> _loadFirstPage({
    required String keyword,
    required String displayKeyword,
    required int requestVersion,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    try {
      final snapshot = await repository.searchGlobal(
        keyword: keyword,
        page: 1,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = GlobalSearchState(
        keyword: displayKeyword,
        users: snapshot.users,
        groups: snapshot.groups,
        messages: snapshot.messages,
        page: 2,
        isLoading: false,
        hasMore: snapshot.messages.length >= _defaultPageSize,
      );
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = GlobalSearchState(
        keyword: displayKeyword,
        users: const <SearchMemberHit>[],
        groups: const <SearchMessageHit>[],
        messages: const <SearchMessageHit>[],
        page: 1,
        isLoading: false,
        hasMore: false,
        error: error.toString(),
      );
    }
  }

  // Backward-compatible path while presentation migrates to Riverpod state.
  Future<Map<String, dynamic>> search(String keyword) async {
    final repository = _repository;
    if (repository == null) {
      return _api.globalSearch(keyword);
    }
    final snapshot = await repository.searchGlobal(
      keyword: keyword,
      page: 1,
      limit: _defaultPageSize,
    );
    return <String, dynamic>{
      'users': snapshot.users.map(_memberToJson).toList(growable: false),
      'groups': snapshot.groups.map(_groupToJson).toList(growable: false),
      'messages': snapshot.messages.map(_messageToJson).toList(growable: false),
    };
  }

  Map<String, dynamic> _memberToJson(SearchMemberHit member) {
    return <String, dynamic>{
      'uid': member.uid,
      'name': member.displayName,
      'avatar': member.avatarUrl ?? '',
    };
  }

  Map<String, dynamic> _groupToJson(SearchMessageHit group) {
    return <String, dynamic>{
      'group_no': group.channelId,
      'name': group.channelName ?? group.fromName,
      'remark': group.previewText,
      'channel_id': group.channelId,
      'channel_type': group.channelType,
    };
  }

  Map<String, dynamic> _messageToJson(SearchMessageHit message) {
    return <String, dynamic>{
      'channel_id': message.channelId,
      'channel_type': message.channelType,
      'message_seq': message.messageSeq,
      'order_seq': message.orderSeq,
      'timestamp': message.timestamp,
      'content_type': message.contentType,
      'from_uid': message.fromUid,
      'from_name': message.fromName,
      'channel_name': message.channelName,
      'message_id': message.messageId,
      'client_msg_no': message.clientMsgNo,
      'searchable_word': message.previewText,
      'content': message.previewText,
    };
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
