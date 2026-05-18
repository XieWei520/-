import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../service/api/collection_api.dart';
import '../../../wukong_base/endpoint/endpoint_manager.dart';
import '../../../wukong_base/endpoint/menu/endpoint_menu.dart';
import '../../../wukong_base/views/image_viewer.dart';
import '../../../wukong_scan/scan_qr_code_bridge.dart';
import '../application/chat_media_search_controller.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'chat_search_image_forward_page.dart';
import 'search_chat_navigation.dart';
import 'widgets/search_collection_section.dart';

class ChatSearchCollectionPage extends ConsumerWidget {
  const ChatSearchCollectionPage({
    super.key,
    required this.channelId,
    required this.channelType,
    required this.scope,
    this.channelName,
    this.onFavoriteItem,
    this.onForwardItem,
    this.onShowItemInChat,
  });

  final String channelId;
  final int channelType;
  final SearchCollectionScope scope;
  final String? channelName;
  final Future<void> Function(SearchMediaItem item)? onFavoriteItem;
  final Future<void> Function(SearchMediaItem item)? onForwardItem;
  final Future<void> Function(SearchMediaItem item)? onShowItemInChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = (
      channelId: channelId,
      channelType: channelType,
      scope: scope,
    );
    final state = ref.watch(chatMediaSearchControllerProvider(target));
    final controller = ref.read(
      chatMediaSearchControllerProvider(target).notifier,
    );

