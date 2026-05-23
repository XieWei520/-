enum DingTalkMonitorCaptureSource {
  uiaText,
  uiaImageMetadata,
  previewSave,
  chatAreaScreenshot,
  chatAreaScreenshotOcr,
  unknown,
}

class DingTalkMonitorShellStatus {
  const DingTalkMonitorShellStatus({
    required this.captureRunning,
    required this.serverTime,
    required this.version,
    required this.shellState,
    required this.currentHwnd,
    required this.message,
    required this.lastWindowEventAt,
    required this.ocrEnabled,
    required this.conversationReadiness,
    required this.conversationReadinessMessage,
  });

  final bool captureRunning;
  final DateTime? serverTime;
  final String version;
  final String shellState;
  final String currentHwnd;
  final String message;
  final DateTime? lastWindowEventAt;
  final bool ocrEnabled;
  final String conversationReadiness;
  final String conversationReadinessMessage;

  bool get isOnline {
    final normalized = shellState.trim().toLowerCase();
    return normalized == 'attached' || normalized == 'running';
  }

  bool get isCapturing => captureRunning;

  factory DingTalkMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    return DingTalkMonitorShellStatus(
      captureRunning: _boolValue(
        json['captureRunning'] ?? json['capture_running'],
      ),
      serverTime: _dateTimeValue(json['serverTime'] ?? json['server_time']),
      version: (json['version'] ?? '').toString(),
      shellState: (json['shellState'] ?? json['shell_state'] ?? '').toString(),
      currentHwnd: (json['currentHwnd'] ?? json['current_hwnd'] ?? '')
          .toString(),
      message: (json['message'] ?? '').toString(),
      lastWindowEventAt: _dateTimeValue(
        json['lastWindowEventAt'] ?? json['last_window_event_at'],
      ),
      ocrEnabled: _boolValue(json['ocrEnabled'] ?? json['ocr_enabled']),
      conversationReadiness:
          (json['conversationReadiness'] ??
                  json['conversation_readiness'] ??
                  'NoConversationList')
              .toString(),
      conversationReadinessMessage:
          (json['conversationReadinessMessage'] ??
                  json['conversation_readiness_message'] ??
                  '')
              .toString(),
    );
  }
}

class DingTalkMonitorMessageEvent {
  const DingTalkMonitorMessageEvent({
    required this.eventId,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.embeddedSourceName,
    required this.senderName,
    required this.observedAt,
    required this.text,
    required this.localImagePath,
    required this.captureSource,
    required this.contentHash,
  });

  final String eventId;
  final String sourceConversationId;
  final String sourceConversationName;
  final String embeddedSourceName;
  final String senderName;
  final DateTime? observedAt;
  final String text;
  final String localImagePath;
  final DingTalkMonitorCaptureSource captureSource;
  final String contentHash;

  bool get isForwardableText =>
      text.trim().isNotEmpty &&
      captureSource == DingTalkMonitorCaptureSource.uiaText &&
      !_isDiagnosticUiaTextSource;

  bool get isForwardableImage =>
      localImagePath.trim().isNotEmpty && _isImageCaptureSource;

  bool get isForwardablePayload => isForwardableText || isForwardableImage;

  bool get _isImageCaptureSource {
    return switch (captureSource) {
      DingTalkMonitorCaptureSource.uiaImageMetadata ||
      DingTalkMonitorCaptureSource.previewSave ||
      DingTalkMonitorCaptureSource.chatAreaScreenshot => true,
      DingTalkMonitorCaptureSource.uiaText ||
      DingTalkMonitorCaptureSource.chatAreaScreenshotOcr ||
      DingTalkMonitorCaptureSource.unknown => false,
    };
  }

  bool get _isDiagnosticUiaTextSource {
    final sourceId = sourceConversationId.trim().toLowerCase();
    final sourceName = _normalizeDingTalkMonitorShellText(
      sourceConversationName,
    );
    final normalizedText = _normalizeDingTalkMonitorShellText(text);
    if (text.trim().startsWith('__DINGTALK_HOST_CLIPBOARD_PROBE__')) {
      return true;
    }
    if (sourceId.isEmpty || sourceId.startsWith('source:')) {
      return true;
    }
    final hasUnstableSourceId =
        sourceId.isEmpty || sourceId.startsWith('source:');
    if (hasUnstableSourceId &&
        (sourceName == 'advancedsearch' ||
            sourceName.contains('enter/alt+s'))) {
      return true;
    }
    return normalizedText.contains('当前检测出钉钉异常') ||
        normalizedText.contains('清理本地缓存尝试修复');
  }

