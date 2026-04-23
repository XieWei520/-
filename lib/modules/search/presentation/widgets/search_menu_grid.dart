import 'package:flutter/material.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';

import '../../domain/search_models.dart';

List<SearchMenuEntry> buildDefaultSearchMenuEntries() {
  return const <SearchMenuEntry>[
    SearchMenuEntry(
      kind: SearchMenuKind.date,
      title: 'Date',
      iconAsset: WKReferenceAssets.search,
      key: 'chat-search-menu-date',
    ),
    SearchMenuEntry(
      kind: SearchMenuKind.image,
      title: 'Image',
      iconAsset: WKReferenceAssets.search,
      key: 'chat-search-menu-image',
    ),
    SearchMenuEntry(
      kind: SearchMenuKind.file,
      title: 'File',
      iconAsset: WKReferenceAssets.search,
      key: 'chat-search-menu-file',
    ),
    SearchMenuEntry(
      kind: SearchMenuKind.link,
      title: 'Link',
      iconAsset: WKReferenceAssets.search,
      key: 'chat-search-menu-link',
    ),
    SearchMenuEntry(
      kind: SearchMenuKind.member,
      title: 'Member',
      iconAsset: WKReferenceAssets.search,
      key: 'chat-search-menu-member',
    ),
  ];
}

class SearchMenuGrid extends StatelessWidget {
  const SearchMenuGrid({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<SearchMenuEntry> entries;
  final ValueChanged<SearchMenuEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      key: const ValueKey<String>('chat-search-menu-grid'),
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.35,
      children: entries
          .map(
            (entry) => InkWell(
              key: ValueKey<String>(entry.key),
              onTap: () => onTap(entry),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KeyedSubtree(
                      key: ValueKey<String>('${entry.key}-icon'),
                      child: WKReferenceAssets.image(
                        entry.iconAsset,
                        width: 22,
                        height: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      key: ValueKey<String>('${entry.key}-title'),
                      entry.title,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
