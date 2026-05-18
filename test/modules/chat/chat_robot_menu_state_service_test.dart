import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_robot_menu_state_service.dart';
import 'package:wukong_im_app/wukong_robot/models/robot.dart';

void main() {
  test('loads robot menus for the current conversation', () async {
    final calls = <String>[];
    final service = ChatRobotMenuStateService(
      loadConversationMenus:
          ({
            required channelId,
            required channelType,
            required forceRefresh,
          }) async {
            calls.add('$channelId:$channelType:$forceRefresh');
            return const <RobotMenu>[
              RobotMenu(
                robotId: 'bot-a',
                cmd: 'wave',
                remark: 'Wave hello',
                type: 'text',
              ),
            ];
          },
    );

    final menus = await service.loadMenus(
      channelId: 'room-a',
      channelType: 2,
      forceRefresh: true,
    );

    expect(calls, <String>['room-a:2:true']);
    expect(menus, hasLength(1));
    expect(menus.single.cmd, 'wave');
  });

  test('returns an empty menu list when sync fails', () async {
    final service = ChatRobotMenuStateService(
      loadConversationMenus:
          ({
            required channelId,
            required channelType,
            required forceRefresh,
          }) async {
            throw StateError('offline');
          },
    );

    final menus = await service.loadMenus(channelId: 'room-a', channelType: 2);

    expect(menus, isEmpty);
  });
}
