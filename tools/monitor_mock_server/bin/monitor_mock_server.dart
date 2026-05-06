import 'dart:io';

import 'package:monitor_mock_server/src/mock_monitor_server.dart';

Future<void> main(List<String> args) async {
  final port = _readPort(args) ?? 8787;
  final server = MockMonitorServer();
  final bound = await server.start(port: port);
  stdout.writeln(
    'Mock Monitor API listening on http://127.0.0.1:${bound.port}',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}

int? _readPort(List<String> args) {
  final index = args.indexOf('--port');
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return int.tryParse(args[index + 1]);
}
