import '../../data/models/chat_session.dart';
import '../../wukong_robot/robot_service.dart';

class ChatGifPanelResult {
  const ChatGifPanelResult({
    required this.url,
    required this.width,
    required this.height,
    required this.title,
  });

  final String url;
  final int width;
  final int height;
  final String title;
}

class ChatGifPanelService {
  ChatGifPanelService({RobotService? robotService})
    : _robotService = robotService ?? RobotService.instance;

  final RobotService _robotService;

  Future<List<ChatGifPanelResult>> search(
    String query, {
    required ChatSession session,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <ChatGifPanelResult>[];
    }

    final results = await _robotService.searchGifs(
      query: normalizedQuery,
      username: 'gif',
      channelId: session.channelId,
      channelType: session.channelType,
    );

    return results
        .map(
          (item) => ChatGifPanelResult(
            url: item.contentUrl?.trim() ?? '',
            width: _readInt(item.extraData['width']),
            height: _readInt(item.extraData['height']),
            title: item.title?.trim().isNotEmpty == true
                ? item.title!.trim()
                : item.id.trim(),
          ),
        )
        .where((item) => item.url.isNotEmpty)
        .toList(growable: false);
  }

  int _readInt(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toInt();
    }
    return int.tryParse(rawValue?.toString() ?? '') ?? 0;
  }
}
