import 'dart:io';

import 'package:feishu_monitor_shell/src/shell_cli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runFeishuMonitorShellCli(args, stdout, stderr);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
