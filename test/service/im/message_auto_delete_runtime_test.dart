
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/conversation.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
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

  test(
    'queryExpiredMessages returns only undeleted expired rows in order',
    () async {
      await _setupSdk(expireInterval: const Duration(days: 1));

      final expiredOlder = _buildMsg(
        clientMsgNo: 'expired_older',
        channelId: 'group_query',
        channelType: WKChannelType.group,
        messageSeq: 1,
        orderSeq: 1000,
        timestamp: 100,
        expireTimestamp: 150,
      );
      final expiredNewer = _buildMsg(
        clientMsgNo: 'expired_newer',
        channelId: 'group_query',
        channelType: WKChannelType.group,
        messageSeq: 2,
        orderSeq: 2000,
        timestamp: 120,
        expireTimestamp: 180,
      );
      final active = _buildMsg(
        clientMsgNo: 'active',
        channelId: 'group_query',
        channelType: WKChannelType.group,
        messageSeq: 3,
        orderSeq: 3000,
        timestamp: 140,
        expireTimestamp: 400,
      );
      final deletedExpired = _buildMsg(
        clientMsgNo: 'deleted_expired',
        channelId: 'group_query',
        channelType: WKChannelType.group,
        messageSeq: 4,
        orderSeq: 4000,
        timestamp: 160,
        expireTimestamp: 170,
        isDeleted: 1,
      );

      await MessageDB.shared.insert(expiredOlder);
      await MessageDB.shared.insert(expiredNewer);
      await MessageDB.shared.insert(active);
      await MessageDB.shared.insert(deletedExpired);

      final expired = await MessageDB.shared.queryExpiredMessages(
        nowTimestamp: 200,
        limit: 10,
      );

      expect(expired.map((message) => message.clientMsgNO).toList(), <String>[
        expiredOlder.clientMsgNO,
        expiredNewer.clientMsgNO,
      ]);
    },
  );

  test(
    'runExpireMessageCheck deletes expired cover messages and refreshes conversation',
    () async {
      await _setupSdk(expireInterval: const Duration(days: 1));

      final live = _buildMsg(
        clientMsgNo: 'live_cover',
        channelId: 'group_runtime',
        channelType: WKChannelType.group,
        messageSeq: 10,
        orderSeq: 1000,
        timestamp: 100,
      );
      final expiredCover = _buildMsg(
        clientMsgNo: 'expired_cover',
        channelId: 'group_runtime',
        channelType: WKChannelType.group,
        messageSeq: 11,
        orderSeq: 2000,
        timestamp: 120,
        expireTimestamp: 150,
      );

      await MessageDB.shared.insert(live);
      await MessageDB.shared.insert(expiredCover);
      await WKIM.shared.conversationManager.saveWithLiMMsg(live, 0);
      await WKIM.shared.conversationManager.saveWithLiMMsg(expiredCover, 0);

      final deletedClientMsgNos = <String>[];
      WKIM.shared.messageManager.addOnDeleteMsgListener(
        'message_auto_delete_runtime_test',
        deletedClientMsgNos.add,
      );
      addTearDown(() {
        WKIM.shared.messageManager.removeDeleteMsgListener(
          'message_auto_delete_runtime_test',
        );
      });

      final deletedCount = await WKIM.shared.messageManager
          .runExpireMessageCheck(nowTimestamp: 200, limit: 10);

      final expiredAfterDelete = await MessageDB.shared.queryWithClientMsgNo(
        expiredCover.clientMsgNO,
      );
      final liveAfterDelete = await MessageDB.shared.queryWithClientMsgNo(
        live.clientMsgNO,
      );
      final conversation = await ConversationDB.shared.queryMsgByMsgChannelId(
        live.channelID,
        live.channelType,
      );

      expect(deletedCount, 1);
      expect(expiredAfterDelete?.isDeleted, 1);
      expect(liveAfterDelete?.isDeleted, 0);
      expect(conversation?.lastClientMsgNO, live.clientMsgNO);
      expect(deletedClientMsgNos, <String>[expiredCover.clientMsgNO]);
    },
  );

  test(
    'setup auto delete runtime sweeps expired messages on schedule',
    () async {
      await _setupSdk(expireInterval: const Duration(milliseconds: 20));

      final expired = _buildMsg(
        clientMsgNo: 'scheduled_expired',
        channelId: 'group_schedule',
        channelType: WKChannelType.group,
        messageSeq: 21,
        orderSeq: 2100,
        timestamp: 100,
        expireTimestamp: 120,
      );

      await MessageDB.shared.insert(expired);
      await WKIM.shared.conversationManager.saveWithLiMMsg(expired, 0);

      await _waitUntil(() async {
        final row = await MessageDB.shared.queryWithClientMsgNo(
          expired.clientMsgNO,
        );
        return row?.isDeleted == 1;
      });
    },
  );

  test(
    'deleteWithClientMsgNo emits a deleted refresh payload for the active chat',
    () async {
      await _setupSdk(expireInterval: const Duration(days: 1));

      final msg = _buildMsg(
        clientMsgNo: 'local_delete_refresh',
        channelId: 'group_delete_refresh',
        channelType: WKChannelType.group,
        messageSeq: 31,
        orderSeq: 3100,
        timestamp: 100,
      );
      await MessageDB.shared.insert(msg);

      final refreshes = <WKMsg>[];
      WKIM.shared.messageManager.addOnRefreshMsgListener(
        'message_auto_delete_refresh_test',
        refreshes.add,
      );
      addTearDown(() {
        WKIM.shared.messageManager.removeOnRefreshMsgListener(
          'message_auto_delete_refresh_test',
        );
      });

      await WKIM.shared.messageManager.deleteWithClientMsgNo(msg.clientMsgNO);

      final row = await MessageDB.shared.queryWithClientMsgNo(msg.clientMsgNO);

      expect(row?.isDeleted, 1);
      expect(refreshes, hasLength(1));
      expect(refreshes.single.clientMsgNO, msg.clientMsgNO);
      expect(refreshes.single.isDeleted, 1);
    },
  );
}

