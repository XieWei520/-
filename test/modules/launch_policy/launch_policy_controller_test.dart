import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/launch_policy/launch_policy_controller.dart';
import 'package:wukong_im_app/modules/launch_policy/launch_policy_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  test('forced upgrade wins over startup notice', () async {
    final controller = LaunchPolicyController(
      api: _FakeLaunchPolicyApi(
        response: LaunchPolicyResponse(
          platform: LaunchPlatform.android,
          version: '1.0.0',
          build: 1,
          versionPolicy: const VersionPolicy(
            platform: LaunchPlatform.android,
            latestVersion: '1.2.0',
            latestBuild: 120,
            minimumVersion: '1.1.0',
            minimumBuild: 110,
            forceUpgrade: true,
            updateUrl: 'https://example.com/update',
            title: 'Required',
            message: 'Update required',
          ),
          startupNotice: const StartupNotice(
            id: 'notice-1',
            title: 'Notice',
            content: 'This should not show',
            frequency: StartupNoticeFrequency.everyStart,
          ),
        ),
      ),
      packageInfoReader: () async =>
          const LaunchPackageInfo(version: '1.0.0', buildNumber: 100),
      platformReader: () => LaunchPlatform.android,
    );

    final decision = await controller.checkLaunchPolicy();

    expect(decision.type, LaunchPolicyDecisionType.forceUpgrade);
    expect(decision.versionPolicy?.minimumBuild, 110);
    expect(decision.startupNotice, isNull);
  });

  test('daily notice is shown once per calendar day', () async {
    final notice = const StartupNotice(
      id: 'notice-daily',
      title: 'Daily',
      content: 'Shown once today',
      frequency: StartupNoticeFrequency.daily,
    );
    final controller = LaunchPolicyController(
      api: _FakeLaunchPolicyApi(
        response: LaunchPolicyResponse(
          platform: LaunchPlatform.windows,
          version: '1.0.0',
          build: 1,
          startupNotice: notice,
        ),
      ),
      packageInfoReader: () async =>
          const LaunchPackageInfo(version: '1.0.0', buildNumber: 1),
      platformReader: () => LaunchPlatform.windows,
      now: () => DateTime(2026, 5, 16, 9),
    );

    final first = await controller.checkLaunchPolicy();
    await controller.markNoticeShown(notice, shownAt: DateTime(2026, 5, 16, 9));
    final second = await controller.checkLaunchPolicy();

    expect(first.type, LaunchPolicyDecisionType.showNotice);
    expect(second.type, LaunchPolicyDecisionType.none);
  });

  test('once notice is suppressed after it has been marked shown', () async {
    final notice = const StartupNotice(
      id: 'notice-once',
      title: 'Once',
      content: 'Shown once',
      frequency: StartupNoticeFrequency.once,
    );
    final controller = LaunchPolicyController(
      api: _FakeLaunchPolicyApi(
        response: LaunchPolicyResponse(
          platform: LaunchPlatform.android,
          version: '1.0.0',
          build: 1,
          startupNotice: notice,
        ),
      ),
      packageInfoReader: () async =>
          const LaunchPackageInfo(version: '1.0.0', buildNumber: 1),
      platformReader: () => LaunchPlatform.android,
    );

    await controller.markNoticeShown(notice);
    final decision = await controller.checkLaunchPolicy();

    expect(decision.type, LaunchPolicyDecisionType.none);
  });

  test('network failures fail open', () async {
    final controller = LaunchPolicyController(
      api: _FakeLaunchPolicyApi(error: Exception('offline')),
      packageInfoReader: () async =>
          const LaunchPackageInfo(version: '1.0.0', buildNumber: 1),
      platformReader: () => LaunchPlatform.android,
    );

    final decision = await controller.checkLaunchPolicy();

    expect(decision.type, LaunchPolicyDecisionType.none);
  });

  test('unsupported platforms skip the remote check', () async {
    final api = _FakeLaunchPolicyApi(
      response: const LaunchPolicyResponse(
        platform: LaunchPlatform.android,
        version: '1.0.0',
        build: 1,
      ),
    );
    final controller = LaunchPolicyController(
      api: api,
      packageInfoReader: () async =>
          const LaunchPackageInfo(version: '1.0.0', buildNumber: 1),
      platformReader: () => null,
    );

    final decision = await controller.checkLaunchPolicy();

    expect(decision.type, LaunchPolicyDecisionType.none);
    expect(api.calls, 0);
  });
}

class _FakeLaunchPolicyApi implements LaunchPolicyApiGateway {
  _FakeLaunchPolicyApi({this.response, this.error});

  final LaunchPolicyResponse? response;
  final Object? error;
  int calls = 0;

  @override
  Future<LaunchPolicyResponse> fetchLaunchPolicy({
    required LaunchPlatform platform,
    required String version,
    required int buildNumber,
  }) async {
    calls += 1;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return response!;
  }
}
