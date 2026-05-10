import 'dart:io';

import 'dart:async';

import 'shell_server.dart';
import 'shell_store.dart';

Future<int> runFeishuMonitorShellCli(
  List<String> args,
  IOSink stdout,
  IOSink stderr,
) async {
  final port = _readIntArg(args, '--port') ?? 18766;
  final token = _readStringArg(args, '--token') ?? 'wukong-feishu-shell-dev';
  final statePath =
      _readStringArg(args, '--state-file') ??
      '.runtime/feishu_monitor_shell/status.json';

  final server = ShellServer(
    store: ShellStore(File(statePath)),
    host: InternetAddress.loopbackIPv4,
    port: port,
    token: token,
  );
  await server.start();
  stdout.writeln(
    'feishu_monitor_shell listening on http://127.0.0.1:$port',
  );

  final completer = Completer<int>();
  ProcessSignal.sigint.watch().listen((_) async {
    if (!completer.isCompleted) {
      await server.close();
      completer.complete(0);
    }
  });
  return completer.future;
}

int? _readIntArg(List<String> args, String name) {
  final value = _readStringArg(args, name);
  if (value == null) {
    return null;
  }
  return int.tryParse(value);
}

String? _readStringArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1].trim();
}
