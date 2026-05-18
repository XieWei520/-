import '../../wukong_robot/models/robot.dart';
import '../../wukong_robot/robot_service.dart';

typedef ChatRobotMenuLoader =
    Future<List<RobotMenu>> Function({
      required String channelId,
      required int channelType,
      required bool forceRefresh,
    });

class ChatRobotMenuStateService {
  ChatRobotMenuStateService({ChatRobotMenuLoader? loadConversationMenus})
    : _loadConversationMenus =
          loadConversationMenus ?? RobotService.instance.syncConversationMenus;

  final ChatRobotMenuLoader _loadConversationMenus;

  Future<List<RobotMenu>> loadMenus({
    required String channelId,
    required int channelType,
    bool forceRefresh = false,
  }) async {
    try {
      final menus = await _loadConversationMenus(
        channelId: channelId,
        channelType: channelType,
        forceRefresh: forceRefresh,
      );
      return List<RobotMenu>.unmodifiable(menus);
    } catch (_) {
      return const <RobotMenu>[];
    }
  }
}
