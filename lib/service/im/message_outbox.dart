import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class MessageEnvelope {
  const MessageEnvelope({
    required this.clientMsgNo,
    required this.channelId,
    required this.channelType,
    required this.serverMsgId,
    required this.messageSeq,
    required this.orderSeq,
  });

  final String clientMsgNo;
  final String channelId;
  final int channelType;
  final String serverMsgId;
  final int messageSeq;
  final int orderSeq;

  MessageEnvelope withServerAck({
    required String serverMsgId,
    required int messageSeq,
    int? orderSeq,
  }) {
    return MessageEnvelope(
      clientMsgNo: clientMsgNo,
      channelId: channelId,
      channelType: channelType,
      serverMsgId: serverMsgId.trim(),
      messageSeq: messageSeq,
      orderSeq: orderSeq ?? messageSeq * 1000,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessageEnvelope &&
        other.clientMsgNo == clientMsgNo &&
        other.channelId == channelId &&
        other.channelType == channelType &&
        other.serverMsgId == serverMsgId &&
        other.messageSeq == messageSeq &&
        other.orderSeq == orderSeq;
  }

  @override
  int get hashCode => Object.hash(
    clientMsgNo,
    channelId,
    channelType,
    serverMsgId,
    messageSeq,
    orderSeq,
  );
}

enum MessageOutboxState { pending, uploading, sent, failed }

class MessageOutboxRecord {
  const MessageOutboxRecord({
    required this.envelope,
    required this.state,
    required this.payload,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final MessageEnvelope envelope;
  final MessageOutboxState state;
  final Map<String, Object?> payload;
  final int retryCount;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toRow() {
    return <String, Object?>{
      'client_msg_no': envelope.clientMsgNo,
      'channel_id': envelope.channelId,
      'channel_type': envelope.channelType,
      'server_msg_id': envelope.serverMsgId,
      'message_seq': envelope.messageSeq,
      'order_seq': envelope.orderSeq,
      'payload': jsonEncode(payload),
      'state': state.name,
      'retry_count': retryCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory MessageOutboxRecord.fromRow(Map<String, Object?> row) {
    final rawPayload = row['payload']?.toString() ?? '{}';
    final decoded = jsonDecode(rawPayload);
    return MessageOutboxRecord(
      envelope: MessageEnvelope(
        clientMsgNo: row['client_msg_no']?.toString() ?? '',
        channelId: row['channel_id']?.toString() ?? '',
        channelType: _readInt(row['channel_type']),
        serverMsgId: row['server_msg_id']?.toString() ?? '',
        messageSeq: _readInt(row['message_seq']),
        orderSeq: _readInt(row['order_seq']),
      ),
      state: MessageOutboxState.values.firstWhere(
        (value) => value.name == (row['state']?.toString() ?? ''),
        orElse: () => MessageOutboxState.pending,
      ),
      payload: decoded is Map
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{},
      retryCount: _readInt(row['retry_count']),
      createdAt: _readInt(row['created_at']),
      updatedAt: _readInt(row['updated_at']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessageOutboxRecord &&
        other.envelope == envelope &&
        other.state == state &&
        _mapEquals(other.payload, payload) &&
        other.retryCount == retryCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    envelope,
    state,
    jsonEncode(payload),
    retryCount,
    createdAt,
    updatedAt,
  );
}

class MessageOutboxSchema {
  const MessageOutboxSchema._();

  static const String tableName = 'message_outbox';
  static const String clientMsgNoIndex = 'idx_message_outbox_client_msg_no';
  static const String channelOrderIndex = 'idx_message_outbox_channel_order';
  static const String stateUpdatedIndex = 'idx_message_outbox_state_updated';

  static const List<String> statements = <String>[
    '''
CREATE TABLE IF NOT EXISTS message_outbox (
  client_msg_no TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  channel_type INTEGER NOT NULL,
  server_msg_id TEXT NOT NULL DEFAULT '',
  message_seq INTEGER NOT NULL DEFAULT 0,
  order_seq INTEGER NOT NULL DEFAULT 0,
  payload TEXT NOT NULL DEFAULT '{}',
  state TEXT NOT NULL DEFAULT 'pending',
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0
)
''',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_message_outbox_client_msg_no ON message_outbox(client_msg_no)',
    'CREATE INDEX IF NOT EXISTS idx_message_outbox_channel_order ON message_outbox(channel_id, channel_type, order_seq DESC)',
    'CREATE INDEX IF NOT EXISTS idx_message_outbox_state_updated ON message_outbox(state, updated_at)',
  ];
}

Future<void> ensureMessageOutboxSchema(DatabaseExecutor executor) async {
  for (final statement in MessageOutboxSchema.statements) {
    await executor.execute(statement);
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _mapEquals(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
