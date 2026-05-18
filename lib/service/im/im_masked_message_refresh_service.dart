import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'im_word_runtime_filter_service.dart';

typedef ImDatabaseReadyChecker = Future<bool> Function();
typedef ImTextMessageClientMsgNoLoader = Future<List<String>> Function();
typedef ImMessageByClientMsgNoLoader =
    Future<WKMsg?> Function(String clientMsgNo);
typedef ImMessageRefreshPublisher = void Function(WKMsg message);
typedef ImDatabaseReader = Database? Function();

class ImMaskedMessageRefreshService {
  ImMaskedMessageRefreshService({
    required this.wordRuntimeFilterService,
    ImDatabaseReadyChecker? ensureDatabaseReady,
    ImTextMessageClientMsgNoLoader? loadTextMessageClientMsgNos,
    ImMessageByClientMsgNoLoader? loadMessageByClientMsgNo,
    ImMessageRefreshPublisher? publishMessageRefresh,
    ImDatabaseReader? databaseReader,
  }) : _ensureDatabaseReady = ensureDatabaseReady ?? _defaultDatabaseReady,
       _loadTextMessageClientMsgNos =
           loadTextMessageClientMsgNos ??
           (() => _loadTextMessageClientMsgNosFromDatabase(databaseReader)),
       _loadMessageByClientMsgNo =
           loadMessageByClientMsgNo ?? MessageDB.shared.queryWithClientMsgNo,
       _publishMessageRefresh =
           publishMessageRefresh ?? WKIM.shared.messageManager.setRefreshMsg;

  final ImWordRuntimeFilterService wordRuntimeFilterService;
  final ImDatabaseReadyChecker _ensureDatabaseReady;
  final ImTextMessageClientMsgNoLoader _loadTextMessageClientMsgNos;
  final ImMessageByClientMsgNoLoader _loadMessageByClientMsgNo;
  final ImMessageRefreshPublisher _publishMessageRefresh;

  Future<void> refreshAfterProhibitWordSync() async {
    if (!await _ensureDatabaseReady()) {
      return;
    }

    final clientMsgNos = await _loadTextMessageClientMsgNos();
    for (final rawClientMsgNo in clientMsgNos) {
      final clientMsgNo = rawClientMsgNo.trim();
      if (clientMsgNo.isEmpty) {
        continue;
      }

      final message = await _loadMessageByClientMsgNo(clientMsgNo);
      if (message == null) {
        continue;
      }

      final changed = wordRuntimeFilterService.applyProhibitWordsToMessage(
        message,
      );
      if (changed) {
        _publishMessageRefresh(message);
      }
    }
  }

  static Future<bool> _defaultDatabaseReady() async {
    return WKDBHelper.shared.getDB() != null;
  }

  static Future<List<String>> _loadTextMessageClientMsgNosFromDatabase(
    ImDatabaseReader? databaseReader,
  ) async {
    final db = databaseReader?.call() ?? WKDBHelper.shared.getDB();
    if (db == null) {
      return const <String>[];
    }

    final rows = await db.query(
      WKDBConst.tableMessage,
      columns: const <String>['client_msg_no'],
      where: 'type=? AND is_deleted=0',
      whereArgs: const <Object>[WkMessageContentType.text],
    );
    return rows
        .map((row) => row['client_msg_no']?.toString().trim() ?? '')
        .toList(growable: false);
  }
}
