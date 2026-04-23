import 'package:flutter/material.dart';

/// Call notification types
enum CallNotificationType {
  incoming,
  outgoing,
}

/// Call notification data
class CallNotificationData {
  final String channelId;
  final String channelName;
  final String? avatar;
  final CallNotificationType type;
  final int callType; // 0=audio, 1=video
  final String? fromUid;

  CallNotificationData({
    required this.channelId,
    required this.channelName,
    this.avatar,
    required this.type,
    required this.callType,
    this.fromUid,
  });
}

/// Call notification overlay
class CallNotificationOverlay {
  CallNotificationOverlay._();
  static final CallNotificationOverlay _instance = CallNotificationOverlay._();
  static CallNotificationOverlay get instance => _instance;

  OverlayEntry? _overlayEntry;

  /// Show incoming call notification
  void showIncomingCall({
    required OverlayState overlayState,
    required CallNotificationData data,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    dismiss();
    _insert(
      overlayState: overlayState,
      builder: (_) => _IncomingCallWidget(
        data: data,
        onAccept: () {
          dismiss();
          onAccept();
        },
        onReject: () {
          dismiss();
          onReject();
        },
      ),
    );
  }

  /// Show outgoing call notification
  void showOutgoingCall({
    required OverlayState overlayState,
    required CallNotificationData data,
  }) {
    dismiss();
    _insert(
      overlayState: overlayState,
      builder: (_) => _OutgoingCallWidget(data: data),
    );
  }

  /// Dismiss notification
  void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insert({
    required OverlayState overlayState,
    required WidgetBuilder builder,
  }) {
    _overlayEntry = OverlayEntry(builder: builder);
    overlayState.insert(_overlayEntry!);
  }
}

class _IncomingCallWidget extends StatefulWidget {
  final CallNotificationData data;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCallWidget({
    required this.data,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_IncomingCallWidget> createState() => _IncomingCallWidgetState();
}

class _IncomingCallWidgetState extends State<_IncomingCallWidget> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      widget.data.channelName.isNotEmpty
                          ? widget.data.channelName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.channelName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.data.callType == 1 ? '视频通话' : '语音通话',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.call_end),
                      label: const Text('拒绝'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onAccept,
                      icon: const Icon(Icons.call),
                      label: const Text('接听'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutgoingCallWidget extends StatelessWidget {
  final CallNotificationData data;

  const _OutgoingCallWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.phone, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '正在呼叫 ${data.channelName}...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      data.callType == 1 ? '视频通话' : '语音通话',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
