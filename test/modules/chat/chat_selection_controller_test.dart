import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_selection_controller.dart';

void main() {
  test('selection controller toggles identities and exposes batch availability',
      () {
    final controller = ChatSelectionController();
    addTearDown(controller.dispose);

    controller.toggle('mid:1');
    controller.toggle('mid:2');

    expect(controller.state.selectedIdentities, <String>{'mid:1', 'mid:2'});
    expect(controller.state.canForward, isTrue);
    expect(controller.state.canFavorite, isFalse);
    expect(controller.state.selectedCount, 2);

    controller.toggle('mid:1');

    expect(controller.state.selectedIdentities, <String>{'mid:2'});
    expect(controller.state.canFavorite, isTrue);
  });
}