Future<void> _setupSdk({
  required Duration expireInterval,
  int expireLimit = 50,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final options = wk.Options.newDefault(
    'message_auto_delete_runtime_${DateTime.now().microsecondsSinceEpoch}',
    'token',
  );
  options.expireMsgCheckInterval = expireInterval;
  options.expireMsgLimit = expireLimit;
  final initialized = await WKIM.shared.setup(options);
  expect(initialized, isTrue);
}

WKMsg _buildMsg({
  required String clientMsgNo,
  required String channelId,
  required int channelType,
  required int messageSeq,
  required int orderSeq,
  required int timestamp,
  int? expireTimestamp,
  int isDeleted = 0,
}) {
  final msg = WKMsg();
  msg.clientMsgNO = clientMsgNo;
  msg.messageID = 'mid_$clientMsgNo';
  msg.messageSeq = messageSeq;
  msg.orderSeq = orderSeq;
  msg.channelID = channelId;
  msg.channelType = channelType;
  msg.fromUID = 'u_sender';
  msg.timestamp = timestamp;
  msg.contentType = 1;
  msg.content = '{"type":1,"content":"$clientMsgNo"}';
  msg.status = WKSendMsgResult.sendSuccess;
  msg.isDeleted = isDeleted;
  if (expireTimestamp != null) {
    msg.expireTimestamp = expireTimestamp;
    msg.expireTime = expireTimestamp > timestamp
        ? expireTimestamp - timestamp
        : 1;
  }
  return msg;
}

Future<void> _waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(milliseconds: 400),
  Duration pollInterval = const Duration(milliseconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(pollInterval);
  }
  fail('Condition not satisfied before timeout.');
}
