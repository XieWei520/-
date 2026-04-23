import 'dart:convert';

class SessionEventFrame {
  const SessionEventFrame({
    required this.eventId,
    required this.userSeq,
    required this.serverTs,
    required this.kind,
    required this.aggregateId,
    required this.payload,
  });

  factory SessionEventFrame.fromJson(Map<String, dynamic> json) {
    return SessionEventFrame(
      eventId: _readString(json['event_id']),
      userSeq: _readInt(json['user_seq']),
      serverTs: _readServerTs(json),
      kind: _readString(json['kind']),
      aggregateId: _readString(json['aggregate_id']),
      payload: _decodePayload(json['payload']),
    );
  }

  final String eventId;
  final int userSeq;
  final int serverTs;
  final String kind;
  final String aggregateId;
  final Map<String, dynamic> payload;

  static String _readString(dynamic value) {
    final resolved = value?.toString().trim() ?? '';
    if (resolved.isEmpty) {
      throw const FormatException('Session event is missing a required string.');
    }
    return resolved;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null) {
      throw const FormatException('Session event is missing a required int.');
    }
    return parsed;
  }

  static int _readServerTs(Map<String, dynamic> json) {
    final rawServerTs = json['server_ts'];
    if (rawServerTs != null) {
      return _readInt(rawServerTs);
    }
    final createdAt = json['created_at']?.toString().trim() ?? '';
    if (createdAt.isEmpty) {
      return 0;
    }
    return DateTime.parse(createdAt).toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  static Map<String, dynamic> _decodePayload(dynamic rawPayload) {
    if (rawPayload == null) {
      return const <String, dynamic>{};
    }
    if (rawPayload is Map<String, dynamic>) {
      return rawPayload;
    }
    if (rawPayload is Map) {
      return Map<String, dynamic>.from(rawPayload);
    }
    if (rawPayload is String) {
      final normalized = rawPayload.trim();
      if (normalized.isEmpty) {
        return const <String, dynamic>{};
      }
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{'value': decoded};
    }
    return <String, dynamic>{'value': rawPayload};
  }
}
