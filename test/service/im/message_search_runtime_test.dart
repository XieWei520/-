import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/modules/search/data/local_search_service.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    WKDBHelper.shared.close();
  });

  test('chat search finds edited text and shows the edited preview', () async {
    await _setupSdk();

    final message = _buildTextMessage(
      clientMsgNo: 'search_edit_client',
      messageId: 'search_edit_mid',
      channelId: 'search_edit_channel',
      channelType: WKChannelType.personal,
      messageSeq: 11,
      orderSeq: 11000,
      text: 'base-001',
    );
    await WKIM.shared.messageManager.saveMsg(message);

    final editExtra = WKMsgExtra()
      ..messageID = message.messageID
      ..channelID = message.channelID
      ..channelType = message.channelType
      ..editedAt = (DateTime.now().millisecondsSinceEpoch / 1000).truncate()
      ..contentEdit = jsonEncode(<String, dynamic>{
        'type': WkMessageContentType.text,
        'content': 'edit-009',
      });

    await WKIM.shared.messageManager.saveRemoteExtraMsg(<WKMsgExtra>[
      editExtra,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final hits = await LocalSearchService().searchMessages(
      channelId: message.channelID,
      channelType: message.channelType,
      keyword: 'edit-009',
      page: 1,
      limit: 20,
    );

    expect(hits, hasLength(1));
    expect(hits.single.messageId, message.messageID);
    expect(hits.single.previewText, 'edit-009');
  });

  test(
    'chat search still finds legacy edited rows with stale searchable text',
    () async {
      await _setupSdk();

      final message = _buildTextMessage(
        clientMsgNo: 'legacy_search_edit_client',
        messageId: 'legacy_search_edit_mid',
        channelId: 'legacy_search_edit_channel',
        channelType: WKChannelType.personal,
        messageSeq: 12,
        orderSeq: 12000,
        text: 'edit-007',
      );
      await WKIM.shared.messageManager.saveMsg(message);

      final editExtra = WKMsgExtra()
        ..messageID = message.messageID
        ..channelID = message.channelID
        ..channelType = message.channelType
        ..editedAt = (DateTime.now().millisecondsSinceEpoch / 1000).truncate()
        ..contentEdit = jsonEncode(<String, dynamic>{
          'type': WkMessageContentType.text,
          'content': 'edit-008',
        });

      await WKIM.shared.messageManager.saveRemoteExtraMsg(<WKMsgExtra>[
        editExtra,
      ]);
      await MessageDB.shared.updateMsgWithFieldAndClientMsgNo(<String, Object>{
        'searchable_word': 'edit-007',
      }, message.clientMsgNO);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final hits = await LocalSearchService().searchMessages(
        channelId: message.channelID,
        channelType: message.channelType,
        keyword: 'edit-008',
        page: 1,
        limit: 20,
      );

      expect(hits, hasLength(1));
      expect(hits.single.messageId, message.messageID);
      expect(hits.single.previewText, 'edit-008');
    },
  );

  test('chat search returns no rows for an empty keyword', () async {
    await _setupSdk();

    final message = _buildTextMessage(
      clientMsgNo: 'empty_search_client',
      messageId: 'empty_search_mid',
      channelId: 'empty_search_channel',
      channelType: WKChannelType.personal,
      messageSeq: 13,
      orderSeq: 13000,
      text: 'visible message',
    );
    await WKIM.shared.messageManager.saveMsg(message);

    final hits = await LocalSearchService().searchMessages(
      channelId: message.channelID,
      channelType: message.channelType,
      keyword: '   ',
      page: 1,
      limit: 20,
    );

    expect(hits, isEmpty);
  });
}

Future<void> _setupSdk() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final options = wk.Options.newDefault(
    'message_search_runtime_${DateTime.now().microsecondsSinceEpoch}',
    'token',
  );
  final initialized = await WKIM.shared.setup(options);
  expect(initialized, isTrue);
}

WKMsg _buildTextMessage({
  required String clientMsgNo,
  required String messageId,
  required String channelId,
  required int channelType,
  required int messageSeq,
  required int orderSeq,
  required String text,
}) {
  final msg = WKMsg();
  msg.clientMsgNO = clientMsgNo;
  msg.messageID = messageId;
  msg.messageSeq = messageSeq;
  msg.orderSeq = orderSeq;
  msg.channelID = channelId;
  msg.channelType = channelType;
  msg.fromUID = 'u_sender';
  msg.timestamp = 1713000000 + messageSeq;
  msg.contentType = WkMessageContentType.text;
  msg.content = jsonEncode(<String, dynamic>{
    'type': WkMessageContentType.text,
    'content': text,
  });
  msg.messageContent = WKTextContent(text);
  msg.status = WKSendMsgResult.sendSuccess;
  return msg;
}
