import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/media_cache_manager.dart';
import '../../core/platform/local_file_picker.dart';
import '../../widgets/local_media_image_provider.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import '../../wukong_base/emoji/emoji_manager.dart';

class EmojiStorePage extends ConsumerStatefulWidget {
  const EmojiStorePage({super.key});

  @override
  ConsumerState<EmojiStorePage> createState() => _EmojiStorePageState();
}

class _EmojiStorePageState extends ConsumerState<EmojiStorePage>
    with SingleTickerProviderStateMixin {
  final EmojiManager _emojiManager = EmojiManager.instance;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;
  List<EmojiPack> _packs = const <EmojiPack>[];

  List<EmojiPack> get _filteredPacks {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _packs;
    }
    return _packs.where((pack) {
      final nameMatch = pack.name.toLowerCase().contains(keyword);
      final emojiMatch = pack.emojis.any(
        (item) => item.toLowerCase().contains(keyword),
      );
      return nameMatch || emojiMatch;
    }).toList();
  }

  List<EmojiPack> get _favoritePacks =>
      _packs.where((item) => item.isFavorite).toList();

  List<String> get _favoriteItems =>
      _favoritePacks.expand((item) => item.emojis).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_refreshLocalState);
    unawaited(_loadPacks());
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshLocalState);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoading = true);
    await _emojiManager.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _packs = _emojiManager.packs;
      _isLoading = false;
    });
  }

  void _refreshLocalState() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _toggleFavorite(EmojiPack pack) async {
    await _emojiManager.togglePackFavorite(pack.id);
    await _loadPacks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pack.isFavorite ? '已取消收藏' : '已加入收藏'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deletePack(EmojiPack pack) async {
    if (pack.isBuiltIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系统内置表情包暂不支持删除')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除表情包'),
          content: Text('确定删除“${pack.name}”吗？删除后不会影响其他已收藏表情。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _emojiManager.deletePack(pack.id);
    await _loadPacks();
  }

  Future<void> _addEmojiPack() async {
    final paths = await pickMultipleLocalImageFilePaths(
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'gif', 'webp'],
    );
    if (paths == null) {
      return;
    }

    if (paths.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可用的表情文件')));
      return;
    }
    if (!mounted) {
      return;
    }

    final nameController = TextEditingController(
      text: '我的表情包 ${_packs.length + 1}',
    );
    final packName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建表情包'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: '输入表情包名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(nameController.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (packName == null) {
      return;
    }

    await _emojiManager.addPack(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: packName,
      emojis: paths,
      coverUrl: paths.first,
    );
    await _loadPacks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('表情包已导入')));
  }

  void _openEmojiPack(EmojiPack pack) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EmojiPackDetailPage(
          pack: pack,
          onFavorite: () => _toggleFavorite(pack),
          onDelete: () => _deletePack(pack),
          onItemTap: _rememberEmoji,
        ),
      ),
    );
  }

  void _rememberEmoji(String emoji) {
    _emojiManager.addToRecent(emoji);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入最近使用')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情商店'),
        actions: [
          IconButton(
            tooltip: '导入本地表情包',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _addEmojiPack,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '表情包'),
            Tab(text: '我的收藏'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WKSpace.md,
              WKSpace.md,
              WKSpace.md,
              WKSpace.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索表情包名称或表情内容',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WKRadius.lg),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: WKColors.surfaceSoft,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const WKLoadingView(message: '正在加载表情包...')
                : TabBarView(
                    controller: _tabController,
                    children: [_buildPackList(), _buildFavoriteList()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackList() {
    final packs = _filteredPacks;
    if (packs.isEmpty) {
      return const WKEmptyView(
        icon: Icons.emoji_emotions_outlined,
        message: '还没有匹配的表情包',
        subMessage: '你可以导入本地图片/GIF，或者调整搜索关键词。',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPacks,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.sm,
          WKSpace.md,
          WKSpace.xl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: WKSpace.md,
          mainAxisSpacing: WKSpace.md,
          childAspectRatio: 0.92,
        ),
        itemCount: packs.length,
        itemBuilder: (context, index) {
          final pack = packs[index];
          return _EmojiPackCard(
            pack: pack,
            onTap: () => _openEmojiPack(pack),
            onFavorite: () => _toggleFavorite(pack),
            onDelete: () => _deletePack(pack),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteList() {
    if (_favoriteItems.isEmpty) {
      return const WKEmptyView(
        icon: Icons.favorite_border_rounded,
        message: '还没有收藏的表情',
        subMessage: '给常用表情包点个收藏，后续这里会更好用。',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        WKSpace.md,
        WKSpace.sm,
        WKSpace.md,
        WKSpace.xl,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: WKSpace.sm,
        mainAxisSpacing: WKSpace.sm,
      ),
      itemCount: _favoriteItems.length,
      itemBuilder: (context, index) {
        final emoji = _favoriteItems[index];
        return GestureDetector(
          onTap: () => _rememberEmoji(emoji),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: WKColors.surface,
              borderRadius: BorderRadius.circular(WKRadius.md),
              border: Border.all(color: WKColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(WKSpace.xs),
              child: Center(child: _EmojiPreview(value: emoji, size: 36)),
            ),
          ),
        );
      },
    );
  }
}

class _EmojiPackCard extends StatelessWidget {
  final EmojiPack pack;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _EmojiPackCard({
    required this.pack,
    required this.onTap,
    required this.onFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(WKRadius.xl),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(WKSpace.md),
          decoration: BoxDecoration(
            color: WKColors.surface,
            borderRadius: BorderRadius.circular(WKRadius.xl),
            border: Border.all(color: WKColors.outline),
            boxShadow: WKShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pack.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: pack.isFavorite ? '取消收藏' : '收藏表情包',
                    onPressed: onFavorite,
                    icon: Icon(
                      pack.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: pack.isFavorite
                          ? WKColors.reminderColor
                          : WKColors.textTertiary,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: WKSpace.xs,
                    mainAxisSpacing: WKSpace.xs,
                  ),
                  itemCount: pack.emojis.length > 6 ? 6 : pack.emojis.length,
                  itemBuilder: (context, index) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: WKColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(WKRadius.sm),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Center(
                          child: _EmojiPreview(
                            value: pack.emojis[index],
                            size: 26,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: WKSpace.sm),
              Row(
                children: [
                  Text(
                    '${pack.emojis.length} 个表情',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WKColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (!pack.isBuiltIn)
                    IconButton(
                      tooltip: '删除表情包',
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: WKColors.danger,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiPackDetailPage extends StatelessWidget {
  final EmojiPack pack;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final void Function(String emoji) onItemTap;

  const _EmojiPackDetailPage({
    required this.pack,
    required this.onFavorite,
    required this.onDelete,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
        actions: [
          IconButton(
            tooltip: pack.isFavorite ? '取消收藏' : '收藏表情包',
            onPressed: onFavorite,
            icon: Icon(
              pack.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: pack.isFavorite ? WKColors.reminderColor : null,
            ),
          ),
          if (!pack.isBuiltIn)
            IconButton(
              tooltip: '删除表情包',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(WKSpace.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: WKSpace.sm,
          mainAxisSpacing: WKSpace.sm,
        ),
        itemCount: pack.emojis.length,
        itemBuilder: (context, index) {
          final emoji = pack.emojis[index];
          return GestureDetector(
            onTap: () => onItemTap(emoji),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: WKColors.surface,
                borderRadius: BorderRadius.circular(WKRadius.md),
                border: Border.all(color: WKColors.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(WKSpace.xs),
                child: Center(child: _EmojiPreview(value: emoji, size: 46)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmojiPreview extends StatelessWidget {
  final String value;
  final double size;

  const _EmojiPreview({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    if (_looksLikeRemoteMedia(value)) {
      final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
      return ClipRRect(
        borderRadius: BorderRadius.circular(WKRadius.sm),
        child: CachedMediaImage(
          imageUrl: value,
          cacheKey: value,
          width: size,
          height: size,
          maxWidth: decodeSize,
          maxHeight: decodeSize,
          fit: BoxFit.cover,
          placeholder: (_, _) => _emojiFallback(),
          errorWidget: (_, _, _) => _emojiFallback(),
        ),
      );
    }

    if (_looksLikeLocalMedia(value)) {
      final imageProvider = resolveLocalMediaImageProvider(value);
      return ClipRRect(
        borderRadius: BorderRadius.circular(WKRadius.sm),
        child: imageProvider == null
            ? _emojiFallback()
            : Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _emojiFallback(),
              ),
      );
    }

    return Text(value, style: TextStyle(fontSize: size));
  }

  Widget _emojiFallback() {
    return Icon(
      Icons.image_not_supported_outlined,
      size: size * 0.75,
      color: WKColors.textTertiary,
    );
  }
}

bool _looksLikeLocalMedia(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('\\') ||
      normalized.startsWith('/') ||
      normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.gif') ||
      normalized.endsWith('.webp');
}

bool _looksLikeRemoteMedia(String value) {
  final normalized = value.toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}
