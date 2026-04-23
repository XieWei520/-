import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group_dingtalk_robot_config.dart';
import 'package:wukong_im_app/data/models/group_feishu_robot_config.dart';

void main() {
  group('GroupFeishuRobotConfig', () {
    test(
      'fromJson defaults webhook_mode to im_generated when missing or invalid',
      () {
        final missingMode = GroupFeishuRobotConfig.fromJson({
          'group_no': 'g-10001',
          'webhook_url': 'https://open.feishu.cn/webhook',
          'secret': 'secret-value',
          'app_id': 'app-id',
          'app_secret': 'app-secret',
          'enabled': 1,
          'secret_set': 1,
          'app_secret_set': 1,
          'last_push_at': 1710000000,
          'last_error': '',
          'updated_at': '2026-04-20T08:00:00Z',
        });
        final invalidMode = GroupFeishuRobotConfig.fromJson({
          'group_no': 'g-10001',
          'webhook_url': 'https://open.feishu.cn/webhook',
          'secret': 'secret-value',
          'app_id': 'app-id',
          'app_secret': 'app-secret',
          'enabled': 1,
          'secret_set': 1,
          'app_secret_set': 1,
          'last_push_at': 1710000000,
          'last_error': '',
          'updated_at': '2026-04-20T08:00:00Z',
          'webhook_mode': 'invalid-mode',
        });

        expect(missingMode.webhookMode, 'im_generated');
        expect(invalidMode.webhookMode, 'im_generated');
      },
    );

    test('fromJson preserves webhook mode and official fields', () {
      final config = GroupFeishuRobotConfig.fromJson({
        'group_no': 'g-10001',
        'webhook_url': 'https://open.feishu.cn/webhook',
        'secret': 'secret-value',
        'app_id': 'app-id',
        'app_secret': 'app-secret',
        'enabled': 1,
        'secret_set': 1,
        'app_secret_set': 1,
        'last_push_at': 1710000000,
        'last_error': '',
        'updated_at': '2026-04-20T08:00:00Z',
        'webhook_mode': 'official',
        'official_webhook_url': 'https://open.feishu.cn/official-webhook',
        'official_secret': 'official-secret',
      });

      expect(config.webhookMode, 'official');
      expect(
        config.officialWebhookUrl,
        'https://open.feishu.cn/official-webhook',
      );
      expect(config.officialSecret, 'official-secret');
    });

    test('fromJson parses transport display fields', () {
      final config = GroupFeishuRobotConfig.fromJson({
        'group_no': 'g-10001',
        'webhook_url': 'https://open.feishu.cn/webhook',
        'secret': 'secret-value',
        'app_id': 'app-id',
        'app_secret': 'app-secret',
        'enabled': 1,
        'secret_set': 1,
        'app_secret_set': 1,
        'last_push_at': 1710000000,
        'last_error': '',
        'updated_at': '2026-04-20T08:00:00Z',
        'display_name': 'Feishu Robot',
        'display_avatar': 'https://example.com/feishu.png',
      });

      expect(config.displayName, 'Feishu Robot');
      expect(config.displayAvatar, 'https://example.com/feishu.png');
    });

    test('toJson serializes transport display fields as snake_case', () {
      const config = GroupFeishuRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://open.feishu.cn/webhook',
        secret: 'secret-value',
        appId: 'app-id',
        appSecret: 'app-secret',
        enabled: true,
        secretSet: true,
        appSecretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'Feishu Robot',
        displayAvatar: 'https://example.com/feishu.png',
      );

      final json = config.toJson();

      expect(json, containsPair('display_name', 'Feishu Robot'));
      expect(
        json,
        containsPair('display_avatar', 'https://example.com/feishu.png'),
      );
    });

    test('copyWith preserves and replaces transport display fields', () {
      const original = GroupFeishuRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://open.feishu.cn/webhook',
        secret: 'secret-value',
        appId: 'app-id',
        appSecret: 'app-secret',
        enabled: true,
        secretSet: true,
        appSecretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'Old Name',
        displayAvatar: 'https://example.com/old.png',
      );

      final copied = original.copyWith(
        displayName: 'New Name',
        displayAvatar: 'https://example.com/new.png',
      );

      expect(copied.displayName, 'New Name');
      expect(copied.displayAvatar, 'https://example.com/new.png');
      expect(original.displayName, 'Old Name');
      expect(original.displayAvatar, 'https://example.com/old.png');
    });

    test('toJson and copyWith include dual-mode robot fields', () {
      const original = GroupFeishuRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://open.feishu.cn/webhook',
        secret: 'secret-value',
        appId: 'app-id',
        appSecret: 'app-secret',
        enabled: true,
        secretSet: true,
        appSecretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'Feishu Robot',
        displayAvatar: 'https://example.com/feishu.png',
        webhookMode: 'im_generated',
        officialWebhookUrl: '',
        officialSecret: '',
      );

      final copied = original.copyWith(
        webhookMode: 'official',
        officialWebhookUrl: 'https://open.feishu.cn/official-webhook',
        officialSecret: 'official-secret',
      );
      final json = copied.toJson();

      expect(copied.webhookMode, 'official');
      expect(
        copied.officialWebhookUrl,
        'https://open.feishu.cn/official-webhook',
      );
      expect(copied.officialSecret, 'official-secret');
      expect(json, containsPair('webhook_mode', 'official'));
      expect(
        json,
        containsPair(
          'official_webhook_url',
          'https://open.feishu.cn/official-webhook',
        ),
      );
      expect(json, containsPair('official_secret', 'official-secret'));
    });
  });

  group('GroupDingTalkRobotConfig', () {
    test('fromJson defaults webhook_mode to im_generated when missing', () {
      final config = GroupDingTalkRobotConfig.fromJson({
        'group_no': 'g-10001',
        'webhook_url': 'https://oapi.dingtalk.com/robot/send',
        'secret': 'secret-value',
        'enabled': 1,
        'secret_set': 1,
        'last_push_at': 1710000000,
        'last_error': '',
        'updated_at': '2026-04-20T08:00:00Z',
      });

      expect(config.webhookMode, 'im_generated');
      expect(config.officialWebhookUrl, '');
      expect(config.officialSecret, '');
    });

    test('fromJson parses transport display fields', () {
      final config = GroupDingTalkRobotConfig.fromJson({
        'group_no': 'g-10001',
        'webhook_url': 'https://oapi.dingtalk.com/robot/send',
        'secret': 'secret-value',
        'enabled': 1,
        'secret_set': 1,
        'last_push_at': 1710000000,
        'last_error': '',
        'updated_at': '2026-04-20T08:00:00Z',
        'display_name': 'DingTalk Robot',
        'display_avatar': 'https://example.com/dingtalk.png',
      });

      expect(config.displayName, 'DingTalk Robot');
      expect(config.displayAvatar, 'https://example.com/dingtalk.png');
    });

    test('toJson serializes transport display fields as snake_case', () {
      const config = GroupDingTalkRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://oapi.dingtalk.com/robot/send',
        secret: 'secret-value',
        enabled: true,
        secretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'DingTalk Robot',
        displayAvatar: 'https://example.com/dingtalk.png',
      );

      final json = config.toJson();

      expect(json, containsPair('display_name', 'DingTalk Robot'));
      expect(
        json,
        containsPair('display_avatar', 'https://example.com/dingtalk.png'),
      );
    });

    test('copyWith preserves and replaces transport display fields', () {
      const original = GroupDingTalkRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://oapi.dingtalk.com/robot/send',
        secret: 'secret-value',
        enabled: true,
        secretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'Old Name',
        displayAvatar: 'https://example.com/old.png',
      );

      final copied = original.copyWith(
        displayName: 'New Name',
        displayAvatar: 'https://example.com/new.png',
      );

      expect(copied.displayName, 'New Name');
      expect(copied.displayAvatar, 'https://example.com/new.png');
      expect(original.displayName, 'Old Name');
      expect(original.displayAvatar, 'https://example.com/old.png');
    });

    test('toJson and copyWith include dual-mode robot fields', () {
      const original = GroupDingTalkRobotConfig(
        groupNo: 'g-10001',
        webhookUrl: 'https://oapi.dingtalk.com/robot/send',
        secret: 'secret-value',
        enabled: true,
        secretSet: true,
        lastPushAt: 1710000000,
        lastError: '',
        updatedAt: '2026-04-20T08:00:00Z',
        displayName: 'DingTalk Robot',
        displayAvatar: 'https://example.com/dingtalk.png',
        webhookMode: 'im_generated',
        officialWebhookUrl: '',
        officialSecret: '',
      );

      final copied = original.copyWith(
        webhookMode: 'official',
        officialWebhookUrl: 'https://oapi.dingtalk.com/official-webhook',
        officialSecret: 'official-secret',
      );
      final json = copied.toJson();

      expect(copied.webhookMode, 'official');
      expect(
        copied.officialWebhookUrl,
        'https://oapi.dingtalk.com/official-webhook',
      );
      expect(copied.officialSecret, 'official-secret');
      expect(json, containsPair('webhook_mode', 'official'));
      expect(
        json,
        containsPair(
          'official_webhook_url',
          'https://oapi.dingtalk.com/official-webhook',
        ),
      );
      expect(json, containsPair('official_secret', 'official-secret'));
    });
  });
}
