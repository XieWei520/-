enum GroupRobotWebhookMode { imGenerated, official }

const String groupRobotWebhookModeImGeneratedLabel = 'IM 接收 Webhook';
const String groupRobotWebhookModeOfficialLabel = '官方 Webhook';
const String feishuOfficialWebhookInvalidMessage =
    '无效的飞书 Webhook URL（必须包含 open.feishu.cn）';
const String dingTalkOfficialWebhookInvalidMessage =
    '无效的钉钉 Webhook URL（必须包含 oapi.dingtalk.com 或 api.dingtalk.com）';

extension GroupRobotWebhookModeX on GroupRobotWebhookMode {
  static const String _imGeneratedApiValue = 'im_generated';
  static const String _officialApiValue = 'official';

  String get apiValue {
    switch (this) {
      case GroupRobotWebhookMode.official:
        return _officialApiValue;
      case GroupRobotWebhookMode.imGenerated:
        return _imGeneratedApiValue;
    }
  }

  String get label {
    switch (this) {
      case GroupRobotWebhookMode.imGenerated:
        return groupRobotWebhookModeImGeneratedLabel;
      case GroupRobotWebhookMode.official:
        return groupRobotWebhookModeOfficialLabel;
    }
  }

  static GroupRobotWebhookMode fromApiValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == _officialApiValue) {
      return GroupRobotWebhookMode.official;
    }
    return GroupRobotWebhookMode.imGenerated;
  }
}

String? validateOfficialWebhookUrl({
  required GroupRobotWebhookMode mode,
  required String webhookUrl,
  required List<String> validHosts,
  required String invalidMessage,
}) {
  if (mode != GroupRobotWebhookMode.official) {
    return null;
  }

  final trimmed = webhookUrl.trim();
  if (trimmed.isEmpty) {
    return invalidMessage;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.trim().isEmpty) {
    return invalidMessage;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return invalidMessage;
  }

  final host = uri.host.trim().toLowerCase();
  final matchesHost = validHosts
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .contains(host);
  return matchesHost ? null : invalidMessage;
}

String? validateFeishuOfficialWebhookUrl({
  required GroupRobotWebhookMode mode,
  required String webhookUrl,
}) {
  return validateOfficialWebhookUrl(
    mode: mode,
    webhookUrl: webhookUrl,
    validHosts: const ['open.feishu.cn'],
    invalidMessage: feishuOfficialWebhookInvalidMessage,
  );
}

String? validateDingTalkOfficialWebhookUrl({
  required GroupRobotWebhookMode mode,
  required String webhookUrl,
}) {
  return validateOfficialWebhookUrl(
    mode: mode,
    webhookUrl: webhookUrl,
    validHosts: const ['oapi.dingtalk.com', 'api.dingtalk.com'],
    invalidMessage: dingTalkOfficialWebhookInvalidMessage,
  );
}
