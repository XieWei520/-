import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/common/crypto_utils.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/manager/message_manager.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/proto/packet.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WKMessageManager outbox send identity', () {
    late String uid;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      uid = 'message_outbox_${DateTime.now().microsecondsSinceEpoch}';
      WKIM.shared.runMode = Model.app;
      WKIM.shared.options = Options.newDefault(uid, 'token');
      CryptoUtils.aesKey = '1234567890123456';
      CryptoUtils.salt = '1234567890123456';
      await _deleteDatabaseForUid(uid);
      final initResult = await WKDBHelper.shared.init();
      expect(initResult, isTrue);
    });

    tearDown(() async {
      WKDBHelper.shared.close();
      await _deleteDatabaseForUid(uid);
    });

    test('sendWithClientMsgNo persists the caller supplied clientMsgNo',
        () async {
      WKMsg? inserted;
      WKIM.shared.messageManager.addOnMsgInsertedListener((message) {
        inserted = message;
      });

      final sent = await WKIM.shared.messageManager.sendWithClientMsgNo(
        WKTextContent('hello outbox'),
        WKChannel('u_alice', WKChannelType.personal),
        WKSendOptions()..expire = 60,
        'client-outbox-1',
      );

      expect(sent.clientMsgNO, 'client-outbox-1');
      expect(inserted?.clientMsgNO, 'client-outbox-1');
      expect(inserted?.expireTime, 60);
    });

    test('applySendAck emits send result with local clientMsgNo', () async {
      WKSendResult? result;
      WKIM.shared.messageManager.addOnSendResultListener(
        'outbox_test_send_result',
        (value) {
          result = value;
        },
      );
      addTearDown(
        () => WKIM.shared.messageManager.removeOnSendResultListener(
          'outbox_test_send_result',
        ),
      );

      final sent = await WKIM.shared.messageManager.sendWithClientMsgNo(
        WKTextContent('hello ack'),
        WKChannel('u_bob', WKChannelType.personal),
        WKSendOptions(),
        'client-outbox-ack',
      );

      await WKIM.shared.messageManager.applySendAck(
        SendAckPacket()
          ..clientSeq = sent.clientSeq
          ..messageID = 'server-outbox-ack'
          ..messageSeq = 8
          ..reasonCode = WKSendMsgResult.sendSuccess,
      );

      expect(result?.message.clientMsgNO, 'client-outbox-ack');
      expect(result?.message.messageID, 'server-outbox-ack');
      expect(result?.ack.messageSeq, 8);
    });
  });
}

Future<void> _deleteDatabaseForUid(String uid) async {
  final databasesPath = await getDatabasesPath();
  final dbPath = p.join(databasesPath, 'wk_$uid.db');
  if (File(dbPath).existsSync()) {
    await deleteDatabase(dbPath);
  }
}
