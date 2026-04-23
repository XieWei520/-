import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'wk_colors.dart';

class WKAvatar extends StatefulWidget {
  final String? url;
  final String? name;
  final double size;
  final bool isGroup;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const WKAvatar({
    super.key,
    this.url,
    this.name,
    this.size = 40,
    this.isGroup = false,
    this.borderRadius,
    this.onTap,
  });

  static const Set<String> _knownPlaceholderHashes = {
    '13b9c7748b60fd0290013c92341f44fd',
  };
  static final Map<String, Uint8List?> _bytesCache = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _pendingLoads =
      <String, Future<Uint8List?>>{};

  static String? _normalizeUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static Future<void> evictUrl(String? value) async {
    final normalized = _normalizeUrl(value);
    if (normalized == null) {
      return;
    }

    _bytesCache.remove(normalized);
    _pendingLoads.remove(normalized);

    final uri = Uri.tryParse(normalized);
    if (uri != null && (uri.hasQuery || uri.fragment.isNotEmpty)) {
      final withoutQuery = uri.replace(queryParameters: const {}, fragment: '');
      final baseUrl = withoutQuery.toString();
      _bytesCache.remove(baseUrl);
      _pendingLoads.remove(baseUrl);
    }
  }

  static Future<Uint8List?> _loadBytes(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) {
      return Future<Uint8List?>.value(null);
    }
    if (_bytesCache.containsKey(normalizedUrl)) {
      return Future<Uint8List?>.value(_bytesCache[normalizedUrl]);
    }

    return _pendingLoads.putIfAbsent(normalizedUrl, () async {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
        final request = await client.getUrl(Uri.parse(normalizedUrl));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _bytesCache[normalizedUrl] = null;
          return null;
        }

        final bytes = await consolidateHttpClientResponseBytes(response);
        if (bytes.isEmpty) {
          _bytesCache[normalizedUrl] = null;
          return null;
        }

        final hash = crypto.md5.convert(bytes).toString();
        final isPlaceholder = _knownPlaceholderHashes.contains(hash);
        final resolvedBytes = isPlaceholder ? null : bytes;
        _bytesCache[normalizedUrl] = resolvedBytes;
        return resolvedBytes;
      } catch (_) {
        _bytesCache[normalizedUrl] = null;
        return null;
      } finally {
        client?.close(force: true);
        _pendingLoads.remove(normalizedUrl);
      }
    });
  }

  @override
  State<WKAvatar> createState() => _WKAvatarState();
}

class _WKAvatarState extends State<WKAvatar> {
  Future<Uint8List?>? _avatarFuture;

  @override
  void initState() {
    super.initState();
    _syncAvatarFuture();
  }

  @override
  void didUpdateWidget(covariant WKAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _syncAvatarFuture();
    }
  }

  void _syncAvatarFuture() {
    final normalizedUrl = WKAvatar._normalizeUrl(widget.url);
    _avatarFuture = normalizedUrl == null
        ? null
        : WKAvatar._loadBytes(normalizedUrl);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius:
            widget.borderRadius ??
            BorderRadius.circular(widget.isGroup ? 8 : widget.size / 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildAvatarContent(),
    );

    if (widget.onTap == null) {
      return avatar;
    }

    return GestureDetector(onTap: widget.onTap, child: avatar);
  }

  Widget _buildAvatarContent() {
    if (_avatarFuture == null) {
      return _buildPlaceholder();
    }

    return FutureBuilder<Uint8List?>(
      future: _avatarFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildPlaceholder(),
              Center(
                child: SizedBox(
                  width: widget.size * 0.28,
                  height: widget.size * 0.28,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    final safeName = widget.name?.trim() ?? '';
    final label = safeName.isEmpty
        ? ''
        : safeName.substring(0, 1).toUpperCase();
    final palette = _paletteFor(
      safeName.isEmpty ? (widget.isGroup ? 'group' : 'user') : safeName,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -widget.size * 0.14,
            right: -widget.size * 0.1,
            child: Container(
              width: widget.size * 0.52,
              height: widget.size * 0.52,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(36),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -widget.size * 0.18,
            left: -widget.size * 0.12,
            child: Container(
              width: widget.size * 0.62,
              height: widget.size * 0.62,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: label.isNotEmpty
                ? Text(
                    label,
                    style: TextStyle(
                      color: WKColors.white,
                      fontSize: widget.size * 0.38,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Icon(
                    widget.isGroup ? Icons.group_rounded : Icons.person_rounded,
                    size: widget.size * 0.52,
                    color: WKColors.white.withAlpha(232),
                  ),
          ),
        ],
      ),
    );
  }

  List<Color> _paletteFor(String seed) {
    const palettes = <List<Color>>[
      [Color(0xFF4F8CFF), Color(0xFF6C63FF)],
      [Color(0xFF12B886), Color(0xFF2F9E44)],
      [Color(0xFFFF922B), Color(0xFFFF6B6B)],
      [Color(0xFF0CA678), Color(0xFF3BC9DB)],
      [Color(0xFFE64980), Color(0xFFBE4BDB)],
      [Color(0xFF1C7ED6), Color(0xFF15AABF)],
      [Color(0xFFFFA94D), Color(0xFFFF6B6B)],
      [Color(0xFF5F3DC4), Color(0xFF364FC7)],
    ];

    final normalized = seed.trim();
    if (normalized.isEmpty) {
      return palettes.first;
    }
    final index =
        normalized.runes.fold<int>(0, (sum, rune) => sum + rune) %
        palettes.length;
    return palettes[index];
  }
}
