import 'dart:convert';

import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';

typedef ChannelSearchCallback =
    Future<List<WKChannelSearchResult>> Function(String keyword);
typedef FollowedUserSearchCallback =
    Future<List<WKChannel>> Function(String keyword, int channelType, int follow);
typedef GlobalMessageSearchCallback =
    Future<List<WKMessageSearchResult>> Function(String keyword);
typedef ChannelMessageSearchCallback =
    Future<List<WKMsg>> Function(String keyword, String channelId, int channelType);

class LocalSearchService {
  LocalSearchService({
    ChannelSearchCallback? searchChannels,
    FollowedUserSearchCallback? searchFollowedUsers,
    GlobalMessageSearchCallback? searchGlobalMessages,
    ChannelMessageSearchCallback? searchMessagesWithChannel,
  }) : _searchChannels =
           searchChannels ?? ((keyword) => WKIM.shared.channelManager.search(keyword)),
       _searchFollowedUsers =
           searchFollowedUsers ??
           ((keyword, channelType, follow) => WKIM.shared.channelManager
               .searchWithChannelTypeAndFollow(keyword, channelType, follow)),
       _searchGlobalMessages =
           searchGlobalMessages ??
           ((keyword) => WKIM.shared.messageManager.search(keyword)),
       _searchMessagesWithChannel =
           searchMessagesWithChannel ??
           ((keyword, channelId, channelType) => WKIM.shared.messageManager
               .searchWithChannel(keyword, channelId, channelType));

