import '../domain/search_models.dart';

class SearchLocateResolver {
  const SearchLocateResolver();

  ChatLocateIntent fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    return ChatLocateIntent.fromSearchHit(
      hit,
      highlightKeyword: highlightKeyword,
      source: source,
    );
  }

  ChatLocateIntent fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    String? channelName,
    required String source,
  }) {
    return ChatLocateIntent.fromDateCell(
      cell: cell,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      source: source,
    );
  }
}
