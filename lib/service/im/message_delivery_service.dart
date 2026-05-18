import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/manager/message_manager.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'message_outbox.dart';

typedef MessageDeliveryDatabaseReader = Database? Function();
typedef MessageDeliveryClock = int Function();

class MessageDeliveryRequest {
  const MessageDeliveryRequest({
    required this.clientMsgNo,
    required this.content,
    required this.channel,
    required this.options,
  });

  final String clientMsgNo;
  final WKMessageContent content;
  final WKChannel channel;
  final WKSendOptions options;

  MessageOutboxRecord toOutboxRecord({required int nowMs}) {
    return MessageOutboxRecord(
      envelope: MessageEnvelope(
        clientMsgNo: clientMsgNo,
        channelId: channel.channelID,
        channelType: channel.channelType,
        serverMsgId: '',
        messageSeq: 0,
        orderSeq: nowMs,
      ),
      state: MessageOutboxState.pending,
      payload: encodeMessageDeliveryPayload(content, options),
      retryCount: 0,
      createdAt: nowMs,
      updatedAt: nowMs,
    );
  }
}

class MessageDeliveryAck {
  const MessageDeliveryAck({
    required this.clientMsgNo,
    this.serverMsgId = '',
    this.messageSeq = 0,
    this.orderSeq = 0,
  });

  final String clientMsgNo;
  final String serverMsgId;
  final int messageSeq;
  final int orderSeq;
}

abstract class MessageDeliverySender {
  Future<MessageDeliveryAck> send(MessageDeliveryRequest request);
}

class SdkMessageDeliverySender implements MessageDeliverySender {
  const SdkMessageDeliverySender({
    this.ackTimeout = const Duration(seconds: 15),
  });

  final Duration ackTimeout;

  @override
  Future<MessageDeliveryAck> send(MessageDeliveryRequest request) async {
    final message = WKMsg()
      ..header = request.options.header
      ..clientMsgNO = request.clientMsgNo;
    if (message.header.noPersist) {
      await WKIM.shared.messageManager.sendWithPreparedMessage(
        message,
        request.content,
        request.channel,
        request.options,
      );
      return MessageDeliveryAck(clientMsgNo: request.clientMsgNo);
    }
    return _sendPersistentMessage(request, message);
  }

  Future<MessageDeliveryAck> _sendPersistentMessage(
    MessageDeliveryRequest request,
    WKMsg message,
  ) async {
    final completer = Completer<WKSendResult>();
    final key =
        'message_delivery_${request.clientMsgNo}_${DateTime.now().microsecondsSinceEpoch}';
    WKIM.shared.messageManager.addOnSendResultListener(key, (result) {
      if (result.message.clientMsgNO == request.clientMsgNo &&
          !completer.isCompleted) {
        completer.complete(result);
      }
    });
    try {
      await WKIM.shared.messageManager.sendWithPreparedMessage(
        message,
        request.content,
        request.channel,
        request.options,
      );
      final result = await completer.future.timeout(ackTimeout);
      final ack = result.ack;
      if (ack.reasonCode != WKSendMsgResult.sendSuccess) {
        throw MessageDeliveryRejectedException(
          clientMsgNo: request.clientMsgNo,
          reasonCode: ack.reasonCode,
        );
      }
      return MessageDeliveryAck(
        clientMsgNo: request.clientMsgNo,
        serverMsgId: ack.messageID,
        messageSeq: ack.messageSeq,
        orderSeq: ack.messageSeq * 1000,
      );
    } on TimeoutException catch (error) {
      throw MessageDeliveryTimeoutException(
        clientMsgNo: request.clientMsgNo,
        timeout: ackTimeout,
      ).._source = error;
    } finally {
      WKIM.shared.messageManager.removeOnSendResultListener(key);
    }
  }
}

class MessageDeliveryTimeoutException implements Exception {
  MessageDeliveryTimeoutException({
    required this.clientMsgNo,
    required this.timeout,
  });

  final String clientMsgNo;
  final Duration timeout;
  TimeoutException? _source;

  @override
  String toString() {
    final sourceMessage = _source == null ? '' : ': ${_source!.message}';
    return 'MessageDeliveryTimeoutException($clientMsgNo, $timeout$sourceMessage)';
  }
}