  final ChannelSearchCallback _searchChannels;
  final FollowedUserSearchCallback _searchFollowedUsers;
  final GlobalMessageSearchCallback _searchGlobalMessages;
  final ChannelMessageSearchCallback _searchMessagesWithChannel;

  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return const GlobalSearchSnapshot();
    }

    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final includeDirectoryResults = safePage == 1;
    final users = includeDirectoryResults
        ? await _loadUsers(trimmedKeyword)
        : const <SearchMemberHit>[];
    final groups = includeDirectoryResults
        ? await _loadGroups(trimmedKeyword)
        : const <SearchMessageHit>[];

    final globalMessageResults = await _searchGlobalMessages(trimmedKeyword);
    final start = (safePage - 1) * safeLimit;
    if (start >= globalMessageResults.length) {
      return GlobalSearchSnapshot(users: users, groups: groups);
    }

    final end = start + safeLimit > globalMessageResults.length
        ? globalMessageResults.length
        : start + safeLimit;
    final pageResults = globalMessageResults.sublist(start, end);
    final messageHits = <SearchMessageHit>[];
    for (final result in pageResults) {
      final mapped = await _mapGlobalMessageAggregate(
        trimmedKeyword,
        result,
      );
      if (mapped != null) {
        messageHits.add(mapped);
      }
    }

    return GlobalSearchSnapshot(
      users: users,
      groups: groups,
      messages: messageHits.toList(growable: false),
    );
  }

  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return const <SearchMessageHit>[];
    }

    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final messages = await _searchMessagesWithChannel(
      trimmedKeyword,
      channelId,
      channelType,
    );
    if (messages.isEmpty) {
      return const <SearchMessageHit>[];
    }

    final mapped = messages
        .map((message) => _mapChannelMessageHit(message))
        .toList(growable: false);
    final start = (safePage - 1) * safeLimit;
    if (start >= mapped.length) {
      return const <SearchMessageHit>[];
    }
    final end = start + safeLimit > mapped.length
        ? mapped.length
        : start + safeLimit;
    return mapped.sublist(start, end);
  }

  Future<List<SearchMemberHit>> _loadUsers(String keyword) async {
    final users = await _searchFollowedUsers(
      keyword,
      WKChannelType.personal,
      1,
    );
    return users
        .map(
          (channel) => SearchMemberHit(
            uid: channel.channelID,
            displayName: _resolveChannelTitle(channel),
            avatarUrl: channel.avatar.isEmpty ? null : channel.avatar,
          ),
        )
        .where((user) => user.uid.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<SearchMessageHit>> _loadGroups(String keyword) async {
    final groups = await _searchChannels(keyword);
    return groups
        .map((result) {
          final channel = result.channel;
          if (channel == null || channel.channelID.isEmpty) {
            return null;
          }
          final containMemberName = result.containMemberName.trim();
          return SearchMessageHit(
            channelId: channel.channelID,
            channelType: channel.channelType,
            messageSeq: 0,
            orderSeq: 0,
            timestamp: 0,
            contentType: 0,
            fromUid: '',
            fromName: '',
            previewText: containMemberName.isEmpty
                ? ''
                : 'Contains: $containMemberName',
            channelName: _resolveChannelTitle(channel),
          );
        })
        .whereType<SearchMessageHit>()
        .toList(growable: false);
  }

  Future<SearchMessageHit?> _mapGlobalMessageAggregate(
    String keyword,
    WKMessageSearchResult result,
  ) async {
    final channel = result.channel;
    if (channel == null || channel.channelID.isEmpty) {
      return null;
    }

    final matchCount = result.messageCount <= 0 ? 1 : result.messageCount;
    if (matchCount == 1) {
      final matches = await _searchMessagesWithChannel(
        keyword,
        channel.channelID,
        channel.channelType,
      );
      if (matches.isNotEmpty) {
        return _mapChannelMessageHit(
          matches.first,
          matchCount: 1,
          fallbackChannelName: _resolveChannelTitle(channel),
        );
      }
    }

    return SearchMessageHit(
      channelId: channel.channelID,
      channelType: channel.channelType,
      messageSeq: 0,
      orderSeq: 0,
      timestamp: 0,
      contentType: 0,
      fromUid: '',
      fromName: '',
      previewText: result.searchableWord.trim(),
      channelName: _resolveChannelTitle(channel),
      matchCount: matchCount,
    );
  }

  SearchMessageHit _mapChannelMessageHit(
    WKMsg message, {
    int matchCount = 1,
    String? fallbackChannelName,
  }) {
    final primaryChannelName = _resolveChannelTitle(message.getChannelInfo());
    final secondaryChannelName = fallbackChannelName?.trim() ?? '';
    final resolvedChannelName = primaryChannelName.isNotEmpty
        ? primaryChannelName
        : (secondaryChannelName.isNotEmpty
              ? secondaryChannelName
              : message.channelID);
    return SearchMessageHit(
      channelId: message.channelID,
      channelType: message.channelType,
      messageSeq: message.messageSeq,
      orderSeq: message.orderSeq,
      timestamp: message.timestamp,
      contentType: message.contentType,
      fromUid: message.fromUID,
      fromName: _resolveSenderName(message),
      previewText: _resolvePreviewText(message),
      channelName: resolvedChannelName,
      messageId: message.messageID.isEmpty ? null : message.messageID,
      clientMsgNo: message.clientMsgNO.isEmpty ? null : message.clientMsgNO,
      matchCount: matchCount,
    );
  }

  String _resolveSenderName(WKMsg message) {
    final member = message.getMemberOfFrom();
    final memberRemark = member?.memberRemark.trim() ?? '';
    if (memberRemark.isNotEmpty) {
      return memberRemark;
    }
    final memberName = member?.memberName.trim() ?? '';
    if (memberName.isNotEmpty) {
      return memberName;
    }

    final fromChannel = message.getFrom();
    final fromRemark = fromChannel?.channelRemark.trim() ?? '';
    if (fromRemark.isNotEmpty) {
      return fromRemark;
    }
    final fromName = fromChannel?.channelName.trim() ?? '';
    if (fromName.isNotEmpty) {
      return fromName;
    }
    return message.fromUID;
  }

  String _resolvePreviewText(WKMsg message) {
    final editedDisplayText =
        message.wkMsgExtra?.messageContent?.displayText().trim() ?? '';
    if (editedDisplayText.isNotEmpty) {
      return editedDisplayText;
    }
    final editedText = _resolveEditedText(message.wkMsgExtra?.contentEdit);
    if (editedText.isNotEmpty) {
      return editedText;
    }
    final displayText = message.messageContent?.displayText().trim() ?? '';
    if (displayText.isNotEmpty) {
      return displayText;
    }
    final searchableWord = message.searchableWord.trim();
    if (searchableWord.isNotEmpty) {
      return searchableWord;
    }
    return message.content.trim();
  }

  String _resolveEditedText(String? contentEdit) {
    final normalized = contentEdit?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        final editedText = decoded['content']?.toString().trim() ?? '';
        if (editedText.isNotEmpty) {
          return editedText;
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  String _resolveChannelTitle(WKChannel? channel) {
    if (channel == null) {
      return '';
    }
    final remark = channel.channelRemark.trim();
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = channel.channelName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return channel.channelID;
  }
}
