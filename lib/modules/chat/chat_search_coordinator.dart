import 'chat_scene_controller.dart';
import 'chat_search_mode_controller.dart';

typedef ChatSearchAnchorReader = int Function();

class ChatSearchCoordinator {
  ChatSearchCoordinator({
    required ChatSearchAnchorReader readFirstVisibleOrderSeq,
    required ChatSearchModeController searchModeController,
    required ChatSceneController sceneController,
  }) : _readFirstVisibleOrderSeq = readFirstVisibleOrderSeq,
       _searchModeController = searchModeController,
       _sceneController = sceneController;

  final ChatSearchAnchorReader _readFirstVisibleOrderSeq;
  final ChatSearchModeController _searchModeController;
  final ChatSceneController _sceneController;

  void open() {
    final anchorOrderSeq = _readFirstVisibleOrderSeq();
    _searchModeController.open(anchorOrderSeq: anchorOrderSeq);
    _sceneController.enterSearchMode(anchorOrderSeq: anchorOrderSeq);
  }

  void close() {
    _searchModeController.close();
    _sceneController.restoreNormal();
  }
}
