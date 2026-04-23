import 'dart:convert';
import 'dart:typed_data';

import '../session/session_event_frame.dart';

class RealtimeEnvelope {
  const RealtimeEnvelope({
    required this.eventSeq,
    required this.eventType,
    required this.payload,
    required this.ackSeq,
    this.deviceId = '',
    this.issuedAtMs = 0,
  });

  final int eventSeq;
  final String eventType;
  final Uint8List payload;
  final int ackSeq;
  final String deviceId;
  final int issuedAtMs;
}

class ControlProtoCodec {
  static const int _wireVarint = 0;
  static const int _wireFixed64 = 1;
  static const int _wireLengthDelimited = 2;
  static const int _wireFixed32 = 5;
  static final BigInt _maxUint64 = BigInt.parse('18446744073709551615');

  static Uint8List encodeEnvelope({
    required int eventSeq,
    required String eventType,
    required Uint8List payload,
    int ackSeq = 0,
    String? deviceId,
    int? issuedAtMs,
  }) {
    _ensureUint64(value: eventSeq, fieldName: 'event_seq');
    _ensureUint64(value: ackSeq, fieldName: 'ack_seq');
    if (issuedAtMs != null) {
      _ensureUint64(value: issuedAtMs, fieldName: 'issued_at_ms');
    }

    final buffer = BytesBuilder(copy: false);
    _writeVarintField(buffer, 1, eventSeq);
    _writeBytesField(buffer, 2, utf8.encode(eventType.trim()));
    _writeBytesField(buffer, 3, payload);
    _writeVarintField(buffer, 4, ackSeq);
    final normalizedDeviceId = deviceId?.trim() ?? '';
    if (normalizedDeviceId.isNotEmpty) {
      _writeBytesField(buffer, 5, utf8.encode(normalizedDeviceId));
    }
    if (issuedAtMs != null && issuedAtMs > 0) {
      _writeVarintField(buffer, 6, issuedAtMs);
    }
    return buffer.toBytes();
  }

  static RealtimeEnvelope decodeEnvelope(List<int> bytes) {
    final cursor = _ProtoCursor(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    );

    var sawKnownField = false;
    var eventSeq = 0;
    var eventType = '';
    var payload = Uint8List(0);
    var ackSeq = 0;
    var deviceId = '';
    var issuedAtMs = 0;

    while (cursor.hasRemaining) {
      final tag = cursor.readVarint();
      if (tag == 0) {
        throw const FormatException('Encountered protobuf tag 0.');
      }
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x07;

      switch (fieldNumber) {
        case 1:
          if (wireType != _wireVarint) {
            throw const FormatException(
              'event_seq field has invalid wire type.',
            );
          }
          eventSeq = cursor.readVarint();
          sawKnownField = true;
          break;
        case 2:
          if (wireType != _wireLengthDelimited) {
            throw const FormatException(
              'event_type field has invalid wire type.',
            );
          }
          eventType = utf8
              .decode(cursor.readLengthDelimited(), allowMalformed: true)
              .trim();
          sawKnownField = true;
          break;
        case 3:
          if (wireType != _wireLengthDelimited) {
            throw const FormatException('payload field has invalid wire type.');
          }
          payload = cursor.readLengthDelimited();
          sawKnownField = true;
          break;
        case 4:
          if (wireType != _wireVarint) {
            throw const FormatException('ack_seq field has invalid wire type.');
          }
          ackSeq = cursor.readVarint();
          sawKnownField = true;
          break;
        case 5:
          if (wireType != _wireLengthDelimited) {
            throw const FormatException(
              'device_id field has invalid wire type.',
            );
          }
          deviceId = utf8
              .decode(cursor.readLengthDelimited(), allowMalformed: true)
              .trim();
          sawKnownField = true;
          break;
        case 6:
          if (wireType != _wireVarint) {
            throw const FormatException(
              'issued_at_ms field has invalid wire type.',
            );
          }
          issuedAtMs = cursor.readVarint();
          sawKnownField = true;
          break;
        default:
          cursor.skipField(wireType);
      }
    }

    if (!sawKnownField || eventType.isEmpty) {
      throw const FormatException('Invalid protobuf control envelope payload.');
    }

    return RealtimeEnvelope(
      eventSeq: eventSeq,
      eventType: eventType,
      payload: payload,
      ackSeq: ackSeq,
      deviceId: deviceId,
      issuedAtMs: issuedAtMs,
    );
  }

