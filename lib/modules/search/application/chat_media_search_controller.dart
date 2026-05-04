import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'search_providers.dart';

@immutable
class ChatMediaSearchState {
  const ChatMediaSearchState({
    this.items = const <SearchMediaItem>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final List<SearchMediaItem> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  ChatMediaSearchState copyWith({
    List<SearchMediaItem>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatMediaSearchState(
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

final chatMediaSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<
      ChatMediaSearchController,
      ChatMediaSearchState,
      ({String channelId, int channelType, SearchCollectionScope scope})
    >((ref, target) {
      final controller = ChatMediaSearchController(
        channelId: target.channelId,
        channelType: target.channelType,
        scope: target.scope,
        repository: ref.read(searchRepositoryProvider),
      );
      unawaited(controller.refresh());
      return controller;
    });

class ChatMediaSearchController extends StateNotifier<ChatMediaSearchState> {
  ChatMediaSearchController({
    required this.channelId,
    required this.channelType,
    required this.scope,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatMediaSearchState());

  final String channelId;
  final int channelType;
  final SearchCollectionScope scope;
  final SearchRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(
      items: const <SearchMediaItem>[],
      page: 1,
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );

    try {
      final items = await _repository.searchCollection(
        channelId: channelId,
        channelType: channelType,
        scope: scope,
        page: 1,
        limit: _defaultPageSize,
      );
      if (!mounted) {
        return;
      }
      state = ChatMediaSearchState(
        items: items,
        page: 2,
        isLoading: false,
        hasMore: items.length >= _defaultPageSize,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = ChatMediaSearchState(
        isLoading: false,
        hasMore: false,
        error: error.toString(),
      );
    }
  }

  Future<void> loadMore({bool isRetry = false}) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    if (!isRetry && state.loadMoreError != null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final items = await _repository.searchCollection(
        channelId: channelId,
        channelType: channelType,
        scope: scope,
        page: state.page,
        limit: _defaultPageSize,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: <SearchMediaItem>[...state.items, ...items],
        page: state.page + 1,
        isLoadingMore: false,
        hasMore: items.length >= _defaultPageSize,
        loadMoreError: null,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: error.toString(),
      );
    }
  }
}
