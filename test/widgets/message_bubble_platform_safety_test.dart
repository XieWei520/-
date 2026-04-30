import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MessageBubble source does not import dart io directly', () {
    final source = File('lib/widgets/message_bubble.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
