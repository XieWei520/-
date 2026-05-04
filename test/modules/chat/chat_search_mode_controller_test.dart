import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_search_mode_controller.dart';

void main() {
  test('search mode controller stores and restores anchor order seq', () {
    final controller = ChatSearchModeController();
    addTearDown(controller.dispose);

    controller.open(anchorOrderSeq: 321);
    controller.updateKeyword('hello');

    expect(controller.state.isActive, isTrue);
    expect(controller.state.anchorOrderSeq, 321);
    expect(controller.state.keyword, 'hello');

    controller.close();

    expect(controller.state.isActive, isFalse);
    expect(controller.state.anchorOrderSeq, 321);
    expect(controller.state.keyword, 'hello');
  });
}
