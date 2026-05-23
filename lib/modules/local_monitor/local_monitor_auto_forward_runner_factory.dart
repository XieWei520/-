import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner.dart';

import 'local_monitor_auto_forward_coordinator.dart';

List<LocalMonitorAutoForwardRunnerController>
createDefaultLocalMonitorAutoForwardRunners() {
  return <LocalMonitorAutoForwardRunnerController>[
    FeishuMonitorAutoForwardRunner(
      clientGroup: FeishuMonitorShellClientGroup.recommendedForRouteCount(120),
    ),
    DingTalkMonitorAutoForwardRunner(),
    MengxiaMonitorAutoForwardRunner(),
    JuliangMonitorAutoForwardRunner(),
    XiaoeMonitorAutoForwardRunner(),
  ];
}