  static SessionEventFrame toSessionEventFrame(RealtimeEnvelope envelope) {
    final payload = _decodePayloadMap(envelope.payload);
    final aggregateId =
        _readStringValue(payload, 'aggregate_id', 'aggregateId') ?? '';
    final issuedAtSeconds = envelope.issuedAtMs > 0
        ? envelope.issuedAtMs ~/ 1000
        : 0;
    final serverTs =
        _readIntValue(payload, 'server_ts', 'serverTs') ?? issuedAtSeconds;
    final eventId =
        _readStringValue(payload, 'event_id', 'eventId') ??
        'proto_${envelope.eventSeq}_${envelope.eventType}';

    return SessionEventFrame(
      eventId: eventId,
      userSeq: envelope.eventSeq,
      serverTs: serverTs,
      kind: envelope.eventType,
      aggregateId: aggregateId,
      payload: payload,
    );
  }

  static Map<String, dynamic> _decodePayloadMap(Uint8List payload) {
    if (payload.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final rawText = utf8.decode(payload);
      final normalized = rawText.trim();
      if (normalized.isEmpty) {
        return const <String, dynamic>{};
      }
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{'value': decoded};
    } catch (_) {
      return <String, dynamic>{'raw_payload_base64': base64Encode(payload)};
    }
  }

  static String? _readStringValue(
    Map<String, dynamic> payload,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    final snakeCaseValue = payload[snakeCaseKey]?.toString().trim() ?? '';
    if (snakeCaseValue.isNotEmpty) {
      return snakeCaseValue;
    }
    final camelCaseValue = payload[camelCaseKey]?.toString().trim() ?? '';
    if (camelCaseValue.isNotEmpty) {
      return camelCaseValue;
    }
    return null;
  }

  static int? _readIntValue(
    Map<String, dynamic> payload,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    final dynamic value = payload.containsKey(snakeCaseKey)
        ? payload[snakeCaseKey]
        : payload[camelCaseKey];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static void _ensureUint64({required int value, required String fieldName}) {
    if (value < 0) {
      throw FormatException('$fieldName must be non-negative.');
    }
    if (BigInt.from(value) > _maxUint64) {
      throw FormatException('$fieldName exceeds uint64 range.');
    }
  }

  static void _writeVarintField(
    BytesBuilder buffer,
    int fieldNumber,
    int value,
  ) {
    _writeTag(buffer, fieldNumber, _wireVarint);
    _writeVarint(buffer, value);
  }

  static void _writeBytesField(
    BytesBuilder buffer,
    int fieldNumber,
    List<int> value,
  ) {
    _writeTag(buffer, fieldNumber, _wireLengthDelimited);
    _writeVarint(buffer, value.length);
    buffer.add(value);
  }

  static void _writeTag(BytesBuilder buffer, int fieldNumber, int wireType) {
    _writeVarint(buffer, (fieldNumber << 3) | wireType);
  }

  static void _writeVarint(BytesBuilder buffer, int value) {
    if (value < 0) {
      throw const FormatException('Negative varint is not supported.');
    }
    var current = value;
    while (true) {
      if ((current & ~0x7f) == 0) {
        buffer.addByte(current);
        return;
      }
      buffer.addByte((current & 0x7f) | 0x80);
      current >>= 7;
    }
  }
}

class _ProtoCursor {
  _ProtoCursor(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get hasRemaining => _offset < _bytes.length;

  int readVarint() {
    var shift = 0;
    var result = 0;
    while (shift < 64) {
      if (_offset >= _bytes.length) {
        throw const FormatException('Truncated protobuf varint.');
      }
      final byte = _bytes[_offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) {
        return result;
      }
      shift += 7;
    }
    throw const FormatException('Protobuf varint exceeds 64-bit limit.');
  }

  Uint8List readLengthDelimited() {
    final length = readVarint();
    if (length < 0) {
      throw const FormatException('Negative protobuf length is invalid.');
    }
    final end = _offset + length;
    if (end > _bytes.length) {
      throw const FormatException('Truncated protobuf length-delimited field.');
    }
    final value = Uint8List.sublistView(_bytes, _offset, end);
    _offset = end;
    return value;
  }

  void skipField(int wireType) {
    switch (wireType) {
      case ControlProtoCodec._wireVarint:
        readVarint();
        return;
      case ControlProtoCodec._wireFixed64:
        _skipBytes(8);
        return;
      case ControlProtoCodec._wireLengthDelimited:
        _skipBytes(readVarint());
        return;
      case ControlProtoCodec._wireFixed32:
        _skipBytes(4);
        return;
      default:
        throw FormatException('Unsupported protobuf wire type: $wireType');
    }
  }

  void _skipBytes(int length) {
    if (length < 0) {
      throw const FormatException('Negative skip length is invalid.');
    }
    final end = _offset + length;
    if (end > _bytes.length) {
      throw const FormatException('Truncated protobuf field.');
    }
    _offset = end;
  }
}
