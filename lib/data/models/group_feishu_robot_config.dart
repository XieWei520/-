class GroupFeishuRobotConfig {
  static const String webhookModeImGenerated = 'im_generated';
  static const String webhookModeOfficial = 'official';

  final String groupNo;
  final String webhookUrl;
  final String secret;
  final String appId;
  final String appSecret;
  final bool enabled;
  final bool secretSet;
  final bool appSecretSet;
  final int lastPushAt;
  final String lastError;
  final String updatedAt;
  final String displayName;
  final String displayAvatar;
  final String webhookMode;
  final String officialWebhookUrl;
  final String officialSecret;

  const GroupFeishuRobotConfig({
    required this.groupNo,
    required this.webhookUrl,
    required this.secret,
    required this.appId,
    required this.appSecret,
    required this.enabled,
    required this.secretSet,
    required this.appSecretSet,
    required this.lastPushAt,
    required this.lastError,
    required this.updatedAt,
    required this.displayName,
    required this.displayAvatar,
    this.webhookMode = webhookModeImGenerated,
    this.officialWebhookUrl = '',
    this.officialSecret = '',
  });

  factory GroupFeishuRobotConfig.fromJson(Map<String, dynamic> json) {
    return GroupFeishuRobotConfig(
      groupNo: json['group_no']?.toString() ?? '',
      webhookUrl: json['webhook_url']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
      appId: json['app_id']?.toString() ?? '',
      appSecret: json['app_secret']?.toString() ?? '',
      enabled: _readInt(json['enabled']) == 1,
      secretSet: _readBool(json['secret_set']),
      appSecretSet: _readBool(json['app_secret_set']),
      lastPushAt: _readInt(json['last_push_at']),
      lastError: json['last_error']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      displayAvatar: json['display_avatar']?.toString() ?? '',
      webhookMode: normalizeWebhookMode(json['webhook_mode']),
      officialWebhookUrl: json['official_webhook_url']?.toString() ?? '',
      officialSecret: json['official_secret']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_no': groupNo,
      'webhook_url': webhookUrl,
      'secret': secret,
      'app_id': appId,
      'app_secret': appSecret,
      'enabled': enabled ? 1 : 0,
      'secret_set': secretSet,
      'app_secret_set': appSecretSet,
      'last_push_at': lastPushAt,
      'last_error': lastError,
      'updated_at': updatedAt,
      'display_name': displayName,
      'display_avatar': displayAvatar,
      'webhook_mode': normalizeWebhookMode(webhookMode),
      'official_webhook_url': officialWebhookUrl,
      'official_secret': officialSecret,
    };
  }

  GroupFeishuRobotConfig copyWith({
    String? groupNo,
    String? webhookUrl,
    String? secret,
    String? appId,
    String? appSecret,
    bool? enabled,
    bool? secretSet,
    bool? appSecretSet,
    int? lastPushAt,
    String? lastError,
    String? updatedAt,
    String? displayName,
    String? displayAvatar,
    String? webhookMode,
    String? officialWebhookUrl,
    String? officialSecret,
  }) {
    return GroupFeishuRobotConfig(
      groupNo: groupNo ?? this.groupNo,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      secret: secret ?? this.secret,
      appId: appId ?? this.appId,
      appSecret: appSecret ?? this.appSecret,
      enabled: enabled ?? this.enabled,
      secretSet: secretSet ?? this.secretSet,
      appSecretSet: appSecretSet ?? this.appSecretSet,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastError: lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
      displayAvatar: displayAvatar ?? this.displayAvatar,
      webhookMode: webhookMode == null
          ? this.webhookMode
          : normalizeWebhookMode(webhookMode),
      officialWebhookUrl: officialWebhookUrl ?? this.officialWebhookUrl,
      officialSecret: officialSecret ?? this.officialSecret,
    );
  }

  static String normalizeWebhookMode(dynamic value) {
    final mode = value?.toString().trim();
    if (mode == webhookModeOfficial) {
      return webhookModeOfficial;
    }
    return webhookModeImGenerated;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return _readInt(value) == 1;
  }
}
