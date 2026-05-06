import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_cli.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runAgentCli(args);
  exit(exitCode);
}
