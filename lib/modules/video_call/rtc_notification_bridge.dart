import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import '../../data/models/call.dart';
import '../../wukong_base/endpoint/endpoint_handler.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_push/notification/notification_helper.dart';

class RtcNotificationRequest {
  const RtcNotificationRequest({
    required this.fromUid,
    required this.fromName,
    required this.callType,
    this.roomId = '',
    this.notificationId = RtcNotificationBridge.notificationId,
  });

  final String fromUid;
  final String fromName;
  final int callType;
  final String roomId;
  final int notificationId;

  String get resolvedTitle {
    final normalized = fromName.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return fromUid.trim().isEmpty ? 'WuKongIM' : fromUid.trim();
  }

  String get resolvedBody {
    if (callType == CallType.video.value) {
      return 'Incoming video call invitation';
    }
    return 'Incoming audio call invitation';
  }

  factory RtcNotificationRequest.fromDynamic(dynamic raw) {
    if (raw is RtcNotificationRequest) {
      return raw;
    }
    if (raw is String) {
      final fromUid = raw.trim();
      return RtcNotificationRequest(
        fromUid: fromUid,
        fromName: fromUid,
        callType: CallType.audio.value,
      );
    }
    if (raw is Map) {
      return RtcNotificationRequest(
        fromUid:
            _readString(raw['from_uid']) ??
            _readString(raw['caller_uid']) ??
            '',
        fromName:
            _readString(raw['from_name']) ??
            _readString(raw['caller_name']) ??
            _readString(raw['from_uid']) ??
            _readString(raw['caller_uid']) ??
            '',
        callType: _readInt(raw['call_type']) ?? CallType.audio.value,
        roomId: _readString(raw['room_id']) ?? '',
      );
    }
    return const RtcNotificationRequest(fromUid: '', fromName: '', callType: 0);
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }
}

abstract class RtcNotificationAdapter {
  Future<void> ensureInitialized();

  Future<void> show(RtcNotificationRequest request);

  Future<void> cancel(int id);
}

class DefaultRtcNotificationAdapter implements RtcNotificationAdapter {
  const DefaultRtcNotificationAdapter();

  @override
  Future<void> ensureInitialized() {
    return NotificationHelper.instance.initialize();
  }

  @override
  Future<void> show(RtcNotificationRequest request) async {
    await NotificationHelper.instance.show(
      id: request.notificationId,
      title: request.resolvedTitle,
      body: request.resolvedBody,
      payload: request.roomId.trim().isEmpty ? request.fromUid : request.roomId,
      channelId: NotificationHelper.rtcChannelId,
      channelName: NotificationHelper.rtcChannelName,
      importance: Importance.max,
    );
  }

  @override
  Future<void> cancel(int id) {
    return NotificationHelper.instance.cancel(id);
  }
}

class RtcNotificationBridge {
  RtcNotificationBridge({RtcNotificationAdapter? adapter})
    : _adapter = adapter ?? const DefaultRtcNotificationAdapter();

  static const int notificationId = 2;

  final RtcNotificationAdapter _adapter;

  void registerEndpoints({EndpointManager? endpointManager}) {
    final manager = endpointManager ?? EndpointManager.getInstance();
    manager.remove('show_rtc_notification');
    manager.remove('cancel_rtc_notification');
    manager.setMethod(
      'show_rtc_notification',
      '',
      0,
      AsyncFunctionHandler(([dynamic param]) => showRtcNotification(param)),
    );
    manager.setMethod(
      'cancel_rtc_notification',
      '',
      0,
      AsyncFunctionHandler(([dynamic _]) => cancelRtcNotification()),
    );
  }

  Future<void> showRtcNotification([dynamic raw]) async {
    final request = RtcNotificationRequest.fromDynamic(raw);
    try {
      await _adapter.ensureInitialized();
      await _adapter.show(request);
    } catch (error) {
      if (_isIgnorableNotificationError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> cancelRtcNotification() async {
    try {
      await _adapter.cancel(notificationId);
    } catch (error) {
      if (_isIgnorableNotificationError(error)) {
        return;
      }
      rethrow;
    }
  }

  bool _isIgnorableNotificationError(Object error) {
    final message = error.toString();
    return error is MissingPluginException ||
        error is PlatformException ||
        error.runtimeType.toString().contains('LateInitializationError') ||
        message.contains('LateInitializationError') ||
        message.contains('has not been initialized');
  }
}
