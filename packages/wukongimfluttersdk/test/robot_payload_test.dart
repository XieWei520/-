import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  group('robot payload parity', () {
    setUpAll(() async {
      WKIM.shared.runMode = Model.web;
      await WKIM.shared.setup(Options());
    });

    test('buildSendPayload includes robot_id when content targets a robot', () {
      final content = WKTextContent('/help')..robotID = 'robot-helper';
      final message = WKMsg()
        ..messageContent = content
        ..contentType = WkMessageContentType.text;

      final payload = jsonDecode(
            WKIM.shared.messageManager.buildSendPayload(message),
          )
          as Map<String, dynamic>;

      expect(payload, containsPair('robot_id', 'robot-helper'));
      expect(payload, containsPair('content', '/help'));
    });

    test('getMessageModel restores robot_id from payload json', () {
      final content = WKIM.shared.messageManager.getMessageModel(
        WkMessageContentType.text,
        <String, dynamic>{
          'type': WkMessageContentType.text,
          'content': '/help',
          'robot_id': 'robot-helper',
        },
      );

      expect(content, isA<WKTextContent>());
      expect(content?.robotID, 'robot-helper');
    });
  });
}
