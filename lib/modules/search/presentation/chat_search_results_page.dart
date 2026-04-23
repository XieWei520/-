import 'package:flutter/material.dart';

import '../domain/search_models.dart';
import 'widgets/search_message_tile.dart';

class ChatSearchResultsPage extends StatelessWidget {
  const ChatSearchResultsPage({
    super.key,
    required this.items,
    required this.onTap,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onLoadMore,
    this.onRetryLoadMore,
  });

  final List<SearchMessageHit> items;
  final ValueChanged<SearchMessageHit> onTap;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          onLoadMore?.call();
        }
        return false;
      },
      child: ListView.builder(
        key: const ValueKey<String>('chat-search-results-list'),
        itemCount:
            items.length + ((isLoadingMore || loadMoreError != null) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            if (isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Load more failed'),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey<String>(
                        'chat-search-load-more-retry',
                      ),
                      onPressed: onRetryLoadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final hit = items[index];
          return SearchMessageTile(hit: hit, onTap: () => onTap(hit));
        },
      ),
    );
  }
}