class MessageDeliveryRejectedException implements Exception {
  const MessageDeliveryRejectedException({
    required this.clientMsgNo,
    required this.reasonCode,
  });

  final String clientMsgNo;
  final int reasonCode;

  @override
  String toString() {
    return 'MessageDeliveryRejectedException($clientMsgNo, reason=$reasonCode)';
  }
}

class MessageDeliveryReplayResult {
  const MessageDeliveryReplayResult({
    required this.attempted,
    required this.succeeded,
    required this.failed,
  });

  final int attempted;
  final int succeeded;
  final int failed;
}

class MessageDeliveryService {
  MessageDeliveryService({
    required MessageDeliveryDatabaseReader databaseReader,
    MessageDeliverySender? sender,
    MessageDeliveryClock? nowMs,
    int staleUploadingAfterMs = 60000,
  }) : _databaseReader = databaseReader,
       _sender = sender ?? const SdkMessageDeliverySender(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _staleUploadingAfterMs = staleUploadingAfterMs;

  final MessageDeliveryDatabaseReader _databaseReader;
  final MessageDeliverySender _sender;
  final MessageDeliveryClock _nowMs;
  final int _staleUploadingAfterMs;
  bool _replayInFlight = false;

  Future<MessageOutboxRecord> savePending(MessageDeliveryRequest request) async {
    final db = _requireDatabase();
    final now = _nowMs();
    final record = request.toOutboxRecord(nowMs: now);
    await db.transaction((txn) async {
      await ensureMessageOutboxSchema(txn);
      await txn.insert(
        MessageOutboxSchema.tableName,
        record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return record;
  }

  Future<MessageDeliveryAck> send(MessageDeliveryRequest request) async {
    await savePending(request);
    await _markUploading(request.clientMsgNo);
    try {
      final ack = await _sender.send(request);
      await markSent(ack);
      return ack;
    } catch (error) {
      await markFailed(request.clientMsgNo);
      rethrow;
    }
  }

  Future<void> markSent(MessageDeliveryAck ack) async {
    final db = _requireDatabase();
    final now = _nowMs();
    await db.transaction((txn) async {
      await ensureMessageOutboxSchema(txn);
      await txn.update(
        MessageOutboxSchema.tableName,
        <String, Object?>{
          'state': MessageOutboxState.sent.name,
          'server_msg_id': ack.serverMsgId,
          'message_seq': ack.messageSeq,
          'order_seq': ack.orderSeq == 0 ? ack.messageSeq * 1000 : ack.orderSeq,
          'updated_at': now,
        },
        where: 'client_msg_no=?',
        whereArgs: <Object?>[ack.clientMsgNo],
      );
    });
  }

  Future<void> markFailed(String clientMsgNo) async {
    final db = _requireDatabase();
    final now = _nowMs();
    await db.transaction((txn) async {
      await ensureMessageOutboxSchema(txn);
      await txn.rawUpdate(
        '''
UPDATE ${MessageOutboxSchema.tableName}
SET state=?, retry_count=retry_count+1, updated_at=?
WHERE client_msg_no=?
''',
        <Object?>[MessageOutboxState.failed.name, now, clientMsgNo],
      );
    });
  }

  Future<MessageDeliveryReplayResult> replayPending({int limit = 50}) async {
    if (_replayInFlight) {
      return const MessageDeliveryReplayResult(
        attempted: 0,
        succeeded: 0,
        failed: 0,
      );
    }
    _replayInFlight = true;
    try {
      final records = await loadReplayable(limit: limit);
      var succeeded = 0;
      var failed = 0;
      for (final record in records) {
        final request = requestFromRecord(record);
        try {
          await _markUploading(record.envelope.clientMsgNo);
          final ack = await _sender.send(request);
          await markSent(ack);
          succeeded++;
        } catch (_) {
          await markFailed(record.envelope.clientMsgNo);
          failed++;
        }
      }
      return MessageDeliveryReplayResult(
        attempted: records.length,
        succeeded: succeeded,
        failed: failed,
      );
    } finally {
      _replayInFlight = false;
    }
  }

  Future<List<MessageOutboxRecord>> loadReplayable({int limit = 50}) async {
    final db = _requireDatabase();
    final staleUploadingBefore = _nowMs() - _staleUploadingAfterMs;
    await ensureMessageOutboxSchema(db);
    final rows = await db.query(
      MessageOutboxSchema.tableName,
      where: '''
state IN (?, ?)
OR (state=? AND updated_at<=?)
''',
      whereArgs: <Object?>[
        MessageOutboxState.pending.name,
        MessageOutboxState.failed.name,
        MessageOutboxState.uploading.name,
        staleUploadingBefore,
      ],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(MessageOutboxRecord.fromRow).toList(growable: false);
  }

  Future<MessageOutboxRecord?> getRecord(String clientMsgNo) async {
    final db = _requireDatabase();
    await ensureMessageOutboxSchema(db);
    final rows = await db.query(
      MessageOutboxSchema.tableName,
      where: 'client_msg_no=?',
      whereArgs: <Object?>[clientMsgNo],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return MessageOutboxRecord.fromRow(rows.single);
  }

  Future<void> _markUploading(String clientMsgNo) async {
    final db = _requireDatabase();
    final now = _nowMs();
    await db.transaction((txn) async {
      await ensureMessageOutboxSchema(txn);
      await txn.update(
        MessageOutboxSchema.tableName,
        <String, Object?>{
          'state': MessageOutboxState.uploading.name,
          'updated_at': now,
        },
        where: 'client_msg_no=?',
        whereArgs: <Object?>[clientMsgNo],
      );
    });
  }

  Database _requireDatabase() {
    final db = _databaseReader();
    if (db == null) {
      throw StateError('Message outbox database is not initialized.');
    }
    return db;
  }
}

class MessageDeliveryReplayCoordinator {
  const MessageDeliveryReplayCoordinator(this._service);

  final MessageDeliveryService _service;

  Future<MessageDeliveryReplayResult> replayForConnectionStatus(
    int connectionStatus, {
    int limit = 50,
  }) {
    if (!_isConnectedStatus(connectionStatus)) {
      return Future<MessageDeliveryReplayResult>.value(
        const MessageDeliveryReplayResult(
          attempted: 0,
          succeeded: 0,
          failed: 0,
        ),
      );
    }
    return _service.replayPending(limit: limit);
  }

  static bool _isConnectedStatus(int status) {
    return status == WKConnectStatus.success ||
        status == WKConnectStatus.syncCompleted;
  }
}

final messageDeliveryServiceProvider = Provider<MessageDeliveryService>((ref) {
  return MessageDeliveryService(
    databaseReader: () => WKDBHelper.shared.getDB(),
  );
});

Map<String, Object?> encodeMessageDeliveryPayload(
  WKMessageContent content,
  WKSendOptions options,
) {
  return <String, Object?>{
    'content_type': content.contentType,
    'content': content.encodeJson(),
    'option': <String, Object?>{
      'expire': options.expire,
      'topic_id': options.topicID,
      'setting': options.setting.encode(),
      'red_dot': options.header.redDot ? 1 : 0,
      'no_persist': options.header.noPersist ? 1 : 0,
      'sync_once': options.header.syncOnce ? 1 : 0,
    },
  };
}

MessageDeliveryRequest requestFromRecord(MessageOutboxRecord record) {
  final payload = record.payload;
  final contentType = _readInt(payload['content_type']);
  final contentJson = Map<String, dynamic>.from(
    (payload['content'] as Map?) ?? const <String, Object?>{},
  );
  final content =
      WKIM.shared.messageManager.getMessageModel(contentType, contentJson) ??
      WKMessageContent().decodeJson(contentJson);
  content.contentType = contentType;
  final optionJson = Map<String, Object?>.from(
    (payload['option'] as Map?) ?? const <String, Object?>{},
  );
  final options = WKSendOptions()
    ..expire = _readInt(optionJson['expire'])
    ..topicID = optionJson['topic_id']?.toString() ?? '';
  options.setting = options.setting.decode(_readInt(optionJson['setting']));
  options.header.redDot = _readBool(optionJson['red_dot'], fallback: true);
  options.header.noPersist = _readBool(optionJson['no_persist']);
  options.header.syncOnce = _readBool(optionJson['sync_once']);

  return MessageDeliveryRequest(
    clientMsgNo: record.envelope.clientMsgNo,
    content: content,
    channel: WKChannel(record.envelope.channelId, record.envelope.channelType),
    options: options,
  );
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value.toInt() != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return fallback;
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
