import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/link_preview.dart';

class LinkPreviewService {
  LinkPreviewService._();

  static final LinkPreviewService instance = LinkPreviewService._();
  static const int maxPreviewCacheEntries = 256;

  static final RegExp _urlPattern = RegExp(
    r'(https?:\/\/[^\s<>"\u3000]+)',
    caseSensitive: false,
  );
  static final RegExp _titlePattern = RegExp(
    r'<title[^>]*>(.*?)<\/title>',
    caseSensitive: false,
    dotAll: true,
  );

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
      responseType: ResponseType.plain,
      followRedirects: true,
      maxRedirects: 4,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (compatible; WuKongIM-LinkPreview/1.0; +https://wukongim.io)',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    ),
  );

  final LinkedHashMap<String, LinkPreview?> _cache =
      LinkedHashMap<String, LinkPreview?>();
  final Map<String, Future<LinkPreview?>> _pending =
      <String, Future<LinkPreview?>>{};

  static String? extractFirstUrl(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    final match = _urlPattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    return normalizeUrl(match.group(0));
  }

  static String? normalizeUrl(String? rawUrl) {
    final candidate = (rawUrl ?? '').trim();
    if (candidate.isEmpty) {
      return null;
    }
    var normalized = candidate;
    while (normalized.isNotEmpty &&
        '.,!?)]}\'"'.contains(normalized[normalized.length - 1])) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    if ((uri.host).trim().isEmpty) {
      return null;
    }
    return uri.toString();
  }

  Future<LinkPreview?> getPreviewForText(String text) async {
    final url = extractFirstUrl(text);
    if (url == null) {
      return null;
    }
    return getPreview(url);
  }

  Future<LinkPreview?> getPreview(String url) async {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl == null) {
      return null;
    }
    if (_cache.containsKey(normalizedUrl)) {
      final cached = _cache.remove(normalizedUrl);
      _cache[normalizedUrl] = cached;
      return cached;
    }
    final pending = _pending[normalizedUrl];
    if (pending != null) {
      return pending;
    }

    final future = _fetchPreview(normalizedUrl);
    _pending[normalizedUrl] = future;
    try {
      final preview = await future;
      _storePreview(normalizedUrl, preview);
      return preview;
    } finally {
      _pending.remove(normalizedUrl);
    }
  }

  @visibleForTesting
  void setPreviewForTesting(String url, LinkPreview? preview) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl == null) {
      return;
    }
    _pending.remove(normalizedUrl);
    _storePreview(normalizedUrl, preview);
  }

  @visibleForTesting
  void clearCacheForTesting() {
    _cache.clear();
    _pending.clear();
  }

  @visibleForTesting
  int get cachedPreviewCountForTesting => _cache.length;

  @visibleForTesting
  bool hasCachedPreviewForTesting(String url) {
    final normalizedUrl = normalizeUrl(url);
    return normalizedUrl != null && _cache.containsKey(normalizedUrl);
  }

  void _storePreview(String url, LinkPreview? preview) {
    _cache.remove(url);
    while (_cache.length >= maxPreviewCacheEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = preview;
  }

  Future<LinkPreview?> _fetchPreview(String url) async {
    final fallback = buildFallbackPreview(url);
    try {
      final response = await _dio.get<String>(url);
      final body = response.data?.trim() ?? '';
      if (body.isEmpty) {
        return fallback;
      }
      return parsePreviewDocument(url: url, document: body) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  LinkPreview buildFallbackPreview(String url) {
    final uri = Uri.parse(url);
    final host = uri.host.trim();
    final path = uri.path.trim();
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final displayUrl = path.isEmpty || path == '/' ? host : '$host$path$query';
    return LinkPreview(
      url: url,
      host: host,
      displayUrl: displayUrl,
      title: '',
      description: '',
      isFallback: true,
    );
  }

  LinkPreview? parsePreviewDocument({
    required String url,
    required String document,
  }) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl == null) {
      return null;
    }
    final fallback = buildFallbackPreview(normalizedUrl);
    final uri = Uri.parse(normalizedUrl);
    final ogTitle = _extractMetaContent(document, property: 'og:title');
    final twitterTitle = _extractMetaContent(document, name: 'twitter:title');
    final pageTitle = _extractTagContent(document, _titlePattern);
    final ogDescription = _extractMetaContent(
      document,
      property: 'og:description',
    );
    final description = _extractMetaContent(document, name: 'description');
    final twitterDescription = _extractMetaContent(
      document,
      name: 'twitter:description',
    );
    final ogImage = _extractMetaContent(document, property: 'og:image');
    final twitterImage = _extractMetaContent(document, name: 'twitter:image');

    final title = _firstNonEmpty(<String?>[ogTitle, twitterTitle, pageTitle]);
    final summary = _firstNonEmpty(<String?>[
      ogDescription,
      twitterDescription,
      description,
    ]);
    final rawImage = _firstNonEmpty(<String?>[ogImage, twitterImage]);

    String? imageUrl;
    if (rawImage.trim().isNotEmpty) {
      imageUrl = normalizeUrl(uri.resolve(rawImage).toString());
    }

    return fallback.copyWith(
      title: _clipAndDecode(title, 80),
      description: _clipAndDecode(summary, 140),
      imageUrl: imageUrl,
      isFallback: false,
    );
  }

  static String? _extractMetaContent(
    String document, {
    String? property,
    String? name,
  }) {
    if ((property ?? '').isEmpty && (name ?? '').isEmpty) {
      return null;
    }
    final key = property ?? name!;
    final pattern = property != null
        ? RegExp(
            '<meta[^>]*property=[\'"]${RegExp.escape(key)}[\'"][^>]*content=[\'"]([^\'"]+)[\'"][^>]*>',
            caseSensitive: false,
            dotAll: true,
          )
        : RegExp(
            '<meta[^>]*name=[\'"]${RegExp.escape(key)}[\'"][^>]*content=[\'"]([^\'"]+)[\'"][^>]*>',
            caseSensitive: false,
            dotAll: true,
          );

    final match = pattern.firstMatch(document);
    if (match == null) {
      final reversedPattern = property != null
          ? RegExp(
              '<meta[^>]*content=[\'"]([^\'"]+)[\'"][^>]*property=[\'"]${RegExp.escape(key)}[\'"][^>]*>',
              caseSensitive: false,
              dotAll: true,
            )
          : RegExp(
              '<meta[^>]*content=[\'"]([^\'"]+)[\'"][^>]*name=[\'"]${RegExp.escape(key)}[\'"][^>]*>',
              caseSensitive: false,
              dotAll: true,
            );
      return reversedPattern.firstMatch(document)?.group(1);
    }
    return match.group(1);
  }

  static String? _extractTagContent(String document, RegExp pattern) {
    final match = pattern.firstMatch(document);
    return match?.group(1);
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static String _clipAndDecode(String? value, int maxLength) {
    final decoded = _decodeHtml((value ?? '').replaceAll(RegExp(r'\s+'), ' '));
    if (decoded.length <= maxLength) {
      return decoded;
    }
    final clippedLength = maxLength > 3 ? maxLength - 3 : maxLength;
    final suffix = maxLength > 3 ? '...' : '';
    return '${decoded.substring(0, clippedLength)}$suffix';
  }

  static String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', '\'')
        .replaceAll('&apos;', '\'')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
