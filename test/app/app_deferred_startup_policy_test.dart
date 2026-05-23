import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app shell defers optional local monitor auto-forward runners', () {
    final appSource = File('lib/app/app.dart').readAsStringSync();

    expect(appSource, contains('deferred as local_monitor_runners'));
    expect(appSource, contains('local_monitor_runners.loadLibrary()'));
    expect(
      appSource,
      contains(
        'local_monitor_runners.createDefaultLocalMonitorAutoForwardRunners',
      ),
    );

    for (final directImport in <String>[
      '../modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart',
      '../modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart',
      '../modules/feishu_monitor/feishu_monitor_shell_client.dart',
      '../modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart',
      '../modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart',
      '../modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner.dart',
    ]) {
      expect(appSource, isNot(contains(directImport)), reason: directImport);
    }
  });

  test('deferred local monitor runner factory owns heavy runner imports', () {
    final factorySource = File(
      'lib/modules/local_monitor/local_monitor_auto_forward_runner_factory.dart',
    ).readAsStringSync();

    for (final symbol in <String>[
      'DingTalkMonitorAutoForwardRunner',
      'FeishuMonitorAutoForwardRunner',
      'FeishuMonitorShellClientGroup',
      'JuliangMonitorAutoForwardRunner',
      'MengxiaMonitorAutoForwardRunner',
      'XiaoeMonitorAutoForwardRunner',
    ]) {
      expect(factorySource, contains(symbol), reason: symbol);
    }
  });
}
