import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';
import 'package:wukong_im_app/modules/chat/chat_search_coordinator.dart';
import 'package:wukong_im_app/modules/chat/chat_search_mode_controller.dart';

void main() {
  test('open enters scene search mode with the current viewport anchor', () {
    final searchController = ChatSearchModeController();
    final sceneController = ChatSceneController();
    var firstVisibleOrderSeq = 42;
    final coordinator = ChatSearchCoordinator(
      readFirstVisibleOrderSeq: () => firstVisibleOrderSeq,
      searchModeController: searchController,
      sceneController: sceneController,
    );

    coordinator.open();

    expect(searchController.state.isActive, isTrue);
    expect(searchController.state.anchorOrderSeq, 42);
    expect(sceneController.state.mode, ChatSceneMode.searching);
    expect(sceneController.state.searchAnchorOrderSeq, 42);

    firstVisibleOrderSeq = 88;
    coordinator.open();

    expect(searchController.state.anchorOrderSeq, 88);
    expect(sceneController.state.searchAnchorOrderSeq, 88);
  });

  test('close deactivates search mode and restores the normal scene', () {
    final searchController = ChatSearchModeController();
    final sceneController = ChatSceneController();
    final coordinator = ChatSearchCoordinator(
      readFirstVisibleOrderSeq: () => 7,
      searchModeController: searchController,
      sceneController: sceneController,
    );

    coordinator.open();
    searchController.updateKeyword('hello');
    sceneController.updateSearchKeyword('hello');

    coordinator.close();

    expect(searchController.state.isActive, isFalse);
    expect(sceneController.state.mode, ChatSceneMode.normal);
    expect(sceneController.state.searchAnchorOrderSeq, 0);
    expect(sceneController.state.searchKeyword, isEmpty);
  });
}
