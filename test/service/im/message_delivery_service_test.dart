import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/crypto_utils.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/proto/packet.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukong_im_app/service/im/message_delivery_service.dart';
import 'package:wukong_im_app/service/im/message_outbox.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MessageDeliveryService', () {
    test(
      'savePending sends through SDK and marks the outbox record sent',
      () async {
        final db = await openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        await ensureMessageOutboxSchema(db);
        final sender = _FakeMessageDeliverySender();
        final service = MessageDeliveryService(
          databaseReader: () => db,
          sender: sender,
          nowMs: () => 1000,
        );

        final ack = await service.send(
          MessageDeliveryRequest(
            clientMsgNo: 'client-1',
            content: WKTextContent('hello'),
            channel: WKChannel('u_alice', WKChannelType.personal),
            options: WKSendOptions()..expire = 60,
          ),
        );

        expect(ack.clientMsgNo, 'client-1');
        expect(sender.requests, hasLength(1));
        expect(sender.requests.single.clientMsgNo, 'client-1');
        expect(sender.requests.single.options.expire, 60);

        final record = await service.getRecord('client-1');
        expect(record?.state, MessageOutboxState.sent);
        expect(record?.envelope.serverMsgId, 'server-1');
        expect(record?.envelope.messageSeq, 1);
        expect(record?.retryCount, 0);
      },
    );

    test(
      'replayAfterReconnect resends failed records with the original clientMsgNo',
      () async {
        final db = await openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        await ensureMessageOutboxSchema(db);
        final sender = _FakeMessageDeliverySender()
          ..failures.add(StateError('offline'));
        final service = MessageDeliveryService(
          databaseReader: () => db,
          sender: sender,
          nowMs: _incrementingClock(2000),
        );

        await expectLater(
          service.send(
            MessageDeliveryRequest(
              clientMsgNo: 'client-replay',
              content: WKTextContent('queued while offline'),
              channel: WKChannel('g_team', WKChannelType.group),
              options: WKSendOptions()..expire = 120,
            ),
          ),
          throwsA(isA<StateError>()),
        );
        expect(
          (await service.getRecord('client-replay'))?.state,
          MessageOutboxState.failed,
        );

        final coordinator = MessageDeliveryReplayCoordinator(service);
        final ignored = await coordinator.replayForConnectionStatus(
          WKConnectStatus.noNetwork,
        );
        expect(ignored.attempted, 0);

        final result = await coordinator.replayForConnectionStatus(
          WKConnectStatus.syncCompleted,
        );

        expect(result.attempted, 1);
        expect(result.succeeded, 1);
        expect(result.failed, 0);
        expect(
          sender.requests.map((request) => request.clientMsgNo),
          <String>['client-replay', 'client-replay'],
        );
        expect(sender.requests.last.options.expire, 120);
        expect(
          (await service.getRecord('client-replay'))?.state,
          MessageOutboxState.sent,
        );
      },
    );

    test(
      'replayAfterReconnect skips fresh uploading records and recovers stale ones',
      () async {
        final db = await openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        await ensureMessageOutboxSchema(db);
        var now = 5000;
        final sender = _FakeMessageDeliverySender();
        final service = MessageDeliveryService(
          databaseReader: () => db,
          sender: sender,
          nowMs: () => now,
          staleUploadingAfterMs: 100,
        );

        await service.savePending(
          MessageDeliveryRequest(
            clientMsgNo: 'client-uploading',
            content: WKTextContent('in flight'),
            channel: WKChannel('u_inflight', WKChannelType.personal),
            options: WKSendOptions(),
          ),
        );
        await db.update(
          MessageOutboxSchema.tableName,
          <String, Object?>{
            'state': MessageOutboxState.uploading.name,
            'updated_at': now,
          },
          where: 'client_msg_no=?',
          whereArgs: <Object?>['client-uploading'],
        );

        final fresh = await service.replayPending();
        expect(fresh.attempted, 0);
        expect(sender.requests, isEmpty);

        now = 5201;
        final stale = await service.replayPending();
        expect(stale.attempted, 1);
        expect(stale.succeeded, 1);
        expect(sender.requests.single.clientMsgNo, 'client-uploading');
        expect(
          (await service.getRecord('client-uploading'))?.state,
          MessageOutboxState.sent,
        );
      },
    );

    test('SdkMessageDeliverySender waits for SDK send ack before succeeding',
        () async {
      final uid = 'delivery_ack_${DateTime.now().microsecondsSinceEpoch}';
      SharedPreferences.setMockInitialValues(<String, Object>{});
      WKIM.shared.runMode = Model.app;
      WKIM.shared.options = Options.newDefault(uid, 'token');
      CryptoUtils.aesKey = '1234567890123456';
      CryptoUtils.salt = '1234567890123456';
      await WKDBHelper.shared.init();
      addTearDown(WKDBHelper.shared.close);

      WKIM.shared.messageManager.addOnMsgInsertedListener((message) {
        Future<void>.microtask(() {
          WKIM.shared.messageManager.applySendAck(
            SendAckPacket()
              ..clientSeq = message.clientSeq
              ..messageID = 'server-ack'
              ..messageSeq = 99
              ..reasonCode = WKSendMsgResult.sendSuccess,
          );
        });
      });

      final sender = SdkMessageDeliverySender(
        ackTimeout: const Duration(seconds: 1),
      );

      final ack = await sender.send(
        MessageDeliveryRequest(
          clientMsgNo: 'client-sdk-ack',
          content: WKTextContent('wait for ack'),
          channel: WKChannel('u_ack', WKChannelType.personal),
          options: WKSendOptions(),
        ),
      );

      expect(ack.clientMsgNo, 'client-sdk-ack');
      expect(ack.serverMsgId, 'server-ack');
      expect(ack.messageSeq, 99);
    });
  });
}

class _FakeMessageDeliverySender implements MessageDeliverySender {
  final requests = <MessageDeliveryRequest>[];
  final failures = <Object>[];

  @override
  Future<MessageDeliveryAck> send(MessageDeliveryRequest request) async {
    requests.add(request);
    if (failures.isNotEmpty) {
      final failure = failures.removeAt(0);
      throw failure;
    }
    final messageSeq = requests.length;
    return MessageDeliveryAck(
      clientMsgNo: request.clientMsgNo,
      serverMsgId: 'server-$messageSeq',
      messageSeq: messageSeq,
      orderSeq: messageSeq * 1000,
    );
  }
}

int Function() _incrementingClock(int start) {
  var value = start;
  return () => value++;
}
