import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/search_models.dart';

Map<String, List<SearchMediaItem>> groupCollectionItems(
  List<SearchMediaItem> items,
) {
  final sections = <String, List<SearchMediaItem>>{};
  for (final item in items) {
    final key = item.sectionKey.isEmpty ? 'Unknown' : item.sectionKey;
    sections.putIfAbsent(key, () => <SearchMediaItem>[]).add(item);
  }
  return sections;
}

class SearchCollectionSectionHeader extends StatelessWidget {
  const SearchCollectionSectionHeader({
    super.key,
    required this.sectionKey,
  });

  final String sectionKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('search-collection-section-$sectionKey'),
      width: double.infinity,
      color: const Color(0x05000000),
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
      alignment: Alignment.centerLeft,
      child: Text(
        sectionKey,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF313131),
          fontSize: 14,
        ),
      ),
    );
  }
}

class SearchCollectionSectionHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  SearchCollectionSectionHeaderDelegate({
    required this.sectionKey,
    this.height = 30,
  });

  final String sectionKey;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SearchCollectionSectionHeader(sectionKey: sectionKey);
  }

  @override
  bool shouldRebuild(SearchCollectionSectionHeaderDelegate oldDelegate) {
    return oldDelegate.sectionKey != sectionKey || oldDelegate.height != height;
  }
}

class SearchCollectionImageTile extends StatelessWidget {
  const SearchCollectionImageTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final SearchMediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = item.mediaUrl?.trim() ?? '';
    final isLocalImage = mediaUrl.isNotEmpty && _isLocalImagePath(mediaUrl);

    return InkWell(
      key: ValueKey<String>('search-collection-item-${item.hit.messageSeq}'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: mediaUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isLocalImage
                    ? Image.file(
                        _resolveLocalFile(mediaUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                      )
                    : CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                        placeholder: (context, url) => const ColoredBox(
                          color: Color(0xFFF1F1F1),
                          child: Center(
                            child: Icon(Icons.image_outlined),
                          ),
                        ),
                      ),
              )
            : const Icon(Icons.image_outlined),
      ),
    );
  }
}

bool _isLocalImagePath(String mediaUrl) {
  final uri = Uri.tryParse(mediaUrl);
  if (uri != null && uri.scheme == 'file') {
    return true;
  }
  if (mediaUrl.startsWith('/')) {
    return true;
  }
  if (mediaUrl.startsWith(r'\\')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(mediaUrl);
}

File _resolveLocalFile(String mediaUrl) {
  if (mediaUrl.startsWith('file://')) {
    final uri = Uri.tryParse(mediaUrl);
    if (uri != null) {
      return File.fromUri(uri);
    }
    return File(mediaUrl.substring('file://'.length));
  }
  final uri = Uri.tryParse(mediaUrl);
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri);
  }
  return File(mediaUrl);
}

class SearchCollectionSection extends StatelessWidget {
  const SearchCollectionSection({
    super.key,
    required this.sectionKey,
    required this.items,
    required this.onTapItem,
    this.onLongPressItem,
  });

  final String sectionKey;
  final List<SearchMediaItem> items;
  final ValueChanged<SearchMediaItem> onTapItem;
  final ValueChanged<SearchMediaItem>? onLongPressItem;

  @override
  Widget build(BuildContext context) {
    final scope = items.first.scope;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchCollectionSectionHeader(sectionKey: sectionKey),
        if (scope == SearchCollectionScope.image)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return SearchCollectionImageTile(
                item: item,
                onTap: () => onTapItem(item),
                onLongPress: onLongPressItem == null
                    ? null
                    : () => onLongPressItem!(item),
              );
            },
          )
        else
          Column(
            children: items.map((item) {
              final icon = scope == SearchCollectionScope.file
                  ? Icons.insert_drive_file_outlined
                  : Icons.link_outlined;
              final title = item.fileName?.trim().isNotEmpty == true
                  ? item.fileName!.trim()
                  : item.hit.previewText;
              final subtitle = scope == SearchCollectionScope.link
                  ? (item.linkUrl ?? item.hit.previewText)
                  : item.hit.fromName;
              return ListTile(
                key: ValueKey<String>(
                  'search-collection-item-${item.hit.messageSeq}',
                ),
                leading: Icon(icon),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onTapItem(item),
              );
            }).toList(growable: false),
          ),
      ],
    );
  }
}