    final title = switch (scope) {
      SearchCollectionScope.image => '图片',
      SearchCollectionScope.file => '文件',
      SearchCollectionScope.link => '链接',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _buildBody(context, ref, state, controller)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ChatMediaSearchState state,
    ChatMediaSearchController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          controller.loadMore();
        }
        return false;
      },
      child: scope == SearchCollectionScope.image
          ? _buildImageCollection(context, ref, state, controller)
          : ListView(
              children: [
                ...groupCollectionItems(state.items).entries.map(
                  (entry) => SearchCollectionSection(
                    sectionKey: entry.key,
                    items: entry.value,
                    onTapItem: (item) =>
                        _handleTap(context, ref, state.items, item),
                  ),
                ),
                _buildLoadMoreFooter(state, controller),
              ],
            ),
    );
  }

  Widget _buildImageCollection(
    BuildContext context,
    WidgetRef ref,
    ChatMediaSearchState state,
    ChatMediaSearchController controller,
  ) {
    final sections = groupCollectionItems(
      state.items,
    ).entries.toList(growable: false);
    return CustomScrollView(
      slivers: [
        for (final entry in sections) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchCollectionSectionHeaderDelegate(
              sectionKey: entry.key,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = entry.value[index];
                return SearchCollectionImageTile(
                  item: item,
                  onTap: () => _handleTap(context, ref, state.items, item),
                  onLongPress: () => _showImageQuickActions(context, ref, item),
                );
              }, childCount: entry.value.length),
            ),
          ),
        ],
        SliverToBoxAdapter(child: _buildLoadMoreFooter(state, controller)),
      ],
    );
  }

  Widget _buildLoadMoreFooter(
    ChatMediaSearchState state,
    ChatMediaSearchController controller,
  ) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载更多失败'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('search-collection-load-more-retry'),
              onPressed: () => controller.loadMore(isRetry: true),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    List<SearchMediaItem> allItems,
    SearchMediaItem item,
  ) async {
    if (scope == SearchCollectionScope.image) {
      await _openPreview(context, ref, allItems, item);
      return;
    }
    await _showInChat(context, ref, item);
  }

  Future<void> _openPreview(
    BuildContext context,
    WidgetRef ref,
    List<SearchMediaItem> allItems,
    SearchMediaItem item,
  ) async {
    final previewableItems = allItems
        .where((candidate) => candidate.scope == SearchCollectionScope.image)
        .where((candidate) {
          final mediaUrl = candidate.mediaUrl?.trim() ?? '';
          return mediaUrl.isNotEmpty;
        })
        .toList(growable: false);
    final initialIndex = previewableItems.indexWhere(
      (candidate) => candidate.hit.messageSeq == item.hit.messageSeq,
    );
    if (initialIndex == -1) {
      if (onShowItemInChat != null) {
        await onShowItemInChat!(item);
        return;
      }
      await _showInChat(context, ref, item);
      return;
    }

    await ImageViewerHelper.show(
      context,
      images: previewableItems
          .map((candidate) => candidate.mediaUrl!.trim())
          .toList(growable: false),
      initialIndex: initialIndex,
      heroTag: 'search-image-preview',
      actions: [
        ImageViewerAction(
          key: 'forward',
          icon: Icons.forward_outlined,
          label: '转发',
          onPressed: (viewerContext, index) async {
            final currentItem = previewableItems[index];
            if (onForwardItem != null) {
              await onForwardItem!(currentItem);
              return;
            }
            if (viewerContext.mounted) {
              Navigator.of(viewerContext).pop();
            }
            if (!context.mounted) {
              return;
            }
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatSearchImageForwardPage(item: currentItem),
              ),
            );
          },
        ),
        ImageViewerAction(
          key: 'favorite',
          icon: Icons.favorite_border,
          label: '收藏',
          onPressed: (viewerContext, index) async {
            final currentItem = previewableItems[index];
            if (onFavoriteItem != null) {
              await onFavoriteItem!(currentItem);
              return;
            }
            await _favoriteItem(viewerContext, currentItem);
          },
        ),
        ImageViewerAction(
          key: 'show-in-chat',
          icon: Icons.chat_bubble_outline,
          label: '在聊天中查看',
          onPressed: (viewerContext, index) async {
            final currentItem = previewableItems[index];
            if (onShowItemInChat != null) {
              await onShowItemInChat!(currentItem);
              return;
            }
            if (viewerContext.mounted) {
              Navigator.of(viewerContext).pop();
            }
            await _showInChat(context, ref, currentItem);
          },
        ),
        if (EndpointManager.getInstance().hasEndpoint(ChatMenuIDs.parseQrCode))
          ImageViewerAction(
            key: 'scan-qrcode',
            icon: Icons.qr_code_scanner_outlined,
            label: '识别二维码',
            onPressed: (viewerContext, index) async {
              await ScanQrCodeBridge.instance.handleImageSource(
                previewableItems[index].mediaUrl!,
              );
            },
          ),
      ],
    );
  }

  Future<void> _showImageQuickActions(
    BuildContext context,
    WidgetRef ref,
    SearchMediaItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey<String>(
                  'search-image-quick-action-forward',
                ),
                leading: const Icon(Icons.forward_outlined),
                title: const Text('转发'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(Duration.zero);
                  if (onForwardItem != null) {
                    await onForwardItem!(item);
                    return;
                  }
                  if (!context.mounted) {
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatSearchImageForwardPage(item: item),
                    ),
                  );
                },
              ),
              ListTile(
                key: const ValueKey<String>(
                  'search-image-quick-action-show-in-chat',
                ),
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('在聊天中查看'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(Duration.zero);
                  if (onShowItemInChat != null) {
                    await onShowItemInChat!(item);
                    return;
                  }
                  if (!context.mounted) {
                    return;
                  }
                  await _showInChat(context, ref, item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInChat(
    BuildContext context,
    WidgetRef ref,
    SearchMediaItem item,
  ) async {
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      item.hit,
      highlightKeyword: '',
      source: 'chat-collection-search',
    );
    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: channelName,
    );
  }

  Future<void> _favoriteItem(BuildContext context, SearchMediaItem item) async {
    final clientMsgNo = item.hit.clientMsgNo?.trim() ?? '';
    if (clientMsgNo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前消息无法收藏')));
      return;
    }

    try {
      await CollectionApi.instance.add(
        clientMsgNo: clientMsgNo,
        messageId: item.hit.messageId,
        content: item.mediaUrl ?? item.hit.previewText,
        contentType: item.hit.contentType,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加到收藏')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('收藏失败：$error')));
    }
  }
}
