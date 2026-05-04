import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'chat_search_results_page.dart';
import 'search_chat_navigation.dart';

class GlobalSearchChannelResultsPage extends ConsumerStatefulWidget {
  const GlobalSearchChannelResultsPage({
    super.key,
    required this.channelId,
    required this.channelType,
    required this.keyword,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String keyword;
  final String? channelName;

  @override
  ConsumerState<GlobalSearchChannelResultsPage> createState() =>
      _GlobalSearchChannelResultsPageState();
}

class _GlobalSearchChannelResultsPageState
    extends ConsumerState<GlobalSearchChannelResultsPage> {
  static const int _pageSize = 100;

  List<SearchMessageHit> _items = const <SearchMessageHit>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadResults());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>(
                'global-search-channel-results-retry',
              ),
              onPressed: _loadResults,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }
    return ChatSearchResultsPage(items: _items, onTap: _openMessageHit);
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repository = ref.read(searchRepositoryProvider);
    final allItems = <SearchMessageHit>[];
    var page = 1;

    try {
      while (true) {
        final pageItems = await repository.searchMessages(
          channelId: widget.channelId,
          channelType: widget.channelType,
          keyword: widget.keyword,
          page: page,
          limit: _pageSize,
        );
        allItems.addAll(pageItems);
        if (pageItems.length < _pageSize) {
          break;
        }
        page += 1;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _items = allItems.toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openMessageHit(SearchMessageHit hit) async {
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      hit,
      highlightKeyword: widget.keyword,
      source: 'global-search-channel-results',
    );
    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: widget.channelName,
    );
  }

  String get _title {
    final name = widget.channelName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return widget.channelId;
  }
}
