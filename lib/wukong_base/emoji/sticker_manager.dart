import 'android_emoji_catalog.dart';
import 'emoji_manager.dart';

/// Sticker category
class StickerCategory {
  final String id;
  final String name;
  final String? iconUrl;
  final List<Sticker> stickers;
  final bool isBuiltIn;

  const StickerCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.stickers,
    this.isBuiltIn = false,
  });
}

/// Sticker
class Sticker {
  final String id;
  final String name;
  final String? url;
  final String? localPath;

  const Sticker({
    required this.id,
    required this.name,
    this.url,
    this.localPath,
  });

  String get displayUrl => localPath ?? url ?? '';
}

/// Sticker manager
class StickerManager {
  StickerManager._();
  static final StickerManager _instance = StickerManager._();
  static StickerManager get instance => _instance;

  final EmojiManager _emojiManager = EmojiManager.instance;
  List<StickerCategory> _categories = [];
  bool _isLoading = false;

  List<StickerCategory> get categories =>
      List<StickerCategory>.unmodifiable(_categories);

  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    await loadCategories();
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    try {
      await _emojiManager.initialize();
      _categories = _emojiManager.packs.map(_packToCategory).toList();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> downloadCategory(String categoryId) async {
    await loadCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    StickerCategory? category;
    for (final item in _categories) {
      if (item.id == categoryId) {
        category = item;
        break;
      }
    }
    if (category == null || category.isBuiltIn) {
      return;
    }
    await _emojiManager.deletePack(categoryId);
    await loadCategories();
  }

  List<Sticker> search(String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return <Sticker>[];
    }

    final results = <Sticker>[];
    for (final category in _categories) {
      for (final sticker in category.stickers) {
        if (sticker.name.toLowerCase().contains(keyword)) {
          results.add(sticker);
        }
      }
    }
    return results;
  }

  StickerCategory _packToCategory(EmojiPack pack) {
    return StickerCategory(
      id: pack.id,
      name: pack.name,
      iconUrl: pack.coverUrl,
      isBuiltIn: pack.isBuiltIn,
      stickers: List<Sticker>.generate(pack.emojis.length, (index) {
        final value = pack.emojis[index].trim();
        final entry = androidEmojiCatalog.lookupByTag(value);
        if (entry != null) {
          return Sticker(
            id: '${pack.id}_$index',
            name: entry.id,
            localPath: entry.assetPath,
          );
        }
        final isRemote = _isHttpUrl(value);
        final localPath = !isRemote && value.isNotEmpty ? value : null;
        return Sticker(
          id: '${pack.id}_$index',
          name: '${pack.name} ${index + 1}',
          url: isRemote ? value : null,
          localPath: localPath,
        );
      }),
    );
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}
