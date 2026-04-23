import 'dart:convert';
import 'dart:io';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'local_search_service.dart';
import 'search_local_timeline_data_source.dart';
import 'search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required SearchRemoteDataSource remoteDataSource,
    required SearchLocalTimelineDataSource localTimelineDataSource,
    LocalSearchService? localSearchService,
    DateTime Function()? now,
    Future<bool> Function(String path)? localImagePathExists,
  }) : _remoteDataSource = remoteDataSource,
       _localTimelineDataSource = localTimelineDataSource,
       _localSearchService = localSearchService ?? LocalSearchService(),
       _now = now ?? DateTime.now,
       _localImagePathExists =
           localImagePathExists ?? _defaultLocalImagePathExists;

  final SearchRemoteDataSource _remoteDataSource;
  final SearchLocalTimelineDataSource _localTimelineDataSource;
  final LocalSearchService _localSearchService;
  final DateTime Function() _now;
  final Future<bool> Function(String path) _localImagePathExists;

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    final buckets = await _localTimelineDataSource.loadDateBuckets(
      channelId: channelId,
      channelType: channelType,
    );
    return buildDateCalendarSections(buckets: buckets, now: _now());
  }

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    final members = await _remoteDataSource.getChannelMembers(
      channelId: channelId,
    );
    return members
        .map(
          (member) => SearchMemberHit(
            uid: _readString(member, 'uid'),
            displayName: _resolveMemberDisplayName(member),
            avatarUrl: _readOptionalString(member, 'avatar'),
          ),
        )
        .where((member) => member.uid.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return _localSearchService.searchGlobal(
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final items = switch (scope) {
      SearchCollectionScope.image => await _remoteDataSource.searchImages(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
      SearchCollectionScope.file => await _remoteDataSource.searchFiles(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
      SearchCollectionScope.link => await _remoteDataSource.searchLinks(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
    };

    final mappedItems = <SearchMediaItem>[];
    for (final item in items) {
      mappedItems.add(
        SearchMediaItem(
          hit: _mapMessageHit(item),
          scope: scope,
          sectionKey: _buildSectionKey(
            _readInt(item, 'timestamp'),
            monthOnly: scope == SearchCollectionScope.image,
          ),
          mediaUrl: await _resolveMediaUrl(scope, item),
          fileName: _readOptionalString(item, 'file_name'),
          linkUrl: _resolveLinkUrl(scope, item),
        ),
      );
    }
    return mappedItems.toList(growable: false);
  }

  static Future<bool> _defaultLocalImagePathExists(String path) {
    return File(path).exists();
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return _localSearchService.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: keyword,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final items = await _remoteDataSource.searchMessagesByMember(
      channelId: channelId,
      channelType: channelType,
      senderId: memberUid,
      keyword: keyword,
      page: safePage,
      limit: safeLimit,
    );
    return items.map(_mapMessageHit).toList(growable: false);
  }

  SearchMessageHit _mapMessageHit(Map<String, dynamic> item) {
    return SearchMessageHit(
      channelId: _readString(item, 'channel_id'),
      channelType: _readInt(item, 'channel_type'),
      messageSeq: _readInt(item, 'message_seq'),
      orderSeq: _readInt(item, 'order_seq'),
      timestamp: _readInt(item, 'timestamp'),
      contentType: _readInt(item, 'content_type'),
      fromUid: _readString(item, 'from_uid'),
      fromName: _readString(item, 'from_name'),
      previewText: _resolvePreviewText(item),
      channelName: _readOptionalString(item, 'channel_name'),
      messageId: _readOptionalString(item, 'message_id'),
      clientMsgNo: _readOptionalString(item, 'client_msg_no'),
    );
  }

  String _buildSectionKey(int timestamp, {bool monthOnly = false}) {
    if (timestamp <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    ).toLocal();
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    if (monthOnly) {
      return monthKey;
    }
    return '$monthKey-${date.day.toString().padLeft(2, '0')}';
  }

  String? _resolveLinkUrl(
    SearchCollectionScope scope,
    Map<String, dynamic> item,
  ) {
    if (scope != SearchCollectionScope.link) {
      return null;
    }
    return _readOptionalString(item, 'link_url') ??
        _readOptionalString(item, 'url');
  }

  Future<String?> _resolveMediaUrl(
    SearchCollectionScope scope,
    Map<String, dynamic> item,
  ) async {
    if (scope == SearchCollectionScope.image) {
      final localPath =
          _readOptionalString(item, 'local_path') ??
          _readOptionalString(item, 'localPath');
      if (localPath != null && await _localImagePathExists(localPath)) {
        return localPath;
      }
      return _readOptionalString(item, 'image_url') ??
          _readOptionalString(item, 'url');
    }
    if (scope == SearchCollectionScope.file) {
      return _readOptionalString(item, 'url');
    }
    return null;
  }

  String _resolvePreviewText(Map<String, dynamic> item) {
    final plainText = _readString(item, 'plain_text');
    if (plainText.isNotEmpty) {
      return plainText;
    }

    final content = _readString(item, 'content');
    final embeddedPlainText = _resolveEmbeddedPlainText(content);
    if (embeddedPlainText.isNotEmpty) {
      return embeddedPlainText;
    }
    if (content.isNotEmpty) {
      return content;
    }
    return _readString(item, 'searchable_word');
  }

  String _resolveEmbeddedPlainText(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty ||
        (!normalized.startsWith('{') && !normalized.startsWith('['))) {
      return '';
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return '';
      }
      final payload = Map<String, dynamic>.from(decoded);
      final plainText = _readString(payload, 'plain_text');
      if (plainText.isNotEmpty) {
        return plainText;
      }
      final card = payload['card'] is Map
          ? Map<String, dynamic>.from(payload['card'] as Map)
          : const <String, dynamic>{};
      final title = _readFirstNonEmpty([card['title'], payload['title']]);
      final body = _readFirstNonEmpty([card['body'], payload['body']]);
      if (title.isEmpty) {
        return body;
      }
      if (body.isEmpty) {
        return title;
      }
      return '$title $body';
    } catch (_) {
      return '';
    }
  }

  String _readFirstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _resolveMemberDisplayName(Map<String, dynamic> item) {
    final remark = _readString(item, 'remark');
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = _readString(item, 'name');
    if (name.isNotEmpty) {
      return name;
    }
    return _readString(item, 'uid');
  }

  int _readInt(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _readString(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    return text;
  }

  String? _readOptionalString(Map<String, dynamic> item, String key) {
    final text = _readString(item, key);
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
}
