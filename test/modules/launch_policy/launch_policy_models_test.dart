import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/launch_policy/launch_policy_models.dart';

void main() {
  group('LaunchPolicyResponse', () {
    test('parses forced upgrade policy and startup notice', () {
      final response = LaunchPolicyResponse.fromJson({
        'serverTime': '2026-05-16T00:00:00Z',
        'platform': 'android',
        'version': '1.0.0',
        'build': 1,
        'versionPolicy': {
          'platform': 'android',
          'latestVersion': '1.3.0',
          'latestBuild': 130,
          'minimumVersion': '1.2.5',
          'minimumBuild': 125,
          'forceUpgrade': true,
          'updateUrl': 'https://example.com/android.apk',
          'title': 'Required update',
          'message': 'Please update.',
        },
        'startupNotice': {
          'id': 'notice-1',
          'title': 'System notice',
          'content': 'Hello',
          'imageUrl': 'common/notices/demo.png',
          'platforms': ['all'],
          'frequency': 'daily',
          'startAt': '2026-05-16T00:00:00Z',
          'endAt': '2026-05-17T00:00:00Z',
        },
      });

      expect(response.platform, LaunchPlatform.android);
      expect(response.build, 1);
      expect(response.versionPolicy?.forceUpgrade, isTrue);
      expect(response.versionPolicy?.minimumBuild, 125);
      expect(response.versionPolicy?.requiresForcedUpgrade(124), isTrue);
      expect(response.versionPolicy?.requiresForcedUpgrade(125), isFalse);
      expect(response.startupNotice?.frequency, StartupNoticeFrequency.daily);
      expect(response.startupNotice?.imageUrl, 'common/notices/demo.png');
    });

    test('ignores malformed optional startup notice instead of throwing', () {
      final response = LaunchPolicyResponse.fromJson({
        'platform': 'windows',
        'versionPolicy': null,
        'startupNotice': {'id': '', 'title': '', 'content': ''},
      });

      expect(response.platform, LaunchPlatform.windows);
      expect(response.versionPolicy, isNull);
      expect(response.startupNotice, isNull);
    });

    test('normalizes snake case backend fields', () {
      final policy = VersionPolicy.fromJson({
        'os': 'windows',
        'app_version': '1.4.0',
        'build_number': '140',
        'minimum_version': '1.3.0',
        'minimum_build_number': '130',
        'is_force': 1,
        'download_url': 'https://example.com/windows',
        'update_desc': 'Update now',
      });

      expect(policy.platform, LaunchPlatform.windows);
      expect(policy.latestBuild, 140);
      expect(policy.minimumBuild, 130);
      expect(policy.forceUpgrade, isTrue);
      expect(policy.message, 'Update now');
    });
  });

  group('LaunchPlatform', () {
    test('supports only android and windows for launch policy checks', () {
      expect(LaunchPlatform.fromWireName('android'), LaunchPlatform.android);
      expect(LaunchPlatform.fromWireName('win'), LaunchPlatform.windows);
      expect(LaunchPlatform.fromWireName('ios'), isNull);
      expect(LaunchPlatform.android.wireName, 'android');
    });
  });
}
