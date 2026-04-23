import 'search_models.dart';

abstract class SearchRepository {
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  });

  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  });

  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  });

  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  });

  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  });

  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  });
}

class GlobalSearchSnapshot {
  const GlobalSearchSnapshot({
    this.users = const <SearchMemberHit>[],
    this.groups = const <SearchMessageHit>[],
    this.messages = const <SearchMessageHit>[],
  });

  final List<SearchMemberHit> users;
  final List<SearchMessageHit> groups;
  final List<SearchMessageHit> messages;
}