  factory DingTalkMonitorMessageEvent.fromJson(Map<String, dynamic> json) {
    return DingTalkMonitorMessageEvent(
      eventId: _stringValue(json, 'eventId', 'event_id'),
      sourceConversationId: _stringValue(
        json,
        'sourceConversationId',
        'source_conversation_id',
      ),
      sourceConversationName: _stringValue(
        json,
        'sourceConversationName',
        'source_conversation_name',
      ),
      embeddedSourceName: _stringValue(
        json,
        'embeddedSourceName',
        'embedded_source_name',
      ),
      senderName: _stringValue(json, 'senderName', 'sender_name'),
      observedAt: _dateTimeValue(json['observedAt'] ?? json['observed_at']),
      text: _stringValue(json, 'text', 'text'),
      localImagePath: _stringValue(json, 'localImagePath', 'local_image_path'),
      captureSource: dingTalkMonitorCaptureSourceFromJson(
        json['captureSource'] ?? json['capture_source'],
      ),
      contentHash: _stringValue(json, 'contentHash', 'content_hash'),
    );
  }
}

DingTalkMonitorCaptureSource dingTalkMonitorCaptureSourceFromJson(
  Object? value,
) {
  if (value is int) {
    return switch (value) {
      0 => DingTalkMonitorCaptureSource.uiaText,
      1 => DingTalkMonitorCaptureSource.uiaImageMetadata,
      2 => DingTalkMonitorCaptureSource.previewSave,
      3 => DingTalkMonitorCaptureSource.chatAreaScreenshot,
      4 => DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
      _ => DingTalkMonitorCaptureSource.unknown,
    };
  }
  final normalized = value
      ?.toString()
      .trim()
      .replaceAll(RegExp(r'[_\-\s]+'), '')
      .toLowerCase();
  return switch (normalized) {
    'uiatext' => DingTalkMonitorCaptureSource.uiaText,
    'uiaimagemetadata' => DingTalkMonitorCaptureSource.uiaImageMetadata,
    'previewsave' => DingTalkMonitorCaptureSource.previewSave,
    'chatareascreenshot' => DingTalkMonitorCaptureSource.chatAreaScreenshot,
    'chatareascreenshotocr' =>
      DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
    _ => DingTalkMonitorCaptureSource.unknown,
  };
}

String dingTalkMonitorCaptureSourceName(
  DingTalkMonitorCaptureSource captureSource,
) {
  return switch (captureSource) {
    DingTalkMonitorCaptureSource.uiaText => 'UiaText',
    DingTalkMonitorCaptureSource.uiaImageMetadata => 'UiaImageMetadata',
    DingTalkMonitorCaptureSource.previewSave => 'PreviewSave',
    DingTalkMonitorCaptureSource.chatAreaScreenshot => 'ChatAreaScreenshot',
    DingTalkMonitorCaptureSource.chatAreaScreenshotOcr =>
      'ChatAreaScreenshotOcr',
    DingTalkMonitorCaptureSource.unknown => 'Unknown',
  };
}

List<T> dingTalkMonitorList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Object?>()
      .map((item) {
        if (item is Map<String, dynamic>) {
          return fromJson(item);
        }
        if (item is Map) {
          return fromJson(Map<String, dynamic>.from(item));
        }
        return null;
      })
      .whereType<T>()
      .toList(growable: false);
}

DateTime? dingTalkMonitorDateTime(Object? value) => _dateTimeValue(value);

String _normalizeDingTalkMonitorShellText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _stringValue(
  Map<String, dynamic> json,
  String camelKey,
  String snakeKey,
) {
  return (json[camelKey] ?? json[snakeKey] ?? '').toString();
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final timestamp = int.tryParse(raw);
  if (timestamp != null) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return DateTime.tryParse(raw);
}
