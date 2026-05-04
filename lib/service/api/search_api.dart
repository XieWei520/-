import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/group.dart';
import '../../wukong_base/msg/msg_content_type.dart';
import 'api_client.dart';
import 'group_api.dart';
import 'user_api.dart';

class SearchApi {
  SearchApi._();

  static final SearchApi _instance = SearchApi._();
  static SearchApi get instance => _instance;

  static const _recentSearchesKey = 'recent_searches';
  static const _recentSearchLimit = 10;
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]+>');
  static final RegExp _urlPattern = RegExp(
    r'(https?://\S+|www\.\S+)',
    caseSensitive: false,
  );

  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> globalSearch(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return {
        'users': const <Map<String, dynamic>>[],
        'groups': const <Map<String, dynamic>>[],
        'messages': const <Map<String, dynamic>>[],
      };
    }

    final safePage = page < 1 ? 1 : page;
    var safeLimit = limit;
    if (safeLimit <= 0) {
      safeLimit = 20;
    }
    if (safeLimit > 100) {
      safeLimit = 100;
    }

    final response = await _searchGlobal(
      keyword: keyword,
      onlyMessage: safePage == 1 ? 0 : 1,
      page: safePage,
      limit: safeLimit,
    );
    final normalizedMessages = _aggregateGlobalSearchMessages(
      _normalizeMessages(response['messages']),
    );
    final includeDirectoryResults = safePage == 1;

    return {
      'users': includeDirectoryResults
          ? _normalizeUsers(response['friends'])
          : const <Map<String, dynamic>>[],
      'groups': includeDirectoryResults
          ? _normalizeGroups(response['groups'])
          : const <Map<String, dynamic>>[],
      'messages': normalizedMessages,
    };
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final users = await UserApi.instance.searchUsers(keyword);
    return users.map((user) => user.toJson()).toList();
  }

  Future<List<dynamic>> searchChannels(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final groups = await GroupApi.instance.getMyGroups();
    return groups
        .where((group) {
          final values = [group.name ?? '', group.groupNo, group.remark ?? ''];
          final loweredKeyword = keyword.toLowerCase();
          return values.any(
            (value) => value.toLowerCase().contains(loweredKeyword),
          );
        })
        .map((group) => group.toJson())
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchMessages({
    required String channelId,
    required int channelType,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _searchGlobal(
      keyword: keyword?.trim() ?? '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      page: page,
      limit: pageSize,
    );
    return _normalizeMessages(response['messages']);
  }

  Future<List<String>> getRecentSearches() async {
    return StorageUtils.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> addToRecentSearches(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return;
    }

    final searches = await getRecentSearches();
    final next = [
      keyword,
      ...searches.where((item) => item != keyword),
    ].take(_recentSearchLimit).toList();
    await StorageUtils.setStringList(_recentSearchesKey, next);
  }

  Future<void> clearRecentSearches() async {
    await StorageUtils.remove(_recentSearchesKey);
  }

  Future<List<Map<String, dynamic>>> searchMessagesByDate({
    required String channelId,
    required int channelType,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 50,
  }) async {
    final response = await _searchGlobal(
      keyword: '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
    return _normalizeMessages(response['messages']);
  }

  Future<List<Map<String, dynamic>>> searchMessagesByMember({
    required String channelId,
    required String senderId,
    String? keyword,
    int channelType = WKChannelType.group,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _searchGlobal(
      keyword: keyword?.trim() ?? '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      fromUid: senderId,
      contentTypes: const <int>[
        WkMessageContentType.text,
        WkMessageContentType.file,
        MsgContentType.robotCard,
      ],
      page: page,
      limit: limit,
    );
    return _normalizeMessages(response['messages']);
  }

  Future<List<Map<String, dynamic>>> searchImages({
    required String channelId,
    int? channelType,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _searchGlobal(
      keyword: '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      contentTypes: const <int>[WkMessageContentType.image],
      page: page,
      limit: limit,
    );
    return _normalizeMessages(response['messages'])
        .where(
          (message) => _readString(message, const ['image_url']).isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchFiles({
    required String channelId,
    int? channelType,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _searchGlobal(
      keyword: '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      contentTypes: const <int>[WkMessageContentType.file],
      page: page,
      limit: limit,
    );
    return _normalizeMessages(response['messages']);
  }

  Future<List<Map<String, dynamic>>> searchLinks({
    required String channelId,
    int? channelType,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _searchGlobal(
      keyword: '',
      onlyMessage: 1,
      channelId: channelId,
      channelType: channelType,
      contentTypes: const <int>[
        14,
        WkMessageContentType.text,
        MsgContentType.robotCard,
      ],
      page: page,
      limit: limit,
    );
    return _normalizeMessages(response['messages'])
        .where((message) => _readString(message, const ['link_url']).isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getChannelMembers({
    required String channelId,
  }) async {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final members = await GroupApi.instance.getGroupMembers(
        normalizedChannelId,
      );
      return _normalizeMembers(members);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _searchGlobal({
    required String keyword,
    required int onlyMessage,
    String? channelId,
    int? channelType,
    String? fromUid,
    List<int>? contentTypes,
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final safePage = page < 1 ? 1 : page;
    var safeLimit = limit;
    if (safeLimit <= 0) {
      safeLimit = 20;
    }
    if (safeLimit > 100) {
      safeLimit = 100;
    }
    final normalizedChannelId = channelId?.trim();
    final normalizedFromUid = fromUid?.trim();
    final normalizedContentTypes = contentTypes?.toSet().toList(
      growable: false,
    );

    final request = <String, dynamic>{
      'only_message': onlyMessage,
      'keyword': keyword,
      'page': safePage,
      'limit': safeLimit,
    };
    if ((normalizedChannelId ?? '').isNotEmpty) {
      request['channel_id'] = normalizedChannelId;
    }
    if (channelType != null) {
      request['channel_type'] = channelType;
    }
    if ((normalizedFromUid ?? '').isNotEmpty) {
      request['from_uid'] = normalizedFromUid;
    }
    if ((normalizedContentTypes ?? const <int>[]).isNotEmpty) {
      request['content_type'] = normalizedContentTypes;
    }
    if (startDate != null) {
      request['start_time'] = startDate.millisecondsSinceEpoch ~/ 1000;
    }
    if (endDate != null) {
      request['end_time'] = endDate.millisecondsSinceEpoch ~/ 1000;
    }

    final response = await _client.post(ApiConfig.searchGlobal, data: request);
    _ensureSuccess(response, fallback: 'Search failed');

    final body = _resolveBody(response.data);
    final data = body['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }

  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _resolveBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  List<Map<String, dynamic>> _normalizeUsers(dynamic raw) {
    return _toMapList(raw)
        .map((user) {
          final uid = _firstNonEmpty([user['uid'], user['channel_id']]);
          if (uid.isEmpty) {
            return const <String, dynamic>{};
          }

          final name = _firstNonEmpty([
            user['name'],
            user['channel_name'],
            uid,
          ]);
          final remark = _firstNonEmpty([
            user['remark'],
            user['channel_remark'],
          ]);
          final normalized = <String, dynamic>{
            'uid': uid,
            'name': name,
            'remark': remark,
          };
          final avatar = _firstNonEmpty([user['avatar']]);
          if (avatar.isNotEmpty) {
            normalized['avatar'] = ApiConfig.resolveMediaUrl(avatar);
          }
          return normalized;
        })
        .where((user) => user.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeGroups(dynamic raw) {
    return _toMapList(raw)
        .map((group) {
          final groupNo = _firstNonEmpty([
            group['group_no'],
            group['channel_id'],
          ]);
          if (groupNo.isEmpty) {
            return const <String, dynamic>{};
          }

          final normalized = <String, dynamic>{
            'group_no': groupNo,
            'name': _firstNonEmpty([
              group['name'],
              group['channel_name'],
              groupNo,
            ]),
            'remark': _firstNonEmpty([
              group['remark'],
              group['channel_remark'],
            ]),
          };
          final avatar = _firstNonEmpty([group['avatar']]);
          if (avatar.isNotEmpty) {
            normalized['avatar'] = ApiConfig.resolveMediaUrl(avatar);
          }
          return normalized;
        })
        .where((group) => group.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeMembers(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Object>()
        .map((member) {
          final uid = _firstNonEmpty([
            if (member is GroupMember) member.uid,
            if (member is Map) member['uid'],
          ]);
          if (uid.isEmpty) {
            return const <String, dynamic>{};
          }

          final normalized = <String, dynamic>{
            'uid': uid,
            'name': _firstNonEmpty([
              if (member is GroupMember) member.name,
              if (member is Map) member['name'],
            ]),
            'remark': _firstNonEmpty([
              if (member is GroupMember) member.remark,
              if (member is Map) member['remark'],
            ]),
          };
          final avatar = _firstNonEmpty([
            if (member is GroupMember) member.avatar,
            if (member is Map) member['avatar'],
          ]);
          if (avatar.isNotEmpty) {
            normalized['avatar'] = ApiConfig.resolveMediaUrl(avatar);
          }
          return normalized;
        })
        .where((member) => member.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _normalizeMessages(dynamic raw) {
    final messages = _toMapList(
      raw,
    ).map(_normalizeMessage).toList(growable: false);
    messages.sort(
      (left, right) => _readInt(right, const [
        'timestamp',
      ]).compareTo(_readInt(left, const ['timestamp'])),
    );
    return messages;
  }

  List<Map<String, dynamic>> _aggregateGlobalSearchMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final channelId = _readString(message, const ['channel_id']);
      final channelType = _readInt(message, const ['channel_type']);
      final groupKey = '$channelType:$channelId';
      final preview = _firstNonEmpty([
        message['plain_text'],
        message['searchable_word'],
        message['content'],
      ]);

      if (channelId.isEmpty || channelType <= 0) {
        final rawMessage = Map<String, dynamic>.from(message);
        rawMessage['message_count'] = 1;
        rawMessage['searchable_word'] = preview;
        grouped['raw:${grouped.length}'] = rawMessage;
        continue;
      }

      final existing = grouped[groupKey];
      if (existing == null) {
        final aggregated = Map<String, dynamic>.from(message);
        aggregated['message_count'] = 1;
        aggregated['searchable_word'] = preview;
        grouped[groupKey] = aggregated;
        continue;
      }

      existing['message_count'] =
          _readInt(existing, const ['message_count']) + 1;
      existing['searchable_word'] = _mergeSearchableWord(
        _firstNonEmpty([existing['searchable_word']]),
        preview,
      );
    }
    return grouped.values.toList(growable: false);
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> raw) {
    final payload = _resolveBody(raw['payload']);
    final channel = _resolveBody(raw['channel']);
    final fromChannel = _resolveBody(raw['from_channel']);
    final contentType = _firstInt([payload['type'], raw['content_type']]);
    final mediaUrl = _extractMediaUrl(payload);
    final fileName = _extractFileName(payload);
    final content = _resolvePayloadPreview(payload);
    final plainText = _firstNonEmpty([
      raw['plain_text'],
      raw['plainText'],
      payload['plain_text'],
      payload['plainText'],
      if (payload['content'] is String)
        _resolveEmbeddedPlainText(payload['content'] as String),
    ]);
    final previewContent = plainText.isNotEmpty ? plainText : content;
    final linkUrl = _extractLinkUrl(payload, fallbackText: previewContent);

    final normalized = <String, dynamic>{
      'message_id': _firstNonEmpty([raw['message_id'], raw['message_idstr']]),
      'message_idstr': _firstNonEmpty([
        raw['message_idstr'],
        raw['message_id'],
      ]),
      'message_seq': _firstInt([raw['message_seq']]),
      'order_seq': _firstInt([raw['order_seq']]),
      'client_msg_no': _firstNonEmpty([raw['client_msg_no']]),
      'from_uid': _firstNonEmpty([raw['from_uid']]),
      'from_name': _firstNonEmpty([
        raw['from_name'],
        fromChannel['channel_remark'],
        fromChannel['channel_name'],
        raw['from_uid'],
      ]),
      'timestamp': _firstInt([raw['timestamp']]),
      'channel_id': _firstNonEmpty([raw['channel_id'], channel['channel_id']]),
      'channel_type': _firstInt([raw['channel_type'], channel['channel_type']]),
      'channel_name': _firstNonEmpty([
        raw['channel_name'],
        channel['channel_remark'],
        channel['channel_name'],
      ]),
      'channel_remark': _firstNonEmpty([channel['channel_remark']]),
      'content_type': contentType,
      'content': previewContent,
      'payload': payload,
      'channel': channel,
      'from_channel': fromChannel,
    };
    if (plainText.isNotEmpty) {
      normalized['plain_text'] = plainText;
    }

    if (mediaUrl.isNotEmpty) {
      normalized['url'] = mediaUrl;
      if (contentType == WkMessageContentType.image) {
        normalized['image_url'] = mediaUrl;
      }
    }
    if (fileName.isNotEmpty) {
      normalized['file_name'] = fileName;
    }
    if (linkUrl.isNotEmpty) {
      normalized['link_url'] = linkUrl;
    }

    return normalized;
  }

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  String _resolvePayloadPreview(Map<String, dynamic> payload) {
    final plainText = _firstNonEmpty([
      payload['plain_text'],
      payload['plainText'],
    ]);
    if (plainText.isNotEmpty) {
      return plainText;
    }

    final content = payload['content'];
    if (content is String && content.trim().isNotEmpty) {
      final embeddedPlainText = _resolveEmbeddedPlainText(content);
      if (embeddedPlainText.isNotEmpty) {
        return embeddedPlainText;
      }
      return _stripMarkup(content);
    }
    if (content is Map) {
      final nested = _resolveBody(content);
      final nestedText = _firstNonEmpty([
        nested['content'],
        nested['text'],
        nested['name'],
        nested['title'],
        nested['url'],
      ]);
      if (nestedText.isNotEmpty) {
        return nestedText;
      }
    }

    final contentType = _firstInt([payload['type']]);
    switch (contentType) {
      case MsgContentType.robotCard:
        final card = payload['card'] is Map
            ? Map<String, dynamic>.from(payload['card'] as Map)
            : const <String, dynamic>{};
        final title = _firstNonEmpty([card['title'], payload['title']]);
        final body = _firstNonEmpty([card['body'], payload['body']]);
        if (title.isEmpty) {
          return body;
        }
        if (body.isEmpty) {
          return title;
        }
        return '$title $body';
      case WkMessageContentType.image:
        return '[\u56fe\u7247]';
      case WkMessageContentType.voice:
        return '[\u8bed\u97f3]';
      case WkMessageContentType.video:
        return '[\u89c6\u9891]';
      case WkMessageContentType.location:
        final title = _firstNonEmpty([payload['title']]);
        return title.isEmpty ? '[\u4f4d\u7f6e]' : '[\u4f4d\u7f6e] $title';
      case WkMessageContentType.file:
        final fileName = _extractFileName(payload);
        return fileName.isEmpty ? '[\u6587\u4ef6]' : '[\u6587\u4ef6] $fileName';
      case WkMessageContentType.card:
        final name = _firstNonEmpty([payload['name']]);
        return name.isEmpty ? '[\u540d\u7247]' : '[\u540d\u7247] $name';
      default:
        return _firstNonEmpty([
          payload['name'],
          payload['title'],
          payload['url'],
        ]);
    }
  }

  String _extractMediaUrl(Map<String, dynamic> payload) {
    final localPath = _firstNonEmpty([
      payload['localPath'],
      payload['local_path'],
    ]);
    if (localPath.isNotEmpty) {
      return localPath;
    }

    final remoteUrl = _firstNonEmpty([payload['url']]);
    if (remoteUrl.isEmpty) {
      return '';
    }
    return ApiConfig.resolveMediaUrl(remoteUrl);
  }

  String _extractFileName(Map<String, dynamic> payload) {
    return _firstNonEmpty([
      payload['name'],
      payload['file_name'],
      payload['filename'],
      payload['title'],
    ]);
  }

  String _extractLinkUrl(
    Map<String, dynamic> payload, {
    required String fallbackText,
  }) {
    final card = payload['card'] is Map
        ? Map<String, dynamic>.from(payload['card'] as Map)
        : const <String, dynamic>{};
    final url = _firstNonEmpty([
      payload['url'],
      payload['link_url'],
      payload['linkUrl'],
      card['link_url'],
      card['linkUrl'],
    ]);
    if (_looksLikeUrl(url)) {
      return _normalizeUrl(url);
    }

    final embeddedUrl = payload['content'] is String
        ? _resolveEmbeddedLinkUrl(payload['content'] as String)
        : '';
    if (_looksLikeUrl(embeddedUrl)) {
      return _normalizeUrl(embeddedUrl);
    }

    final title = _firstNonEmpty([
      payload['content'],
      payload['title'],
      fallbackText,
    ]);
    final match = _urlPattern.firstMatch(title);
    if (match == null) {
      return '';
    }
    return _normalizeUrl(match.group(0) ?? '');
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
      final plainText = _firstNonEmpty([
        payload['plain_text'],
        payload['plainText'],
      ]);
      if (plainText.isNotEmpty) {
        return plainText;
      }

      final card = payload['card'] is Map
          ? Map<String, dynamic>.from(payload['card'] as Map)
          : const <String, dynamic>{};
      final title = _firstNonEmpty([card['title'], payload['title']]);
      final body = _firstNonEmpty([card['body'], payload['body']]);
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

  String _resolveEmbeddedLinkUrl(String raw) {
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
      final card = payload['card'] is Map
          ? Map<String, dynamic>.from(payload['card'] as Map)
          : const <String, dynamic>{};
      return _firstNonEmpty([
        payload['url'],
        payload['link_url'],
        payload['linkUrl'],
        card['link_url'],
        card['linkUrl'],
      ]);
    } catch (_) {
      return '';
    }
  }

  bool _looksLikeUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('www.');
  }

  String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (_looksLikeUrl(trimmed)) {
      if (trimmed.toLowerCase().startsWith('www.')) {
        return 'https://$trimmed';
      }
      return trimmed;
    }
    return ApiConfig.resolveMediaUrl(trimmed);
  }

  String _stripMarkup(String value) {
    return value.replaceAll(_htmlTagPattern, '').trim();
  }

  String _mergeSearchableWord(String current, String next) {
    if (next.isEmpty) {
      return current;
    }
    if (current.isEmpty) {
      return next;
    }
    if (current.contains(next)) {
      return current;
    }
    return '$current $next';
  }

  String _firstNonEmpty(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final text = _stripMarkup(candidate.toString());
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  int _firstInt(List<dynamic> candidates, {int fallback = 0}) {
    for (final candidate in candidates) {
      if (candidate is int) {
        return candidate;
      }
      if (candidate is num) {
        return candidate.toInt();
      }
      if (candidate is String) {
        final parsed = int.tryParse(candidate);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) {
        continue;
      }
      final text = _stripMarkup(value.toString());
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }
}
