import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'search_providers.dart';

@immutable
class ChatSearchTarget {
  const ChatSearchTarget({required this.channelId, required this.channelType});

  final String channelId;
  final int channelType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChatSearchTarget &&
        other.channelId == channelId &&
        other.channelType == channelType;
  }

  @override
  int get hashCode => Object.hash(channelId, channelType);
}

@immutable
class ChatKeywordSearchState {
  const ChatKeywordSearchState({
    this.keyword = '',
    this.items = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final List<SearchMessageHit> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  bool get hasKeyword => keyword.trim().isNotEmpty;

  ChatKeywordSearchState copyWith({
    String? keyword,
    List<SearchMessageHit>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatKeywordSearchState(
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
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

const Object _errorSentinel = Object();
const int _defaultPageSize = 20;

final chatKeywordSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<
      ChatKeywordSearchController,
      ChatKeywordSearchState,
      ChatSearchTarget
    >((ref, target) {
      return ChatKeywordSearchController(
        channelId: target.channelId,
        channelType: target.channelType,
        repository: ref.watch(searchRepositoryProvider),
      );
    });

class ChatKeywordSearchController
    extends StateNotifier<ChatKeywordSearchState> {
  ChatKeywordSearchController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
    Duration debounce = const Duration(milliseconds: 250),
  }) : _repository = repository,
       _debounceDuration = debounce,
       super(const ChatKeywordSearchState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  int _requestVersion = 0;

  void updateKeyword(String value) {
    _debounceTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _requestVersion += 1;
      state = ChatKeywordSearchState(keyword: value);
      return;
    }

    state = state.copyWith(
      keyword: value,
      items: const <SearchMessageHit>[],
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
      final items = await _repository.searchMessages(
        channelId: channelId,
        channelType: channelType,
        keyword: trimmedKeyword,
        page: state.page,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        items: <SearchMessageHit>[...state.items, ...items],
        page: state.page + 1,
        isLoadingMore: false,
        hasMore: items.length >= _defaultPageSize,
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
    try {
      final items = await _repository.searchMessages(
        channelId: channelId,
        channelType: channelType,
        keyword: keyword,
        page: 1,
        limit: _defaultPageSize,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = ChatKeywordSearchState(
        keyword: displayKeyword,
        items: items,
        page: 2,
        isLoading: false,
        hasMore: items.length >= _defaultPageSize,
      );
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      state = ChatKeywordSearchState(
        keyword: displayKeyword,
        items: const <SearchMessageHit>[],
        page: 1,
        isLoading: false,
        hasMore: false,
        error: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
