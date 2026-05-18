import 'package:flutter_test/flutter_test.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  tearDown(() {
    WKIM.shared.runMode = Model.app;
  });

  test('web mode conversation sync completes without local database callback',
      () async {
    WKIM.shared.runMode = Model.web;
    var completed = false;

    await WKIM.shared.conversationManager.setSyncConversation(() {
      completed = true;
    });

    expect(completed, isTrue);
  });
}
